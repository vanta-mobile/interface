import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/data/order_recovery_codec.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/live_order.dart';

void main() {
  for (final peg in LiveOrderPeg.values) {
    for (final buy in [true, false]) {
      for (final hedge in [true, false]) {
        test('ordinary ${peg.wire} buy=$buy hedge=$hedge freezes original query terms', () {
          final i = liveIntent(peg: peg, buy: buy, hedge: hedge);
          expect(i.context.validate(i.draft), null);
          expect(i.draft.price, '');
          expect(i.parameters['price'], '0');
          expect(i.parameters['pegPriceType'], peg.wire);
          expect(i.parameters['side'], buy ? 'BUY' : 'SELL');
          expect(i.parameters['positionSide'], hedge ? (buy ? 'LONG' : 'SHORT') : 'BOTH');
          final record = OrderRecoveryRecord(
            query: OrderQuery.capture(i),
            createdAt: liveOrderClock,
          );
          final restored = decodeRecoveryJournal(encodeRecoveryJournal([record])).single;
          expect(restored.query.draft.peg, peg);
          expect(restored.query.draft.price, '');
          expect(mapRecoveredOrderQuery(liveQueryPayload(i), restored.query).orderId, '12345');
        });
        test('dedicated close ${peg.wire} short=$buy hedge=$hedge keeps reduction scope', () {
          final i = liveCloseIntent(peg: peg, market: false, short: buy, hedge: hedge);
          expect(i.context.validate(i.draft), null);
          expect(i.parameters['price'], '0');
          expect(i.parameters['pegPriceType'], peg.wire);
          expect(i.parameters['reduceOnly'], hedge ? null : 'true');
          expect(i.parameters['positionSide'], hedge ? (buy ? 'SHORT' : 'LONG') : 'BOTH');
          expect(
            i.context.estimatedClosePnl(i.draft),
            Decimal.parse(
              peg == LiveOrderPeg.counterparty
                  ? buy
                        ? '-5.005'
                        : '4.995'
                  : buy
                  ? '-4.995'
                  : '5.005',
            ),
          );
          expect(mapLiveOrderQuery(liveQueryPayload(i), i).needsRecheck, false);
        });
      }
    }
    for (final kind in LiveOrderTriggerKind.values) {
      test('conditional ${peg.wire} $kind resolves at trigger and retains trigger terms', () {
        final trigger = LiveOrderTrigger(
          kind: kind,
          price: kind == LiveOrderTriggerKind.stop ? '80500' : '79500',
          basis: LiveOrderTriggerBasis.mark,
          protect: true,
        );
        final i = liveIntent(peg: peg, trigger: trigger);
        expect(i.context.validate(i.draft), null);
        expect(i.parameters['type'], kind == LiveOrderTriggerKind.stop ? 'STOP' : 'TAKE_PROFIT');
        expect(i.parameters['stopPrice'], trigger.price);
        expect(i.parameters['price'], '0');
        expect(i.context.referenceExecutionPrice(i.draft), null);
        final payload = liveQueryPayload(i)..['type'] = 'LIMIT';
        expect(mapLiveOrderQuery(payload, i).needsRecheck, false);
        payload['stopPrice'] = '1';
        expect(() => mapLiveOrderQuery(payload, i), throwsFormatException);
      });
    }
  }
  for (final policy in LiveOrderTimeInForce.values) {
    test('ordinary BBO preserves supported time-in-force $policy', () {
      final i = liveIntent(peg: LiveOrderPeg.queue, timeInForce: policy);
      expect(i.context.validate(i.draft), null);
      expect(i.parameters['timeInForce'], policy.wire);
      final restricted = liveContext(policies: {LiveOrderTimeInForce.gtc});
      if (policy != LiveOrderTimeInForce.gtc) {
        expect(restricted.validate(i.draft), 'liveOrderTimeInForceUnavailable');
      }
    });
  }
  test('incompatible shapes never validate or deserialize as ordinary BBO', () {
    final drafts = [
      liveDraft(peg: LiveOrderPeg.queue),
      liveDraft(peg: LiveOrderPeg.queue, price: '0'),
      liveDraft(peg: LiveOrderPeg.queue, price: '', market: true),
      liveDraft(peg: LiveOrderPeg.queue, price: '', quickEntry: true, market: true),
      liveDraft(
        peg: LiveOrderPeg.queue,
        price: '',
        market: true,
        trailing: const LiveOrderTrailing(callbackRate: '1'),
      ),
      liveDraft(
        peg: LiveOrderPeg.queue,
        price: '',
        attachment: const LiveOrderAttachment(
          takeProfit: AttachedExit(kind: LiveOrderTriggerKind.takeProfit, price: '81000'),
        ),
      ),
      liveDraft(
        peg: LiveOrderPeg.queue,
        price: '',
        market: true,
        entireClose: true,
        closingSide: 'BOTH',
        quantity: '',
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '79000'),
      ),
    ];
    for (final d in drafts) {
      expect(liveContext().validate(d), 'liveOrderPegInvalid');
      final i = LiveOrderIntent(
        context: liveContext(),
        draft: d,
        clientOrderId: 'invalid',
        revision: 0,
      );
      final row = encodeRecoveryRecord(
        OrderRecoveryRecord(query: OrderQuery.capture(i), createdAt: liveOrderClock),
      );
      expect(() => decodeRecoveryRecord(row), throwsFormatException);
    }
  });
  test('BBO current book estimate preserves quantity filters', () {
    final i = liveIntent(peg: LiveOrderPeg.counterparty);
    final context = liveContext(bid: '79999', ask: '80001');
    expect(context.referenceExecutionPrice(i.draft), Decimal.parse('80001'));
    expect(context.estimatedOpeningMargin(i.draft), Decimal.parse('8.0001'));
    expect(i.context.referenceExecutionPrice(i.draft), null);
    expect(
      i.context.validate(liveDraft(peg: LiveOrderPeg.queue, price: '', quantity: '0.0001')),
      'liveOrderQuantityFilter',
    );
    expect(
      i.context.validate(liveDraft(peg: LiveOrderPeg.queue, price: '', quantity: '1e3')),
      'liveOrderInvalidQuantity',
    );
    expect(
      liveContext(orderTypes: {'LIMIT', 'MARKET'}).validate(
        liveDraft(
          peg: LiveOrderPeg.queue,
          price: '',
          trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '80500'),
        ),
      ),
      'liveOrderTypeUnavailable',
    );
  });
  for (final wrong in [null, '', 'QUEUE_1', 'COUNTERPARTY_3', 'unknown', 1]) {
    test('query rejects missing/changed/deeper peg $wrong', () {
      final i = liveIntent(peg: LiveOrderPeg.counterparty);
      final payload = liveQueryPayload(i)..['pegPriceType'] = wrong;
      expect(() => mapLiveOrderQuery(payload, i), throwsFormatException);
    });
  }
  for (final price in ['0', '80001.000000000000000001', '-1', 'NaN', null, 80000]) {
    test('BBO query validates engine-resolved numeric price $price', () {
      final i = liveIntent(peg: LiveOrderPeg.queue);
      final payload = liveQueryPayload(i)..['price'] = price;
      if (price == '0' || price == '80001.000000000000000001') {
        expect(mapLiveOrderQuery(payload, i).needsRecheck, false);
      } else {
        expect(() => mapLiveOrderQuery(payload, i), throwsFormatException);
      }
    });
  }
  test('fixed-price and market queries reject an unexpected nonempty peg', () {
    for (final market in [false, true]) {
      final i = liveIntent(market: market);
      final payload = liveQueryPayload(i)..['pegPriceType'] = 'QUEUE_1';
      expect(() => mapLiveOrderQuery(payload, i), throwsFormatException);
      payload['pegPriceType'] = '';
      expect(mapLiveOrderQuery(payload, i).needsRecheck, false);
    }
  });
  test('v1/v2 survive upgrade; ordinary pegs require v3 and valid level-one identifiers', () {
    OrderRecoveryRecord record(LiveOrderIntent i) =>
        OrderRecoveryRecord(query: OrderQuery.capture(i), createdAt: liveOrderClock);
    for (final version in [1, 2]) {
      final row = encodeRecoveryRecord(record(liveIntent()));
      expect(
        decodeRecoveryJournal(
          jsonEncode({
            'version': version,
            'records': [row],
          }),
        ).single.query.draft.peg,
        null,
      );
      final pegged = encodeRecoveryRecord(record(liveIntent(peg: LiveOrderPeg.queue)));
      expect(
        () => decodeRecoveryJournal(
          jsonEncode({
            'version': version,
            'records': [pegged],
          }),
        ),
        throwsFormatException,
      );
    }
    for (final value in [null, '', 'QUEUE_20', 'COUNTERPARTY_3', 1]) {
      final row = encodeRecoveryRecord(record(liveIntent(peg: LiveOrderPeg.queue)));
      (row['draft'] as Map)['peg'] = value;
      expect(() => decodeRecoveryRecord(row), throwsFormatException);
    }
  });
}
