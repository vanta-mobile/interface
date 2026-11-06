import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/attached_entry_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity_preview.dart';
import 'package:vanta/features/portfolio/domain/main_order_post_trade.dart';
import 'package:vanta/features/portfolio/domain/main_order_price_assumption.dart';
import 'package:vanta/features/portfolio/domain/main_order_revaluation.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_revaluation.dart';

Matcher failure(String key) => throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', key));

void main() {
  for (final (peg, buy, price, basis, cost, maximum) in [
    (LiveOrderPeg.counterparty, true, '101', OrderSizeReference.ask, '22.2', '9.009'),
    (LiveOrderPeg.counterparty, false, '99', OrderSizeReference.bid, '22', '9.09'),
    (LiveOrderPeg.queue, true, '99', OrderSizeReference.bid, '19.8', '10.101'),
    (LiveOrderPeg.queue, false, '101', OrderSizeReference.ask, '20.2', '9.9'),
  ]) {
    for (final conditional in [false, true]) {
      test('BBO $peg buy=$buy conditional=$conditional shares selected book across estimates', () {
        final snapshot = assembledCapacity();
        final draft = liveDraft(
          price: '',
          peg: peg,
          buy: buy,
          quantity: '2',
          trigger: conditional
              ? const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '120')
              : null,
        );
        final preview = MainOrderCapacityPreview(
          snapshot: snapshot,
          draft: draft,
          unit: OrderSizeUnit.base,
          input: '2',
        );
        final side = buy ? preview.buy : preview.sell;
        expect(side.failure, null);
        expect(side.notional, d(price) * d('2'));
        expect(side.cost!.total, d(cost).toRational());
        expect(side.capacity!.maximum, d(maximum));
        final conversion = LiveOrderSize(
          unit: OrderSizeUnit.quote,
          text: '${d(price) * d('2')}',
        ).resolve(snapshot.context, draft);
        expect(conversion.quantity, '2');
        expect(conversion.reference, d(price));
        expect(conversion.basis, basis);
        final post = mainOrderPostTrade(
          snapshot: withRevaluationFacts(snapshot, takerFee: d('0.001')),
          context: snapshot.context,
          draft: draft,
          quantity: d('2'),
          cost: side.cost!,
        )!;
        expect(post.executionPrice, d(price));
        expect(post.entryValue, (d(price) * d(buy ? '2' : '-2')).toRational());
        // The indicative book never becomes a submitted manual price.
        final intent = LiveOrderIntent(
          context: snapshot.context,
          draft: draft,
          clientOrderId: 'bbo',
          revision: 0,
        );
        expect(intent.parameters['price'], '0');
        expect(intent.parameters['pegPriceType'], peg.wire);
      });
    }
  }
  for (final (bid, ask) in [
    (null, '101'),
    ('99', null),
    ('0', '101'),
    ('99', '0'),
    ('102', '101'),
  ]) {
    test('missing/invalid BBO book $bid/$ask has no Mark or trigger fallback', () {
      final context = liveContext(bid: bid, ask: ask);
      final draft = liveDraft(
        price: '',
        peg: LiveOrderPeg.queue,
        trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '80500'),
      );
      expect(context.referenceExecutionPrice(draft), null);
      expect(
        LiveOrderSize(unit: OrderSizeUnit.quote, text: '100').resolve(context, draft).failure,
        'liveAmountReferenceUnavailable',
      );
      final preview = MainOrderCapacityPreview.manual(
        context: context,
        draft: draft,
        unit: OrderSizeUnit.base,
        input: '1',
      );
      expect(preview.buy.failure!.key, 'liveCapacityPriceUnavailable');
      expect(preview.sell.failure!.key, 'liveCapacityPriceUnavailable');
      expect(
        () => MainOrderPriceAssumption.resolve(context, draft),
        failure(bid == null || ask == null ? 'liveCapacityPriceUnavailable' : 'accountDataInvalid'),
      );
    });
  }
  test('ordinary BBO decimal quote preserves sub-binary precision and book receipt', () {
    final context = liveContext(
      bid: '9007199254740993.000000000000000001',
      ask: '9007199254740993.000000000000000002',
    );
    final draft = liveDraft(price: '', peg: LiveOrderPeg.counterparty);
    final size = LiveOrderSize(
      unit: OrderSizeUnit.quote,
      text: '9007199254740.993000000000000000002',
    ).resolve(context, draft);
    expect(size.quantity, '0.001');
    expect(size.estimatedNotional, d('9007199254740.993000000000000000002'));
    expect(size.referenceAt, context.receivedAt);
  });
  test('minimum notional checks current peg reference instead of Mark', () {
    final snapshot = assembledCapacity();
    // Mark100 would accept0.05; selected bid99 is below the5 USDT minimum.
    final draft = liveDraft(price: '', peg: LiveOrderPeg.queue, quantity: '0.05');
    final preview = MainOrderCapacityPreview(
      snapshot: snapshot,
      draft: draft,
      unit: OrderSizeUnit.base,
      input: '0.05',
    );
    expect(preview.buy.failure!.key, 'liveOrderNotionalFilter');
    expect(preview.sell.failure, null);
    expect(snapshot.context.validate(draft), 'liveOrderNotionalFilter');
  });
  for (final (peg, buyNumerator, sellNumerator) in [
    (LiveOrderPeg.queue, '79.099', '120.899'),
    (LiveOrderPeg.counterparty, '81.101', '118.901'),
  ]) {
    test('BBO $peg independent full-fill liquidation uses selected current entry and fee', () {
      final raw = capacityAccountPayload();
      raw['assets'] = [
        {
          ...capacityAsset(),
          'availableBalance': '20',
          'crossWalletBalance': '20',
          'crossUnPnl': '0',
          'initialMargin': '0',
        },
      ];
      final snapshot = withRevaluationFacts(assembledCapacity(payload: raw), takerFee: d('0.001'));
      final valuation = revalueMainOrderCapacity(
        snapshot: snapshot,
        marks: revaluationMarks({'BTCUSDT': '100'}),
        references: {'BTCUSDT': revaluationReference()},
        indices: null,
        now: liveOrderClock,
      );
      final preview = MainOrderCapacityPreview(
        snapshot: snapshot,
        valuation: valuation,
        draft: liveDraft(price: '', peg: peg),
        unit: OrderSizeUnit.base,
        input: '1',
      );
      expect(preview.buy.failure, null);
      expect(preview.sell.failure, null);
      // Cross equity20 minus hypothetical entry fee plus entry PnL equals
      // maintenance0.005*P, with all arithmetic exact until display rounding.
      expect(preview.buy.liquidation, d(buyNumerator) / d('0.995'));
      expect(preview.sell.liquidation, d(sellNumerator) / d('1.005'));
    });
  }
  test('compound deeper BBO cannot silently acquire one-level capacity', () {
    final draft = liveDraft(
      price: '',
      attachment: const LiveOrderAttachment(
        entryPeg: AttachedEntryPeg.queue20,
        takeProfit: AttachedExit(kind: LiveOrderTriggerKind.takeProfit, price: '120'),
      ),
    );
    final preview = MainOrderCapacityPreview(
      snapshot: assembledCapacity(),
      draft: draft,
      unit: OrderSizeUnit.base,
      input: '2',
    );
    expect(preview.buy.failure!.key, 'liveCapacityPriceUnavailable');
    expect(preview.sell.capacity, null);
  });
  for (final peg in LiveOrderPeg.values) {
    test('positive resolved $peg LIMIT consumes pending capacity with margin corroboration', () {
      final raw = capacityAccountPayload();
      raw['positions'] = [capacityPosition(orderMargin: '20')];
      final order = {...capacityOrder(), 'pegPriceType': peg.wire};
      final result = assembledCapacity(payload: raw, orders: [order]);
      expect(result.exposure.currentNotional, d('200'));
      final repriced = revalueMainOrderCapacity(
        snapshot: withRevaluationFacts(result, orders: [order]),
        marks: revaluationMarks({'BTCUSDT': '120'}),
        references: {'BTCUSDT': revaluationReference(last: '120', bid: '119', ask: '121')},
        indices: null,
        now: liveOrderClock,
      );
      expect(repriced.exposure.currentNotional, d('200'));
      expect(repriced.availableMargin, d('130').toRational());
    });
    test('resolved $peg pending exposure keeps both hedge legs', () {
      final raw = capacityAccountPayload(hedge: true);
      raw['positions'] = [
        capacityPosition(side: 'LONG', orderMargin: '20'),
        capacityPosition(side: 'SHORT', orderMargin: '30'),
      ];
      final result = assembledCapacity(
        context: capacityContext(hedge: true, payload: raw),
        payload: raw,
        orders: [
          {...capacityOrder(positionSide: 'LONG'), 'pegPriceType': peg.wire},
          {
            ...capacityOrder(positionSide: 'SHORT', side: 'SELL', quantity: '4'),
            'orderId': 11,
            'pegPriceType': peg.wire,
          },
        ],
      );
      expect(result.exposure.currentNotional, d('500'));
    });
  }
  for (final (peg, price, type) in [
    ('QUEUE_1', '0', 'LIMIT'),
    ('COUNTERPARTY_1', '0', 'LIMIT'),
    ('QUEUE_20', '100', 'LIMIT'),
    ('UNKNOWN', '100', 'LIMIT'),
    ('QUEUE_1', '100', 'STOP'),
    ('COUNTERPARTY_1', '100', 'TAKE_PROFIT'),
    ('QUEUE_1', '100', 'MARKET'),
  ]) {
    test('unresolved or unsupported pending BBO $peg $type $price blocks capacity', () {
      expect(
        () => assembledCapacity(
          orders: [
            {...capacityOrder(), 'pegPriceType': peg, 'price': price, 'type': type},
          ],
        ),
        failure('liveCapacityPendingUnknown'),
      );
    });
  }
  test('other symbol resolved BBO occupies the shared cross budget at its fixed price', () {
    final raw = capacityAccountPayload();
    raw['positions'] = [capacityPosition(), capacityPosition(symbol: 'ETHUSDT', orderMargin: '20')];
    final order = {...capacityOrder(), 'symbol': 'ETHUSDT', 'pegPriceType': 'QUEUE_1'};
    final result = assembledCapacity(payload: raw);
    final priced = revalueMainOrderCapacity(
      snapshot: withRevaluationFacts(result, orders: [order]),
      marks: revaluationMarks({'BTCUSDT': '100'}),
      references: {'BTCUSDT': revaluationReference()},
      indices: null,
      now: liveOrderClock,
    );
    expect(priced.exposure.currentNotional, Decimal.zero);
    expect(priced.availableMargin, d('130').toRational());
  });
}
