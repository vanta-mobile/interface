import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/rebalance_codec.dart';
import 'package:vanta/features/portfolio/data/rebalance_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/asset_rebalance.dart';

import '../../support/rebalance.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  test(
    'host restart retains exact nonce, debt and terminal public reply without signatures',
    () async {
      final dir = await Directory.systemTemp.createTemp('vanta-rebalance-');
      addTearDown(() => dir.delete(recursive: true));
      final j = FileRebalanceJournal(() async => dir);
      await j.reload();
      final r = rebalanceRecord(now: time);
      await j.prepare(r);
      final f = File('${dir.path}/pending-asset-rebalances-v1.json');
      final text = await f.readAsString();
      expect(text.contains('signature'), false);
      expect(text.contains('secret'), false);
      final initial = decodeRebalanceJournal(text).single;
      expect(initial.nonce, r.nonce);
      expect(initial.previousUsdt.toString(), '-1.000000000000000001');
      await j.report(r.key, rebalanceReply(now: time));
      await j.close();
      final rebuilt = FileRebalanceJournal(() async => dir);
      await rebuilt.reload();
      expect(rebuilt.snapshot.records.single.reply!.accountId, '9007199254740993');
      await rebuilt.complete(r.key);
      expect(decodeRebalanceJournal(await f.readAsString()), isEmpty);
      await rebuilt.close();
    },
  );
  test('unknown record survives restart and blocks duplicate wallet mutation', () async {
    final dir = await Directory.systemTemp.createTemp('vanta-rebalance-');
    addTearDown(() => dir.delete(recursive: true));
    final j = FileRebalanceJournal(() async => dir);
    await j.reload();
    final r = rebalanceRecord(now: time);
    final a = j.prepare(r), b = j.prepare(r);
    await a;
    await expectLater(b, throwsA(isA<AccountReadFailure>()));
    await j.close();
    final rebuilt = FileRebalanceJournal(() async => dir);
    await rebuilt.reload();
    expect(rebuilt.snapshot.records.single.reply, null);
    await expectLater(rebuilt.prepare(r), throwsA(isA<AccountReadFailure>()));
    await rebuilt.close();
  });
  test('reported response cannot be overwritten in memory or on disk', () async {
    final dir = await Directory.systemTemp.createTemp('vanta-rebalance-');
    addTearDown(() => dir.delete(recursive: true));
    final j = FileRebalanceJournal(() async => dir);
    addTearDown(j.close);
    await j.reload();
    final r = rebalanceRecord(now: time);
    await j.prepare(r);
    await j.report(r.key, rebalanceReply(now: time));
    await expectLater(j.report(r.key, const RebalanceReply.noExchange()), throwsA(anything));
    expect(j.snapshot.records.single.reply!.noExchange, false);
    final f = File('${dir.path}/pending-asset-rebalances-v1.json');
    expect(decodeRebalanceJournal(await f.readAsString()).single.reply!.noExchange, false);
    await f.writeAsString(encodeRebalanceJournal([r.reported(const RebalanceReply.noExchange())]));
    await expectLater(j.reload(), throwsA(isA<AccountReadFailure>()));
    expect(j.snapshot.failure, true);
    expect(j.snapshot.records.single.reply!.noExchange, false);
  });
  for (final issue in [
    'version',
    'extra',
    'duplicate',
    'address',
    'nonce',
    'debt',
    'time',
    'reply',
    'duplicateKeys',
    'oversize',
  ]) {
    test('strict journal rejects $issue without manufacturing an executable operation', () {
      var source = encodeRebalanceJournal([rebalanceRecord(now: time)]);
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
        case 'debt':
          row['usdt'] = '0';
        case 'time':
          row['preparedAt'] = '0';
        case 'reply':
          row['reply'] = {'asset': 'USDT', 'balance': null, 'accountId': null, 'time': null};
      }
      source = issue == 'duplicateKeys'
          ? source.replaceFirst('"version":"1"', '"version":"1","version":"1"')
          : issue == 'oversize'
          ? ' ' * 131073
          : jsonEncode(m);
      expect(() => decodeRebalanceJournal(source), throwsA(anything));
    });
  }
  test('no-op is distinct from unknown across codec', () {
    final decoded = decodeRebalanceJournal(
      encodeRebalanceJournal([
        rebalanceRecord(now: time, reply: const RebalanceReply.noExchange()),
      ]),
    ).single;
    expect(decoded.reply!.noExchange, true);
  });
  for (final fault in ['directory', 'read', 'write']) {
    test(
      'response retained if $fault fails and reload merges into original durable intent',
      () async {
        final dir = await Directory.systemTemp.createTemp('vanta-rebalance-');
        addTearDown(() => dir.delete(recursive: true));
        var unavailable = false;
        final j = FileRebalanceJournal(() async {
          if (unavailable) throw const FileSystemException('unavailable');
          return dir;
        });
        await j.reload();
        final r = rebalanceRecord(now: time);
        await j.prepare(r);
        final f = File('${dir.path}/pending-asset-rebalances-v1.json'),
            tmp = Directory('${dir.path}/pending-asset-rebalances-v1.json.tmp');
        final source = await f.readAsString();
        if (fault == 'directory') unavailable = true;
        if (fault == 'read') await f.writeAsString('{broken');
        if (fault == 'write') await tmp.create();
        await expectLater(
          j.report(r.key, rebalanceReply(now: time)),
          throwsA(isA<AccountReadFailure>()),
        );
        expect(j.snapshot.records.single.reply!.accountId, '9007199254740993');
        expect(j.snapshot.failure, true);
        unavailable = false;
        if (fault == 'read') await f.writeAsString(source);
        if (fault == 'write') await tmp.delete();
        await j.reload();
        expect(j.snapshot.failure, false);
        expect(decodeRebalanceJournal(await f.readAsString()).single.reply, isNotNull);
        await j.close();
      },
    );
  }
  test('corruption and temp preserved, missing canonical record cannot clear memory', () async {
    final dir = await Directory.systemTemp.createTemp('vanta-rebalance-');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/pending-asset-rebalances-v1.json'),
        temp = File('${dir.path}/pending-asset-rebalances-v1.json.tmp');
    await f.writeAsString('{corrupt');
    await temp.writeAsString(encodeRebalanceJournal([rebalanceRecord(now: time)]));
    final j = FileRebalanceJournal(() async => dir);
    await expectLater(j.reload(), throwsA(isA<AccountReadFailure>()));
    expect(await f.readAsString(), '{corrupt');
    await f.writeAsString(encodeRebalanceJournal([rebalanceRecord(now: time)]));
    await j.reload();
    await f.delete();
    await expectLater(j.reload(), throwsA(isA<AccountReadFailure>()));
    expect(j.snapshot.records.length, 1);
    await j.close();
  });
}
