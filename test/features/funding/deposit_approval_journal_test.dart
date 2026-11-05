import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/data/deposit_approval_codec.dart';
import 'package:vanta/features/funding/data/deposit_approval_journal.dart';
import 'package:vanta/features/funding/data/funding_json.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/deposit_approval.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  test(
    'exact public recovery terms survive lexical JSON and host file rebuild without signing data',
    () async {
      final directory = await Directory.systemTemp.createTemp('vanta-approval-');
      addTearDown(() => directory.delete(recursive: true));
      final journal = FileDepositApprovalJournal(() async => directory);
      expect(journal.snapshot.ready, false);
      await journal.reload();
      final record = approvalRecord(now: time);
      await journal.prepare(record);
      final file = File('${directory.path}/pending-deposit-approvals-v1.json');
      final data = await file.readAsString();
      expect(data.contains('signature'), false);
      expect(data.contains('secret'), false);
      final decoded = decodeApprovalJournal(data).single;
      expect(decoded.transaction.parameters, record.transaction.parameters);
      expect(decoded.amountUnits, record.amountUnits);
      expect(decoded.preparedAt, time);
      await journal.attachHash(record.key, '0x${'b' * 64}');
      await journal.close();
      final restored = FileDepositApprovalJournal(() async => directory);
      await restored.reload();
      expect(restored.snapshot.records.single.hash, '0x${'b' * 64}');
      await restored.complete(record.key);
      await restored.close();
      expect(decodeApprovalJournal(await file.readAsString()), isEmpty);
      expect(await File('${file.path}.tmp').exists(), false);
    },
  );
  test('serial preparations cannot create two sends for one wallet', () async {
    final directory = await Directory.systemTemp.createTemp('vanta-approval-');
    addTearDown(() => directory.delete(recursive: true));
    final journal = FileDepositApprovalJournal(() async => directory);
    await journal.reload();
    final r = approvalRecord(now: time);
    final first = journal.prepare(r), second = journal.prepare(r);
    await first;
    await expectLater(
      second,
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'depositApprovalPending')),
    );
    expect(journal.snapshot.records.length, 1);
    await journal.close();
  });
  for (final issue in [
    'duplicateKey',
    'version',
    'extra',
    'unsignedOverflow',
    'nonce',
    'calldata',
    'target',
    'nativeValue',
    'kind',
    'zeroHash',
    'duplicateWallet',
  ]) {
    test('corrupt $issue cannot become an executable or disposable record', () {
      final source = encodeApprovalJournal([approvalRecord(now: time)]);
      final map = jsonDecode(source) as Map<String, dynamic>;
      final row = (map['records'] as List).single as Map<String, dynamic>;
      switch (issue) {
        case 'version':
          map['version'] = 2;
        case 'extra':
          row['signature'] = 'must not be stored';
        case 'unsignedOverflow':
          row['amount'] = '${BigInt.one << 256}';
        case 'nonce':
          row['nonce'] = '-1';
        case 'calldata':
          row['data'] = '0x095ea7b3';
        case 'target':
          row['to'] = '0x${'3' * 40}';
        case 'nativeValue':
          row['value'] = '1';
        case 'kind':
          row['kind'] = 'deposit';
        case 'zeroHash':
          row['hash'] = '0x${'0' * 64}';
        case 'duplicateWallet':
          (map['records'] as List).add(row);
      }
      final text = issue == 'duplicateKey'
          ? source.replaceFirst('"version":1', '"version":1,"version":1')
          : jsonEncode(map);
      expect(
        () => decodeApprovalJournal(text),
        throwsA(anyOf(isA<FormatException>(), isA<AccountReadFailure>())),
      );
    });
  }
  test('oversize, too many records, unknown enums and impossible timestamps rejected', () {
    expect(() => decodeApprovalJournal(' ' * 262145), throwsFormatException);
    final m = decodeFundingJson(
      encodeApprovalJournal([approvalRecord(now: time)]),
    ) as Map<String, dynamic>;
    final row = (m['records'] as List).single as Map<String, dynamic>;
    for (final field in ['market', 'kind', 'preparedAt']) {
      final invalid = {...row, field: field == 'preparedAt' ? '10413792000001' : 'invalid'};
      expect(() => decodeApprovalRecord(invalid), throwsFormatException);
    }
    expect(
      () => decodeApprovalJournal(
        '{"version":1,"records":[${List.filled(101, jsonEncode(encodeApprovalRecord(approvalRecord(now: time)))).join(',')}]}',
      ),
      throwsFormatException,
    );
  });
  test('corruption is retained on disk; interrupted temp file is never promoted', () async {
    final directory = await Directory.systemTemp.createTemp('vanta-approval-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/pending-deposit-approvals-v1.json');
    await file.writeAsString('{broken');
    await File('${file.path}.tmp')
        .writeAsString(encodeApprovalJournal([approvalRecord(now: time)]));
    final journal = FileDepositApprovalJournal(() async => directory);
    await expectLater(journal.reload(), throwsA(isA<AccountReadFailure>()));
    await expectLater(
      journal.prepare(approvalRecord(now: time)),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(await file.readAsString(), '{broken');
    expect(journal.snapshot.failure, isNotNull);
    await journal.close();
  });
  test(
    'failed hash write retains hash in memory and retry merges it to valid disk record',
    () async {
      final directory = await Directory.systemTemp.createTemp('vanta-approval-');
      addTearDown(() => directory.delete(recursive: true));
      final journal = FileDepositApprovalJournal(() async => directory);
      await journal.reload();
      final r = approvalRecord(now: time);
      await journal.prepare(r);
      final temporary = Directory('${directory.path}/pending-deposit-approvals-v1.json.tmp');
      await temporary.create();
      await expectLater(
        journal.attachHash(r.key, '0x${'b' * 64}'),
        throwsA(isA<AccountReadFailure>()),
      );
      expect(journal.snapshot.records.single.hash, '0x${'b' * 64}');
      expect(journal.snapshot.failure, isNotNull);
      await temporary.delete();
      await journal.reload();
      expect(journal.snapshot.failure, null);
      expect(
        decodeApprovalJournal(
          await File('${directory.path}/pending-deposit-approvals-v1.json').readAsString(),
        ).single.hash,
        '0x${'b' * 64}',
      );
      await journal.close();
    },
  );
  test('known hash cannot be replaced and missing canonical records do not clear memory', () async {
    final directory = await Directory.systemTemp.createTemp('vanta-approval-');
    addTearDown(() => directory.delete(recursive: true));
    final journal = FileDepositApprovalJournal(() async => directory);
    await journal.reload();
    final r = approvalRecord(now: time);
    await journal.prepare(r);
    await journal.attachHash(r.key, '0x${'b' * 64}');
    await expectLater(
      journal.attachHash(r.key, '0x${'c' * 64}'),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(journal.snapshot.records.single.hash, '0x${'b' * 64}');
    await File('${directory.path}/pending-deposit-approvals-v1.json').delete();
    await expectLater(journal.reload(), throwsA(isA<AccountReadFailure>()));
    expect(journal.snapshot.records.single.hash, '0x${'b' * 64}');
    await journal.close();
  });
  for (final failure in ['directory', 'read']) {
    test('hash retained if $failure fails before disk write and reload recovers', () async {
      final directory = await Directory.systemTemp.createTemp('vanta-approval-');
      addTearDown(() => directory.delete(recursive: true));
      var locationFailed = false;
      final journal = FileDepositApprovalJournal(() async {
        if (locationFailed) throw const FileSystemException('unavailable');
        return directory;
      });
      await journal.reload();
      final record = approvalRecord(now: time);
      await journal.prepare(record);
      final file = File('${directory.path}/pending-deposit-approvals-v1.json');
      final source = await file.readAsString();
      if (failure == 'directory') locationFailed = true;
      if (failure == 'read') await file.writeAsString('{corrupt');
      final hash = '0x${'b' * 64}';
      await expectLater(journal.attachHash(record.key, hash), throwsA(isA<AccountReadFailure>()));
      expect(journal.snapshot.records.single.hash, hash);
      expect(journal.snapshot.failure, isNotNull);
      await expectLater(journal.prepare(record), throwsA(isA<AccountReadFailure>()));
      locationFailed = false;
      if (failure == 'read') await file.writeAsString(source);
      await journal.reload();
      expect(journal.snapshot.failure, null);
      expect(decodeApprovalJournal(await file.readAsString()).single.hash, hash);
      await journal.close();
    });
  }
}
