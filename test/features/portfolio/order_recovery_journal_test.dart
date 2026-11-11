import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/order_recovery_codec.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/data/attached_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/aster_account.dart';
import '../../support/attached_order.dart';
import '../../support/live_order.dart';
import '../../support/order_recovery.dart';

OrderRecoveryRecord recoveryRecord([LiveOrderIntent? intent]) => OrderRecoveryRecord(
  query: OrderQuery.capture(intent ?? liveIntent()),
  createdAt: liveOrderClock,
);

void main() {
  for (final buy in [true, false]) {
    for (final hedge in [true, false]) {
      test('all known query terms survive serialization $buy $hedge', () {
        final intents = [
          liveIntent(buy: buy, hedge: hedge),
          liveIntent(buy: buy, hedge: hedge, market: true),
          liveIntent(
            buy: buy,
            hedge: hedge,
            market: true,
            trigger: LiveOrderTrigger(
              kind: LiveOrderTriggerKind.stop,
              price: buy ? '81000' : '79000',
            ),
          ),
          liveIntent(
            buy: buy,
            hedge: hedge,
            market: true,
            trailing: const LiveOrderTrailing(callbackRate: '1.000000000000000001'),
          ),
          liveCloseIntent(
            short: !buy,
            hedge: hedge,
            market: true,
            entireClose: true,
            trigger: LiveOrderTrigger(
              kind: LiveOrderTriggerKind.stop,
              price: buy ? '81000' : '79000',
            ),
          ),
        ];
        for (final intent in intents) {
          final original = recoveryRecord(intent);
          final restored = decodeRecoveryJournal(encodeRecoveryJournal([original])).single;
          final payload = liveQueryPayload(intent);
          expect(mapRecoveredOrderQuery(payload, restored.query).orderId, '12345');
          expect(restored.query.positionSide, intent.positionSide);
          expect(restored.createdAt, original.createdAt);
          expect(restored.query.key, original.key);
        }
      });
    }
  }
  test('reversed attached entry retains full original protection, not a new account snapshot', () {
    final intent = attachedIntent(
      context: liveCloseContext(short: true, quantity: '0.002'),
      quantity: '0.003',
    );
    final restored = decodeRecoveryJournal(encodeRecoveryJournal([recoveryRecord(intent)])).single;
    expect(restored.query.protectedQuantity, '0.003');
    expect(
      mapRecoveredStrategyQuery(
        attachedQuery(intent),
        restored.query,
        liveOrderClock,
      ).strategy!.strategyId,
      '9876',
    );
    final encoded = encodeRecoveryJournal([restored]);
    for (final secret in [
      'signature',
      'nonce',
      'email',
      'token',
      'balance',
      'markPrice',
      'positions',
      'entryPrice',
      'privateKey',
    ]) {
      expect(encoded.toLowerCase(), isNot(contains(secret.toLowerCase())));
    }
  });
  test('corrupt, future-version, unknown fields and duplicated identities are rejected', () {
    final row = encodeRecoveryRecord(recoveryRecord());
    for (final text in [
      '{',
      '[]',
      jsonEncode({
        'version': 5,
        'records': [row],
      }),
      jsonEncode({
        'version': 1,
        'records': [row, row],
      }),
      jsonEncode({
        'version': 1,
        'records': [
          {...row, 'signature': 'secret'},
        ],
      }),
    ]) {
      expect(() => decodeRecoveryJournal(text), throwsFormatException);
    }
  });
  test('journal byte limit counts UTF-8 symbols before any replacement is written', () {
    final row = encodeRecoveryRecord(recoveryRecord(attachedIntent()));
    row['symbol'] = '币' * 50;
    row['protectedQuantity'] = '1' * 65;
    final draft = row['draft'] as Map;
    draft['quantity'] = '1' * 65;
    draft['price'] = '1' * 65;
    final attachment = draft['attachment'] as Map;
    (attachment['takeProfit'] as Map)['price'] = '1' * 65;
    (attachment['stopLoss'] as Map)['price'] = '1' * 65;
    // Each row is individually valid; only the complete file exceeds its byte budget.
    decodeRecoveryRecord(row);
    final rows = [
      for (var i = 0; i < 1000; i++) {...row, 'clientId': 'utf8-$i'},
    ];
    final text = jsonEncode({'version': 4, 'records': rows});
    expect(text.length, lessThan(1024 * 1024));
    expect(utf8.encode(text).length, greaterThan(1024 * 1024));
    expect(() => decodeRecoveryJournal(text), throwsFormatException);
  });
  for (final field in ['address', 'symbol', 'clientId', 'mode', 'createdAt']) {
    test('invalid identity or metadata rejected: $field', () {
      final row = encodeRecoveryRecord(recoveryRecord());
      row[field] = field == 'createdAt' ? 1.5 : 'invalid & signature=hidden';
      expect(() => decodeRecoveryRecord(row), throwsFormatException);
    });
  }
  test('decimal, scope, enum and boolean corruption cannot become query expectations', () {
    for (final mutation in <String, Object?>{
      'quantity': 0.001,
      'price': 'NaN',
      'market': 'true',
      'timeInForce': 'arbitrary',
      'closingSide': 'ALIEN',
    }.entries) {
      final row = encodeRecoveryRecord(recoveryRecord());
      (row['draft'] as Map)[mutation.key] = mutation.value;
      expect(() => decodeRecoveryRecord(row), throwsFormatException);
    }
  });

  group('durable local journal', () {
    late Directory directory;
    late FileOrderRecoveryJournal journal;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('vanta-recovery-test-');
      journal = FileOrderRecoveryJournal(() async => directory);
      await journal.reload();
    });
    tearDown(() async {
      await journal.close();
      await directory.delete(recursive: true);
    });
    File canonical() => File('${directory.path}/pending-futures-orders-v1.json');
    test('existing v1 pending file is found and safely rewritten as v4 on completion', () async {
      final record = recoveryRecord(attachedIntent());
      await canonical().writeAsString(
        jsonEncode({
          'version': 1,
          'records': [legacyRecoveryFields(encodeRecoveryRecord(record))],
        }),
        flush: true,
      );
      await journal.reload();
      expect(journal.snapshot.records.single.key, record.key);
      expect(journal.snapshot.records.single.query.draft.attachment!.entryPeg, null);
      await journal.complete(record.key);
      final bytes = await canonical().readAsString();
      expect((jsonDecode(bytes) as Map)['version'], 4);
      expect(decodeRecoveryJournal(bytes), isEmpty);
    });
    test(
      'fresh process restores unresolved record; completion is durable and idempotent',
      () async {
        final record = recoveryRecord();
        await journal.prepare(record);
        final restarted = FileOrderRecoveryJournal(() async => directory);
        await restarted.reload();
        expect(restarted.snapshot.records.single.key, record.key);
        await restarted.complete(record.key);
        await restarted.complete(record.key);
        final next = FileOrderRecoveryJournal(() async => directory);
        await next.reload();
        expect(next.snapshot.records, isEmpty);
        await restarted.close();
        await next.close();
      },
    );
    test('same wallet records distinct attempts and duplicate keys are idempotent', () async {
      final first = recoveryRecord();
      final second = recoveryRecord(
        LiveOrderIntent(
          context: liveContext(),
          draft: liveDraft(),
          clientOrderId: 'different-reference',
          revision: 0,
        ),
      );
      await Future.wait([journal.prepare(first), journal.prepare(second)]);
      await journal.prepare(first);
      expect(journal.snapshot.records.map((r) => r.key), [first.key, second.key]);
      expect(decodeRecoveryJournal(await canonical().readAsString()).length, 2);
      await journal.complete(first.key);
      expect(journal.snapshot.records.single.key, second.key);
    });
    test('different wallets survive queued writes and scoped removal', () async {
      final first = recoveryRecord();
      final second = recoveryRecord(
        LiveOrderIntent(
          context: liveContext(address: '0x${'3' * 40}'),
          draft: liveDraft(),
          clientOrderId: 'second-wallet-reference',
          revision: 0,
        ),
      );
      await Future.wait([journal.prepare(first), journal.prepare(second)]);
      expect(journal.snapshot.records.length, 2);
      await journal.complete(first.key);
      expect(journal.snapshot.records.single.query.address, '0x${'3' * 40}');
      expect(decodeRecoveryJournal(await canonical().readAsString()).single.key, second.key);
    });
    test('interrupted temp file never replaces the last canonical record', () async {
      await journal.prepare(recoveryRecord());
      await File('${canonical().path}.tmp').writeAsString('incomplete');
      final restart = FileOrderRecoveryJournal(() async => directory);
      await restart.reload();
      expect(restart.snapshot.records.single.query.address, accountAddress);
      await restart.close();
    });
    test('corrupt canonical fails closed, preserves bytes and last known records', () async {
      await journal.prepare(recoveryRecord());
      await canonical().writeAsString('corrupt-data', flush: true);
      await expectLater(journal.reload(), throwsA(isA<AccountReadFailure>()));
      expect(journal.snapshot.failure!.key, 'orderRecoveryStorage');
      expect(journal.snapshot.records.length, 1);
      await expectLater(journal.prepare(recoveryRecord()), throwsA(isA<AccountReadFailure>()));
      expect(await canonical().readAsString(), 'corrupt-data');
    });
    test('failed atomic replacement preserves canonical and retry can recover', () async {
      final original = await canonical().exists() ? await canonical().readAsString() : null;
      final blocker = Directory('${canonical().path}.tmp');
      await blocker.create();
      await expectLater(journal.prepare(recoveryRecord()), throwsA(isA<AccountReadFailure>()));
      expect(journal.snapshot.failure!.key, 'orderRecoveryStorage');
      expect(await canonical().exists(), original != null);
      await blocker.delete();
      await journal.reload();
      await journal.prepare(recoveryRecord());
      expect(journal.snapshot.failure, null);
      expect(journal.snapshot.records.length, 1);
    });
    test('a completion write failure retains record for another original-ID query', () async {
      final record = recoveryRecord();
      await journal.prepare(record);
      final blocker = Directory('${canonical().path}.tmp');
      await blocker.create();
      await expectLater(journal.complete(record.key), throwsA(isA<AccountReadFailure>()));
      expect(decodeRecoveryJournal(await canonical().readAsString()).single.key, record.key);
      expect(journal.snapshot.records.single.key, record.key);
      await blocker.delete();
      await journal.reload();
      await journal.complete(record.key);
      expect(journal.snapshot.records, isEmpty);
    });
  });
}
