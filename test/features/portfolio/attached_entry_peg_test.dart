import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/attached_order_mapper.dart';
import 'package:vanta/features/portfolio/data/order_recovery_codec.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/attached_entry_peg.dart';
import 'package:vanta/features/portfolio/domain/attached_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/attached_order.dart';
import '../../support/live_order.dart';
import '../../support/order_recovery.dart';

void main() {
  for (final wire in [
    'COUNTERPARTY_1',
    'COUNTERPARTY_3',
    'COUNTERPARTY_5',
    'COUNTERPARTY_10',
    'COUNTERPARTY_20',
    'QUEUE_1',
    'QUEUE_3',
    'QUEUE_5',
    'QUEUE_10',
    'QUEUE_20',
  ]) {
    for (final conditional in [false, true]) {
      test('documented compound peg $wire conditional=$conditional survives original-ID query', () {
        final peg = AttachedEntryPeg.values.singleWhere((p) => p.wire == wire);
        final intent = attachedIntent(
          peg: peg,
          trigger: conditional
              ? const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '80500')
              : null,
        );
        expect(intent.context.validate(intent.draft), null);
        expect(intent.draft.price, '');
        expect(() => intent.parameters, throwsStateError);
        final legs = jsonDecode(intent.strategyParameters['subOrderList']!) as List;
        expect((legs.first as Map)['price'], '0');
        expect((legs.first as Map)['pegPriceType'], wire);
        expect((legs.first as Map)['type'], conditional ? 'STOP' : 'LIMIT');
        expect((legs.first as Map)['stopPrice'], conditional ? '80500' : null);
        expect((legs.first as Map)['timeInForce'], 'GTC');
        expect((legs[1] as Map).containsKey('pegPriceType'), false);
        expect((legs[1] as Map).containsKey('price'), false);
        final snapshot = mapAttachedOrderQuery(attachedQuery(intent), intent, liveOrderClock);
        expect(snapshot.needsRecheck, false);
        expect(snapshot.executedQuantity, null);
        expect(snapshot.orderId, null);
        expect(snapshot.strategy!.strategyId, '9876');
        final record = OrderRecoveryRecord(
          query: OrderQuery.capture(intent),
          createdAt: liveOrderClock,
        );
        final json = encodeRecoveryJournal([record]);
        expect((jsonDecode(json) as Map)['version'], 4);
        final restored = decodeRecoveryJournal(json).single;
        expect(restored.query.draft.attachment!.entryPeg, peg);
        expect(restored.query.draft.price, '');
        expect(buildStrategyLegs(restored.query), legs);
        expect(
          mapRecoveredStrategyQuery(
            attachedQuery(intent),
            restored.query,
            liveOrderClock,
          ).strategy!.strategyId,
          '9876',
        );
      });
    }
  }
  for (final buy in [true, false]) {
    for (final hedge in [true, false]) {
      test('pegged entry preserves direction, exposure, linkage $buy $hedge', () {
        final intent = attachedIntent(buy: buy, hedge: hedge, peg: AttachedEntryPeg.queue1);
        expect(intent.context.validate(intent.draft), null);
        final legs = intent.strategyLegs;
        expect(legs.first['side'], buy ? 'BUY' : 'SELL');
        expect(legs.first['positionSide'], hedge ? (buy ? 'LONG' : 'SHORT') : 'BOTH');
        expect(legs[1]['quantity'], '0.001');
        expect(legs[1]['reduceOnly'], hedge ? null : 'true');
        expect(legs[1]['firstDrivenOn'], 'PARTIALLY_FILLED_OR_FILLED');
        expect(legs[1]['secondDrivenOn'], 'PARTIALLY_FILLED_OR_FILLED');
      });
    }
  }
  for (final policy in LiveOrderTimeInForce.values) {
    test('compound BBO respects supported time in force $policy', () {
      final intent = attachedIntent(peg: AttachedEntryPeg.queue3, policy: policy);
      expect(
        intent.context.validate(intent.draft),
        policy == LiveOrderTimeInForce.ioc ? 'attachedOrderIocUnavailable' : null,
      );
      if (policy != LiveOrderTimeInForce.ioc) {
        expect(intent.strategyLegs.first['timeInForce'], policy.wire);
      }
    });
  }
  test('conditional take-profit entry keeps trigger policy distinct from engine price', () {
    final intent = attachedIntent(
      peg: AttachedEntryPeg.counterparty1,
      trigger: const LiveOrderTrigger(
        kind: LiveOrderTriggerKind.takeProfit,
        price: '79500',
        basis: LiveOrderTriggerBasis.mark,
        protect: true,
      ),
    );
    expect(intent.context.validate(intent.draft), null);
    expect(intent.strategyLegs.first['type'], 'TAKE_PROFIT');
    expect(intent.strategyLegs.first['stopPrice'], '79500');
    expect(intent.strategyLegs.first['workingType'], 'MARK_PRICE');
    expect(intent.strategyLegs.first['priceProtect'], 'true');
    expect(intent.strategyLegs.first['price'], '0');
    final payload = attachedQuery(intent);
    final row = (payload['subOrders'] as List).first as Map;
    row['origType'] = 'TAKE_PROFIT';
    row['type'] = 'LIMIT';
    expect(mapAttachedOrderQuery(payload, intent, liveOrderClock).needsRecheck, false);
  });
  test('BBO cannot leak into market, reducing, trailing, quick, empty or fixed-price shapes', () {
    final protection = attachedProtection(peg: AttachedEntryPeg.queue1);
    final drafts = [
      liveDraft(attachment: protection), // positive user-entered limit
      liveDraft(price: '0', attachment: protection), // sentinel belongs only at transport boundary
      liveDraft(market: true, price: '', attachment: protection),
      liveDraft(price: '', reduceOnly: true, attachment: protection),
      liveDraft(price: '', closingSide: 'BOTH', attachment: protection),
      liveDraft(market: true, price: '', quickEntry: true, attachment: protection),
      liveDraft(
        market: true,
        price: '',
        trailing: const LiveOrderTrailing(callbackRate: '1'),
        attachment: protection,
      ),
      liveDraft(
        price: '',
        attachment: const LiveOrderAttachment(entryPeg: AttachedEntryPeg.queue1),
      ),
    ];
    for (final draft in drafts) {
      expect(liveContext().validate(draft), 'attachedEntryPegInvalid');
      expect(
        liveContext().rules.validate(draft, Decimal.parse('80000')),
        'attachedEntryPegInvalid',
      );
    }
    final ordinary = liveDraft(price: '0');
    expect(liveContext().validate(ordinary), 'liveOrderInvalidPrice');
  });
  test('reference estimates use Mark/trigger, never zero or a guessed nth-level quote', () {
    final intent = attachedIntent(peg: AttachedEntryPeg.counterparty20);
    expect(intent.context.referenceExecutionPrice(intent.draft), Decimal.parse('80000'));
    expect(intent.context.estimatedOpeningMargin(intent.draft), Decimal.parse('8'));
    final conditional = attachedIntent(
      peg: AttachedEntryPeg.queue20,
      trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '80500'),
    );
    expect(conditional.context.referenceExecutionPrice(conditional.draft), Decimal.parse('80500'));
    expect(conditional.context.estimatedOpeningMargin(conditional.draft), Decimal.parse('8.05'));
    final exchange = liveExchangePayload();
    final filters = ((exchange['symbols'] as List).single as Map)['filters'] as List;
    (filters.singleWhere((f) => (f as Map)['filterType'] == 'MIN_NOTIONAL') as Map)['notional'] =
        '100';
    final rules = mapLiveOrderRules(exchange, 'BTCUSDT');
    expect(rules.validate(intent.draft, Decimal.parse('80000')), 'liveOrderNotionalFilter');
  });
  test(
    'BBO bracket direction is engine-checked; invalid exits and entry triggers still rejected',
    () {
      final bracket = LiveOrderAttachment(
        entryPeg: AttachedEntryPeg.queue1,
        takeProfit: const AttachedExit(kind: LiveOrderTriggerKind.takeProfit, price: '79999'),
      );
      expect(liveContext().validate(liveDraft(price: '', attachment: bracket)), null);
      final wrongTick = LiveOrderAttachment(
        entryPeg: AttachedEntryPeg.queue1,
        takeProfit: const AttachedExit(kind: LiveOrderTriggerKind.takeProfit, price: '81000.01'),
      );
      expect(
        liveContext().validate(liveDraft(price: '', attachment: wrongTick)),
        'liveOrderTriggerFilter',
      );
      final intent = attachedIntent(
        peg: AttachedEntryPeg.queue1,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '79900'),
      );
      expect(intent.context.validate(intent.draft), 'liveOrderTriggerImmediate');
    },
  );
  for (final mutation in <String, Object?>{
    'absent': null,
    'empty': '',
    'unknown': 'MID_PRICE',
    'different-depth': 'QUEUE_3',
    'different-side': 'COUNTERPARTY_1',
    'wrong-type': 1,
  }.entries) {
    test('a zero entry price cannot resolve wrong peg ${mutation.key}', () {
      final intent = attachedIntent(peg: AttachedEntryPeg.queue1);
      final payload = attachedQuery(intent);
      final row = (payload['subOrders'] as List).first as Map;
      if (mutation.value == null) {
        row.remove('pegPriceType');
      } else {
        row['pegPriceType'] = mutation.value;
      }
      expect(() => mapAttachedOrderQuery(payload, intent, liveOrderClock), throwsFormatException);
    });
  }
  test('query rejects resolved positive price and unexpected peg on fixed entries or exits', () {
    final intent = attachedIntent(peg: AttachedEntryPeg.queue1);
    final payload = attachedQuery(intent);
    ((payload['subOrders'] as List).first as Map)['price'] = '80000';
    expect(() => mapAttachedOrderQuery(payload, intent, liveOrderClock), throwsFormatException);
    for (final sequence in [0, 1]) {
      final fixed = attachedIntent(), wrong = attachedQuery(attachedIntent());
      ((wrong['subOrders'] as List)[sequence] as Map)['pegPriceType'] = 'QUEUE_1';
      expect(() => mapAttachedOrderQuery(wrong, fixed, liveOrderClock), throwsFormatException);
    }
    final fixed = attachedIntent(), good = attachedQuery(attachedIntent());
    ((good['subOrders'] as List).first as Map)['pegPriceType'] = '';
    expect(mapAttachedOrderQuery(good, fixed, liveOrderClock).needsRecheck, false);
  });
  test('legacy v1 ordinary and compound records migrate without inventing a peg', () {
    for (final intent in [liveIntent(), attachedIntent()]) {
      final old = {
        'version': 1,
        'records': [
          legacyRecoveryFields(
            encodeRecoveryRecord(
              OrderRecoveryRecord(query: OrderQuery.capture(intent), createdAt: liveOrderClock),
            ),
          ),
        ],
      };
      final record = decodeRecoveryJournal(jsonEncode(old)).single;
      expect(record.query.draft.attachment?.entryPeg, null);
      expect(record.query.draft.price, '80000');
      final current = encodeRecoveryJournal([record]);
      expect((jsonDecode(current) as Map)['version'], 4);
      expect(decodeRecoveryJournal(current).single.query.clientOrderId, intent.clientOrderId);
    }
  });
  test('corrupt peg, price and scope cannot become trusted durable query expectations', () {
    final intent = attachedIntent(peg: AttachedEntryPeg.queue1);
    Map<String, Object?> record() => encodeRecoveryRecord(
      OrderRecoveryRecord(query: OrderQuery.capture(intent), createdAt: liveOrderClock),
    );
    for (final value in [null, 1, 'queue1', 'MID_PRICE', 'QUEUE_2']) {
      final row = record();
      ((row['draft'] as Map)['attachment'] as Map)['entryPeg'] = value;
      expect(() => decodeRecoveryRecord(row), throwsFormatException);
    }
    for (final mutation in <String, Object?>{
      'price': '0',
      'market': true,
      'reduceOnly': true,
      'closingSide': 'BOTH',
      'quickEntry': true,
    }.entries) {
      final row = record();
      (row['draft'] as Map)[mutation.key] = mutation.value;
      expect(() => decodeRecoveryRecord(row), throwsFormatException);
    }
    // Version 1 never defined BBO fields; a forged legacy row is not accepted.
    expect(
      () => decodeRecoveryJournal(
        jsonEncode({
          'version': 1,
          'records': [record()],
        }),
      ),
      throwsFormatException,
    );
  });
}
