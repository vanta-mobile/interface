import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/attached_order_mapper.dart';
import 'package:vanta/features/portfolio/data/order_recovery_codec.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/attached_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/attached_order.dart';
import '../../support/live_order.dart';
import '../../support/order_recovery.dart';

void main() {
  for (final buy in [true, false]) {
    for (final hedge in [true, false]) {
      for (final execution in AttachedExitExecution.values) {
        test('signed exit terms survive recovery $buy $hedge $execution', () {
          final tp = AttachedExit(
            kind: LiveOrderTriggerKind.takeProfit,
            price: buy ? '81000' : '79000',
            execution: execution,
            limitPrice: execution == AttachedExitExecution.manualLimit
                ? (buy ? '80999.9' : '79000.1')
                : null,
          );
          final sl = AttachedExit(
            kind: LiveOrderTriggerKind.stop,
            basis: LiveOrderTriggerBasis.last,
            price: buy ? '79000' : '81000',
            execution: AttachedExitExecution.automaticLimit,
          );
          final intent = attachedIntent(
            buy: buy,
            hedge: hedge,
            protection: LiveOrderAttachment(takeProfit: tp, stopLoss: sl),
          );
          expect(intent.context.validate(intent.draft), null);
          final record = OrderRecoveryRecord(
            query: OrderQuery.capture(intent),
            createdAt: liveOrderClock,
          );
          final json = encodeRecoveryJournal([record]);
          expect((jsonDecode(json) as Map)['version'], 4);
          final restored = decodeRecoveryJournal(json).single;
          final legs = buildStrategyLegs(restored.query);
          expect(legs[1]['quantity'], intent.draft.quantity);
          expect(legs[1]['firstDrivenOn'], 'PARTIALLY_FILLED_OR_FILLED');
          expect(legs[1]['secondDrivenOn'], 'PARTIALLY_FILLED_OR_FILLED');
          expect(
            legs[1]['type'],
            execution == AttachedExitExecution.market ? 'TAKE_PROFIT_MARKET' : 'TAKE_PROFIT',
          );
          expect(
            legs[1]['price'],
            execution == AttachedExitExecution.market ? null : tp.executionPrice,
          );
          expect(legs[1]['timeInForce'], execution == AttachedExitExecution.market ? null : 'GTC');
          expect(legs[2]['price'], sl.price);
          expect(legs[2]['workingType'], 'CONTRACT_PRICE');
          expect(
            mapRecoveredStrategyQuery(
              attachedQuery(intent),
              restored.query,
              liveOrderClock,
            ).needsRecheck,
            false,
          );
          expect(restored.query.draft.attachment!.takeProfit!.execution, execution);
        });
      }
    }
  }
  for (final version in [1, 2, 3]) {
    test('v$version retains net quantity and FILLED actions through v4 rewrite', () {
      final intent = attachedIntent(quantity: '0.003');
      final legacy = legacyRecoveryFields(
        encodeRecoveryRecord(
          OrderRecoveryRecord(query: OrderQuery.capture(intent), createdAt: liveOrderClock),
        ),
      );
      legacy['protectedQuantity'] = '0.001';
      final old = jsonEncode({
        'version': version,
        'records': [legacy],
      });
      final restored = decodeRecoveryJournal(old).single;
      final rewritten = decodeRecoveryJournal(encodeRecoveryJournal([restored])).single;
      for (final query in [restored.query, rewritten.query]) {
        final legs = buildStrategyLegs(query);
        expect(legs[1]['quantity'], '0.001');
        expect(legs[1]['firstDrivenOn'], 'FILLED');
        expect(legs[1]['secondDrivenOn'], 'FILLED');
        expect(legs[1].containsKey('price'), false);
        final payload = attachedQuery(intent);
        for (final row in (payload['subOrders'] as List).skip(1).cast<Map<String, dynamic>>()) {
          row['quantity'] = '0.001';
          row['firstDrivenOn'] = row['secondDrivenOn'] = 'FILLED';
        }
        expect(mapRecoveredStrategyQuery(payload, query, liveOrderClock).needsRecheck, false);
        ((payload['subOrders'] as List)[1] as Map)['firstDrivenOn'] = 'PARTIALLY_FILLED_OR_FILLED';
        expect(
          () => mapRecoveredStrategyQuery(payload, query, liveOrderClock),
          throwsFormatException,
        );
      }
    });
  }
  for (final mutation in <String, Object?>{
    'price': '79000',
    'type': 'TAKE_PROFIT_MARKET',
    'timeInForce': 'IOC',
    'firstDrivenOn': 'FILLED',
    'secondDrivenOn': 'FILLED',
  }.entries) {
    test('query cannot resolve a different exit limit or lifecycle ${mutation.key}', () {
      final intent = attachedIntent(
        protection: const LiveOrderAttachment(
          takeProfit: AttachedExit(
            kind: LiveOrderTriggerKind.takeProfit,
            price: '81000',
            execution: AttachedExitExecution.manualLimit,
            limitPrice: '80999.9',
          ),
          stopLoss: AttachedExit(kind: LiveOrderTriggerKind.stop, price: '79000'),
        ),
      );
      final payload = attachedQuery(intent);
      ((payload['subOrders'] as List)[1] as Map)[mutation.key] = mutation.value;
      expect(() => mapAttachedOrderQuery(payload, intent, liveOrderClock), throwsFormatException);
    });
  }
  test('triggered limit remains verifiable only with original conditional type and limit', () {
    final intent = attachedIntent(
      protection: const LiveOrderAttachment(
        takeProfit: AttachedExit(
          kind: LiveOrderTriggerKind.takeProfit,
          price: '81000',
          execution: AttachedExitExecution.automaticLimit,
        ),
      ),
    );
    final payload = attachedQuery(intent),
        row = ((attachedQuery(intent)['subOrders'] as List)[1] as Map);
    row['origType'] = 'TAKE_PROFIT';
    row['type'] = 'LIMIT';
    row['status'] = 'PARTIALLY_FILLED';
    (payload['subOrders'] as List)[1] = row;
    expect(
      mapAttachedOrderQuery(payload, intent, liveOrderClock).strategy!.legs.last.status,
      'PARTIALLY_FILLED',
    );
    expect(mapAttachedOrderQuery(payload, intent, liveOrderClock).executedQuantity, null);
    row['price'] = '81000.1';
    expect(() => mapAttachedOrderQuery(payload, intent, liveOrderClock), throwsFormatException);
  });
  for (final field in ['drivenOn', 'execution', 'limitPrice', 'protectedQuantity']) {
    test('corrupt durable exit terms fail closed $field', () {
      final intent = attachedIntent();
      final row = encodeRecoveryRecord(
        OrderRecoveryRecord(query: OrderQuery.capture(intent), createdAt: liveOrderClock),
      );
      final attachment = (row['draft'] as Map)['attachment'] as Map;
      if (field == 'protectedQuantity') {
        row[field] = '0.0005';
      } else if (field == 'drivenOn') {
        attachment[field] = 'NEW';
      } else {
        (attachment['takeProfit'] as Map)[field] = 'invalid';
      }
      expect(() => decodeRecoveryRecord(row), throwsFormatException);
    });
  }
  test('v1-v3 cannot silently accept modern exit fields', () {
    final row = encodeRecoveryRecord(
      OrderRecoveryRecord(query: OrderQuery.capture(attachedIntent()), createdAt: liveOrderClock),
    );
    for (final version in [1, 2, 3]) {
      expect(
        () => decodeRecoveryJournal(
          jsonEncode({
            'version': version,
            'records': [row],
          }),
        ),
        throwsFormatException,
      );
    }
  });
  test('host journal restart retains manual exit and original full protected quantity', () async {
    final directory = await Directory.systemTemp.createTemp('vanta-exit-v4-');
    final journal = FileOrderRecoveryJournal(() async => directory);
    final restart = FileOrderRecoveryJournal(() async => directory);
    addTearDown(() async {
      await journal.close();
      await restart.close();
      await directory.delete(recursive: true);
    });
    await journal.reload();
    final intent = attachedIntent(
      context: liveCloseContext(short: true, quantity: '0.002'),
      quantity: '0.003',
      protection: const LiveOrderAttachment(
        stopLoss: AttachedExit(
          kind: LiveOrderTriggerKind.stop,
          price: '79000',
          execution: AttachedExitExecution.manualLimit,
          limitPrice: '78999.9',
        ),
      ),
    );
    await journal.prepare(
      OrderRecoveryRecord(query: OrderQuery.capture(intent), createdAt: liveOrderClock),
    );
    await restart.reload();
    final saved = restart.snapshot.records.single.query;
    expect(saved.protectedQuantity, '0.003');
    expect(saved.draft.attachment!.stopLoss!.limitPrice, '78999.9');
    expect(saved.draft.attachment!.drivenOn, AttachedOrderDrivenOn.partialOrFilled);
    expect(buildStrategyLegs(saved), intent.strategyLegs);
  });
}
