import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/data/internal_transfer_codec.dart';
import 'package:vanta/features/funding/data/internal_transfer_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/funding/domain/internal_transfer.dart';

import '../../support/internal_transfer.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  test(
    'host restart retains exact nonce, amount and terminal public reply without signatures',
    () async {
      final dir = await Directory.systemTemp.createTemp('vanta-internal-transfer-');
      addTearDown(() => dir.delete(recursive: true));
      final j = FileInternalTransferJournal(() async => dir);
      await j.reload();
      final r = transferRecord(now: time);
      await j.prepare(r);
      final f = File('${dir.path}/pending-internal-transfers-v1.json');
      final text = await f.readAsString();
      expect(text.contains('signature'), false);
      expect(text.contains('secret'), false);
      final initial = decodeInternalTransferJournal(text).single;
      expect(initial.nonce, r.nonce);
      expect(initial.amount.toString(), '1.01');
      await j.report(r.key, transferReply());
      await j.close();
      final rebuilt = FileInternalTransferJournal(() async => dir);
      await rebuilt.reload();
      expect(rebuilt.snapshot.records.single.reply!.transactionId, '9007199254740993');
      await rebuilt.complete(r.key);
      expect(decodeInternalTransferJournal(await f.readAsString()), isEmpty);
      await rebuilt.close();
    },
  );
  test('unknown record survives restart and blocks duplicate wallet mutation', () async {
    final dir = await Directory.systemTemp.createTemp('vanta-internal-transfer-');
    addTearDown(() => dir.delete(recursive: true));
    final j = FileInternalTransferJournal(() async => dir);
    await j.reload();
    final r = transferRecord(now: time);
    final a = j.prepare(r), b = j.prepare(r);
    await a;
    await expectLater(b, throwsA(isA<AccountReadFailure>()));
    await j.close();
    final rebuilt = FileInternalTransferJournal(() async => dir);
    await rebuilt.reload();
    expect(rebuilt.snapshot.records.single.reply, null);
    await expectLater(rebuilt.prepare(r), throwsA(isA<AccountReadFailure>()));
    await rebuilt.close();
  });
  test('reported response cannot be overwritten in memory or on disk', () async {
    final dir = await Directory.systemTemp.createTemp('vanta-internal-transfer-');
    addTearDown(() => dir.delete(recursive: true));
    final j = FileInternalTransferJournal(() async => dir);
    addTearDown(j.close);
    await j.reload();
    final r = transferRecord(now: time);
    await j.prepare(r);
    await j.report(r.key, transferReply());
    await expectLater(j.report(r.key, InternalTransferReply('42')), throwsA(anything));
    expect(j.snapshot.records.single.reply!.transactionId, '9007199254740993');
    final f = File('${dir.path}/pending-internal-transfers-v1.json');
    expect(
      decodeInternalTransferJournal(await f.readAsString()).single.reply!.transactionId,
      '9007199254740993',
    );
    await f.writeAsString(encodeInternalTransferJournal([r.reported(InternalTransferReply('42'))]));
    await expectLater(j.reload(), throwsA(isA<AccountReadFailure>()));
    expect(j.snapshot.failure, true);
    expect(j.snapshot.records.single.reply!.transactionId, '9007199254740993');
  });
  for (final issue in [
    'version',
    'extra',
    'duplicate',
    'address',
    'nonce',
    'amount',
    'time',
    'reply',
    'direction',
    'clientId',
    'asset',
    'numericNonce',
    'duplicateKeys',
    'oversize',
  ]) {
    test('strict journal rejects $issue without manufacturing an executable operation', () {
      var source = encodeInternalTransferJournal([transferRecord(now: time)]);
      final m = jsonDecode(source) as Map<String, dynamic>;
      final row = (m['records'] as List).single as Map<String, dynamic>;
      switch (issue) {
        case 'version':
          m['version'] = '2';
        case 'extra':
          row['signature'] = 'must not be saved';
        case 'duplicate':
          (m['records'] as List).add(row);
        case 'address':
          row['address'] = '0x${'0' * 40}';
        case 'nonce':
          row['nonce'] = '9223372036854775808';
        case 'amount':
          row['amount'] = '0';
        case 'time':
          row['preparedAt'] = '0';
        case 'direction':
          row['direction'] = 'MAIN_FUTURE';
        case 'clientId':
          row['clientId'] = '';
        case 'asset':
          row['asset'] = 'USDT/BTC';
        case 'numericNonce':
          row['nonce'] = 1;
        case 'reply':
          row['reply'] = {'asset': 'USDT', 'balance': null, 'accountId': null, 'time': null};
      }
      source = issue == 'duplicateKeys'
          ? source.replaceFirst('"version":"1"', '"version":"1","version":"1"')
          : issue == 'oversize'
          ? ' ' * 131073
          : jsonEncode(m);
      expect(() => decodeInternalTransferJournal(source), throwsA(anything));
    });
  }
  test('known response is distinct from unknown across codec', () {
    final decoded = decodeInternalTransferJournal(
      encodeInternalTransferJournal([
        transferRecord(now: time, reply: InternalTransferReply('42')),
      ]),
    ).single;
    expect(decoded.reply!.transactionId, '42');
  });
  for (final fault in ['directory', 'read', 'write']) {
    test(
      'response retained if $fault fails and reload merges into original durable intent',
      () async {
        final dir = await Directory.systemTemp.createTemp('vanta-internal-transfer-');
        addTearDown(() => dir.delete(recursive: true));
        var unavailable = false;
        final j = FileInternalTransferJournal(() async {
          if (unavailable) throw const FileSystemException('unavailable');
          return dir;
        });
        await j.reload();
        final r = transferRecord(now: time);
        await j.prepare(r);
        final f = File('${dir.path}/pending-internal-transfers-v1.json'),
            tmp = Directory('${dir.path}/pending-internal-transfers-v1.json.tmp');
        final source = await f.readAsString();
        if (fault == 'directory') unavailable = true;
        if (fault == 'read') await f.writeAsString('{broken');
        if (fault == 'write') await tmp.create();
        await expectLater(j.report(r.key, transferReply()), throwsA(isA<AccountReadFailure>()));
        expect(j.snapshot.records.single.reply!.transactionId, '9007199254740993');
        expect(j.snapshot.failure, true);
        unavailable = false;
        if (fault == 'read') await f.writeAsString(source);
        if (fault == 'write') await tmp.delete();
        await j.reload();
        expect(j.snapshot.failure, false);
        expect(decodeInternalTransferJournal(await f.readAsString()).single.reply, isNotNull);
        await j.close();
      },
    );
  }
  test('corruption and temp preserved, missing canonical record cannot clear memory', () async {
    final dir = await Directory.systemTemp.createTemp('vanta-internal-transfer-');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/pending-internal-transfers-v1.json'),
        temp = File('${dir.path}/pending-internal-transfers-v1.json.tmp');
    await f.writeAsString('{corrupt');
    await temp.writeAsString(encodeInternalTransferJournal([transferRecord(now: time)]));
    final j = FileInternalTransferJournal(() async => dir);
    await expectLater(j.reload(), throwsA(isA<AccountReadFailure>()));
    expect(await f.readAsString(), '{corrupt');
    await f.writeAsString(encodeInternalTransferJournal([transferRecord(now: time)]));
    await j.reload();
    await f.delete();
    await expectLater(j.reload(), throwsA(isA<AccountReadFailure>()));
    expect(j.snapshot.records.length, 1);
    await j.close();
  });
  for (final mutation in ['prepare', 'complete']) {
    test('missing or altered original disk intent blocks $mutation and preserves memory', () async {
      final dir = await Directory.systemTemp.createTemp('vanta-internal-transfer-tamper-');
      addTearDown(() => dir.delete(recursive: true));
      final j = FileInternalTransferJournal(() async => dir);
      addTearDown(j.close);
      await j.reload();
      final r = transferRecord(now: time);
      await j.prepare(r);
      final f = File('${dir.path}/pending-internal-transfers-v1.json');
      await f.writeAsString(encodeInternalTransferJournal([]));
      await expectLater(
        mutation == 'complete' ? j.complete(r.key) : j.prepare(r),
        throwsA(isA<AccountReadFailure>()),
      );
      expect(j.snapshot.failure, true);
      expect(j.snapshot.records.single.clientId, r.clientId);
    });
  }
}
