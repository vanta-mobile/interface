import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';

import '../support/aster_signatures.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 8);
  WalletOperationRecord record({int nonce = 1, String address = fixtureMaster}) =>
      WalletOperationRecord(
        kind: WalletOperationKind.createSubaccount,
        address: address,
        nonce: nonce,
        preparedAt: now,
        terms: {'child': fixtureChild, 'name': 'Desk A'},
      );
  test(
    'pending master request blocks other operations, another wallet remains independent',
    () async {
      final j = MemoryWalletOperationJournal();
      addTearDown(j.close);
      await j.prepare(record());
      await expectLater(j.prepare(record(nonce: 2)), throwsA(isA<WalletOperationPending>()));
      await j.prepare(record(address: '0x3333333333333333333333333333333333333333'));
      expect(j.snapshot.records.length, 2);
    },
  );
  test('acknowledgement is retained and permits a separately prepared operation', () async {
    final j = MemoryWalletOperationJournal();
    addTearDown(j.close);
    await j.prepare(record());
    await j.report(record().key);
    await j.prepare(record(nonce: 2));
    expect(j.snapshot.records.length, 2);
    expect(j.snapshot.records.first.acknowledged, true);
  });
  test(
    'multiple unknown withdrawals survive restart and late IDs bind to their original keys',
    () async {
      final directory = await Directory.systemTemp.createTemp('vanta-withdrawal-attempts-');
      addTearDown(() => directory.delete(recursive: true));
      WalletOperationRecord withdrawal(int nonce) => WalletOperationRecord(
        kind: WalletOperationKind.withdrawal,
        address: fixtureMaster,
        nonce: nonce,
        preparedAt: now,
        terms: {
          'chain': '56',
          'market': 'perp',
          'asset': 'USDT',
          'amount': '$nonce',
          'fee': '0',
          'receiver': fixtureMaster,
        },
      );
      final first = withdrawal(1), second = withdrawal(2);
      final journal = FileWalletOperationJournal(() async => directory);
      await journal.reload();
      await journal.prepare(first);
      await journal.prepare(second);
      await journal.close();
      final restored = FileWalletOperationJournal(() async => directory);
      addTearDown(restored.close);
      await restored.reload();
      expect(restored.snapshot.records, hasLength(2));
      await restored.report(first.key, 'first-id');
      expect(restored.snapshot.records.first.reference, 'first-id');
      expect(restored.snapshot.records.last.acknowledged, false);
      // Unknown withdrawals cannot lock an unrelated, newly validated operation.
      await restored.prepare(record(nonce: 3));
      expect(restored.snapshot.records, hasLength(3));
      await expectLater(restored.prepare(second), throwsA(isA<WalletOperationPending>()));
    },
  );
  for (final mutation in <String Function(String)>[
    (s) => s.replaceFirst('"version":"1"', '"version":"2"'),
    (s) => s.replaceFirst('"nonce":"1"', '"nonce":"01"'),
    (s) => s.replaceFirst('"nonce":"1"', '"nonce":1'),
    (s) => s.replaceFirst('"child":', '"signature":"hidden","child":'),
    (s) => s.replaceFirst('"terms":', '"terms":{},"terms":'),
    (s) => s.replaceFirst(fixtureMaster, '0x${'0' * 40}'),
    (s) => s.replaceFirst('"reference":null', '"reference":"unacknowledged-id"'),
    (s) => '${s}garbage',
  ]) {
    test('corrupt/ambiguous or sensitive unsigned journal rejected ${mutation.hashCode}', () {
      expect(
        () => decodeWalletOperations(mutation(encodeWalletOperations([record()]))),
        throwsFormatException,
      );
    });
  }
  test('exact int64 nonce survives serialization above JavaScript integer range', () {
    final r = record(nonce: 1762243200000000001);
    expect(decodeWalletOperations(encodeWalletOperations([r])).single.nonce, r.nonce);
  });
  test('file persists before dispatch and restores pending block after restart', () async {
    final d = await Directory.systemTemp.createTemp('vanta-operation-test-');
    addTearDown(() => d.delete(recursive: true));
    final j = FileWalletOperationJournal(() async => d);
    await j.reload();
    await j.prepare(record());
    await j.close();
    final restored = FileWalletOperationJournal(() async => d);
    addTearDown(restored.close);
    await restored.reload();
    expect(restored.snapshot.records.single.key, record().key);
    await expectLater(restored.prepare(record(nonce: 2)), throwsA(isA<WalletOperationPending>()));
    await restored.report(record().key);
    final body = await File('${d.path}/wallet-operations-v1.json').readAsString();
    expect(jsonDecode(body)['records'][0]['acknowledged'], true);
  });
  test(
    'failed response write retains acknowledgement and reload merges it into original disk terms',
    () async {
      final d = await Directory.systemTemp.createTemp('vanta-operation-test-');
      addTearDown(() => d.delete(recursive: true));
      var fail = false;
      final j = FileWalletOperationJournal(() async {
        if (fail) throw const FileSystemException('fixture');
        return d;
      });
      addTearDown(j.close);
      await j.reload();
      await j.prepare(record());
      fail = true;
      await expectLater(j.report(record().key), throwsA(isA<WalletOperationStorageFailure>()));
      expect(j.snapshot.failed, true);
      expect(j.snapshot.records.single.acknowledged, true);
      fail = false;
      await j.reload();
      expect(j.snapshot.failed, false);
      expect(j.snapshot.records.single.acknowledged, true);
    },
  );
  test('corrupt disk is never replaced by an empty journal on reload', () async {
    final d = await Directory.systemTemp.createTemp('vanta-operation-test-');
    addTearDown(() => d.delete(recursive: true));
    final f = File('${d.path}/wallet-operations-v1.json');
    await f.writeAsString('{bad');
    final j = FileWalletOperationJournal(() async => d);
    addTearDown(j.close);
    await expectLater(j.reload(), throwsA(isA<WalletOperationStorageFailure>()));
    expect(j.snapshot.failed, true);
    expect(await f.readAsString(), '{bad');
    await expectLater(j.prepare(record()), throwsA(isA<WalletOperationStorageFailure>()));
  });
  test('changed disk terms cannot be combined with retained response', () async {
    final d = await Directory.systemTemp.createTemp('vanta-operation-test-');
    addTearDown(() => d.delete(recursive: true));
    final j = FileWalletOperationJournal(() async => d);
    addTearDown(j.close);
    await j.reload();
    await j.prepare(record());
    final f = File('${d.path}/wallet-operations-v1.json');
    await f.writeAsString((await f.readAsString()).replaceFirst('Desk A', 'Desk B'));
    await expectLater(j.reload(), throwsA(isA<WalletOperationStorageFailure>()));
    expect(j.snapshot.failed, true);
    expect(j.snapshot.records.single.terms['name'], 'Desk A');
  });
}
