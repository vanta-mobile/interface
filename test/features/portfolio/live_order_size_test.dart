import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/data/order_recovery_codec.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';

import '../../support/live_order.dart';

void main() {
  LiveOrderContext context({
    String minimum = '0.01',
    String step = '0.01',
    String maximum = '10000',
    String marketStep = '0.01',
    String price = '0.6989',
    String? bid = '0.69',
    String? ask = '0.69890',
    int leverage = 10,
  }) {
    final source = liveContext();
    final payload = liveExchangePayload();
    final symbol = (payload['symbols'] as List).single as Map<String, dynamic>;
    symbol['symbol'] = 'ASTERUSDT';
    symbol['baseAsset'] = 'ASTER';
    symbol['filters'] = [
      {
        'filterType': 'PRICE_FILTER',
        'minPrice': '0.0001',
        'maxPrice': '10000',
        'tickSize': '0.0001',
      },
      {'filterType': 'LOT_SIZE', 'minQty': minimum, 'maxQty': maximum, 'stepSize': step},
      {
        'filterType': 'MARKET_LOT_SIZE',
        'minQty': minimum,
        'maxQty': maximum,
        'stepSize': marketStep,
      },
      {'filterType': 'MIN_NOTIONAL', 'notional': '5'},
      {'filterType': 'PERCENT_PRICE', 'multiplierUp': '1.02', 'multiplierDown': '0.98'},
    ];
    return LiveOrderContext(
      address: source.address,
      rules: mapLiveOrderRules(payload, 'ASTERUSDT'),
      mode: source.mode,
      marginMode: source.marginMode,
      leverage: leverage,
      markPrice: Decimal.parse(price),
      lastPrice: Decimal.parse(price),
      receivedAt: source.receivedAt,
      positions: source.positions,
      funds: source.funds,
      bid: bid == null ? null : Decimal.parse(bid),
      ask: ask == null ? null : Decimal.parse(ask),
    );
  }

  OrderSizeResolution resolve(String input, {LiveOrderContext? data, LiveOrderDraft? draft}) =>
      LiveOrderSize(
        unit: OrderSizeUnit.quote,
        text: input,
      ).resolve(data ?? context(), draft ?? liveDraft(market: true, price: ''));

  test('PRD 70 USDT buys exactly 100.15 ASTER, reference notional 69.994835', () {
    final value = resolve('70');
    expect(value.failure, null);
    expect(value.quantity, '100.15');
    expect(value.estimatedNotional, Decimal.parse('69.994835'));
    expect(value.basis, OrderSizeReference.ask);
    expect(value.referenceAt, liveOrderClock);
    expect(value.converted, true);
  });
  for (final leverage in [1, 10, 125]) {
    test('amount is not multiplied by leverage $leverage', () {
      expect(resolve('70', data: context(leverage: leverage)).quantity, '100.15');
    });
  }
  test('market sell uses bid, never buy ask', () {
    final value = resolve('70', draft: liveDraft(market: true, buy: false));
    expect(value.quantity, '101.44');
    expect(value.reference, Decimal.parse('0.69'));
    expect(value.basis, OrderSizeReference.bid);
  });
  for (final buy in [true, false]) {
    test('missing required market quote has no Last/Mark/opposite fallback $buy', () {
      final value = resolve(
        '70',
        data: context(ask: buy ? null : '1', bid: buy ? '1' : null),
        draft: liveDraft(market: true, buy: buy),
      );
      expect(value.failure, 'liveAmountReferenceUnavailable');
      expect(value.quantity, isEmpty);
    });
  }
  test('limit conversion uses entered price even when book missing', () {
    final value = resolve(
      '70',
      data: context(ask: null, bid: null),
      draft: liveDraft(price: '0.7'),
    );
    expect(value.quantity, '100');
    expect(value.basis, OrderSizeReference.limit);
    expect(value.estimatedNotional, Decimal.fromInt(70));
  });
  test('ordinary market uses MARKET_LOT_SIZE, limit uses LOT_SIZE', () {
    final data = context(marketStep: '1');
    expect(resolve('70', data: data).quantity, '100.01');
    expect(
      resolve(
        '70',
        data: data,
        draft: liveDraft(price: '0.6989'),
      ).quantity,
      '100.15',
    );
  });
  for (final (input, quantity) in [
    ('1', '0.33'),
    ('0.99', '0.33'),
    ('0.989999999999999999999999999999', '0.32'),
    ('0.990000000000000000000000000001', '0.33'),
  ]) {
    test('exact rational division and floor $input', () {
      expect(resolve(input, data: context(ask: '3')).quantity, quantity);
    });
  }
  test('nonzero minimum offset remains aligned to exchange rule', () {
    final value = resolve(
      '1',
      data: context(minimum: '0.003', step: '0.01', marketStep: '0.01', ask: '3'),
    );
    expect(value.quantity, '0.333');
    expect(value.estimatedNotional, Decimal.parse('0.999'));
  });
  for (final input in ['0.001', '0.006988999999999999999999']) {
    test('below minimum/step blocks, never rounds up $input', () {
      expect(resolve(input).failure, 'liveAmountBelowStep');
    });
  }
  test('exact minimum amount accepts one step', () {
    expect(resolve('0.006989').quantity, '0.01');
  });
  test('malformed exchange minimum rejected before amount conversion', () {
    expect(() => context(minimum: '0'), throwsFormatException);
  });
  test('exceeding maximum is rejected without clamping', () {
    expect(resolve('70', data: context(maximum: '100')).failure, 'liveOrderQuantityFilter');
  });
  for (final input in ['', '0', '-1', '+1', 'NaN', '1e3', '1,000', '.5', '1.', '1 0', '9' * 81]) {
    test('malformed quote amount rejected: $input', () {
      expect(resolve(input).failure, 'liveAmountInvalid');
    });
  }
  test('surrounding whitespace trimmed without changing exact amount', () {
    expect(resolve(' 70.000000000000000001 ').input, Decimal.parse('70.000000000000000001'));
  });
  test('base input remains exact and downstream validation rejects off-step', () {
    const size = LiveOrderSize(unit: OrderSizeUnit.base, text: ' 0.0015 ');
    final data = liveContext();
    final result = size.resolve(data, liveDraft());
    expect(result.quantity, '0.0015');
    expect(result.converted, false);
    expect(data.validate(liveDraft(quantity: result.quantity)), 'liveOrderQuantityFilter');
  });
  test('entire-close ignores dormant invalid quote input and transmits no quantity', () {
    final original = liveCloseIntent(
      entireClose: true,
      trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '78000'),
    );
    final size = const LiveOrderSize(
      unit: OrderSizeUnit.quote,
      text: 'bad',
    ).resolve(original.context, original.draft);
    expect(size.failure, null);
    expect(size.quantity, isEmpty);
    expect(size.converted, false);
    expect(original.parameters.containsKey('quantity'), false);
  });
  const trigger = LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '0.8');
  for (final market in [true, false]) {
    test('conditional $market selects trigger or fixed limit and LOT_SIZE', () {
      final value = resolve(
        '70',
        data: context(marketStep: '1'),
        draft: liveDraft(market: market, price: market ? '' : '0.7', trigger: trigger),
      );
      expect(value.quantity, market ? '87.5' : '100');
      expect(value.basis, market ? OrderSizeReference.trigger : OrderSizeReference.limit);
    });
  }
  test('ordinary BBO conversion labels selected book, not Mark or trigger', () {
    final regular = resolve(
      '70',
      draft: liveDraft(price: '', peg: LiveOrderPeg.counterparty),
    );
    expect(regular.quantity, '100.15');
    expect(regular.basis, OrderSizeReference.ask);
    final conditional = resolve(
      '70',
      draft: liveDraft(price: '', peg: LiveOrderPeg.queue, trigger: trigger),
    );
    expect(conditional.quantity, '101.44');
    expect(conditional.basis, OrderSizeReference.bid);
  });
  for (final basis in LiveOrderTriggerBasis.values) {
    test('trailing uses chosen snapshot $basis', () {
      final value = resolve(
        '80',
        data: liveContext(lastPrice: '40000'),
        draft: liveDraft(
          market: true,
          price: '',
          trailing: LiveOrderTrailing(callbackRate: '1', basis: basis),
        ),
      );
      expect(value.quantity, basis == LiveOrderTriggerBasis.mark ? '0.001' : '0.002');
      expect(
        value.basis,
        basis == LiveOrderTriggerBasis.mark ? OrderSizeReference.mark : OrderSizeReference.last,
      );
    });
  }
  test('trailing Last missing cannot fall back to Mark', () {
    expect(
      resolve(
        '80',
        data: liveContext(lastPrice: null),
        draft: liveDraft(market: true, trailing: const LiveOrderTrailing(callbackRate: '1')),
      ).failure,
      'liveAmountReferenceUnavailable',
    );
  });
  test('invalid limit and trigger references block conversion', () {
    for (final text in ['', '0', '-1', '1e3']) {
      expect(
        resolve('70', draft: liveDraft(price: text)).failure,
        'liveAmountReferenceUnavailable',
      );
      expect(
        resolve(
          '70',
          draft: liveDraft(
            market: true,
            trigger: LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: text),
          ),
        ).failure,
        'liveAmountReferenceUnavailable',
      );
    }
  });
  test('quantity replacement preserves every independent draft field', () {
    const attachment = LiveOrderAttachment();
    const trailing = LiveOrderTrailing(callbackRate: '1');
    final before = liveDraft(
      buy: false,
      market: true,
      reduceOnly: true,
      closingSide: 'SHORT',
      timeInForce: LiveOrderTimeInForce.postOnly,
      trigger: trigger,
      entireClose: true,
      trailing: trailing,
      quickEntry: true,
      attachment: attachment,
      peg: LiveOrderPeg.queue,
    );
    final after = before.withQuantity('100.15');
    expect(after.quantity, '100.15');
    expect(after.buy, before.buy);
    expect(after.market, before.market);
    expect(after.price, before.price);
    expect(after.reduceOnly, before.reduceOnly);
    expect(after.closingSide, before.closingSide);
    expect(after.timeInForce, before.timeInForce);
    expect(after.trigger, same(trigger));
    expect(after.entireClose, before.entireClose);
    expect(after.trailing, same(trailing));
    expect(after.quickEntry, before.quickEntry);
    expect(after.attachment, same(attachment));
    expect(after.peg, before.peg);
  });
  test('first valid Last seeds limit; no Mark fallback or price repair', () {
    expect(initialLiveLimitPrice(liveContext()), '80001');
    for (final text in [null, '0', '-1', '80000.01', '1000001']) {
      expect(initialLiveLimitPrice(liveContext(lastPrice: text)), null, reason: '$text');
    }
  });
  test('journal and query retain confirmed base quantity after price changes', () {
    final data = liveContext(ask: '80000');
    const input = LiveOrderSize(unit: OrderSizeUnit.quote, text: '80');
    final entry = liveDraft(market: true, price: '');
    final draft = entry.withQuantity(input.resolve(data, entry).quantity);
    final intent = LiveOrderIntent(
      context: data,
      draft: draft,
      clientOrderId: 'vanta-size-123',
      revision: 0,
    );
    final record = OrderRecoveryRecord(
      query: OrderQuery.capture(intent),
      createdAt: liveOrderClock,
    );
    final encoded = encodeRecoveryJournal([record]);
    final restored = decodeRecoveryJournal(encoded).single;
    expect(input.resolve(liveContext(ask: '40000'), entry).quantity, '0.002');
    expect(restored.query.draft.quantity, '0.001');
    expect(restored.query.clientOrderId, intent.clientOrderId);
    expect(intent.parameters['quantity'], '0.001');
    expect(intent.parameters.containsKey('quantityUnit'), false);
    expect(mapRecoveredOrderQuery(liveQueryPayload(intent), restored.query).orderId, '12345');
    expect(encoded, isNot(contains('quoteAmount')));
    expect(encoded, isNot(contains('80000')));
  });
}
