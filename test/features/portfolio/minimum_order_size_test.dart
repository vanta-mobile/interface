import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/minimum_order_size.dart';

import '../../support/live_order.dart';

LiveOrderContext minimumContext({
  String minimum = '0.001',
  String step = '0.001',
  String marketMinimum = '0.001',
  String notional = '5',
  String maximum = '1000',
  String? ask = '101',
  String? bid = '99',
}) {
  final payload = liveExchangePayload();
  final symbol = (payload['symbols'] as List).single as Map<String, dynamic>;
  final filters = symbol['filters'] as List;
  for (final raw in filters) {
    final row = raw as Map<String, dynamic>;
    if (row['filterType'] == 'LOT_SIZE') {
      row.addAll({'minQty': minimum, 'maxQty': maximum, 'stepSize': step});
    }
    if (row['filterType'] == 'MARKET_LOT_SIZE') {
      row.addAll({'minQty': marketMinimum, 'maxQty': maximum, 'stepSize': step});
    }
    if (row['filterType'] == 'MIN_NOTIONAL') row['notional'] = notional;
  }
  final original = liveContext();
  return LiveOrderContext(
    address: original.address,
    rules: mapLiveOrderRules(payload, 'BTCUSDT'),
    mode: FuturesPositionMode.oneWay,
    marginMode: original.marginMode,
    leverage: 10,
    markPrice: Decimal.parse('100'),
    lastPrice: Decimal.parse('100'),
    receivedAt: original.receivedAt,
    positions: original.positions,
    ask: ask == null ? null : Decimal.parse(ask),
    bid: bid == null ? null : Decimal.parse(bid),
  );
}

void main() {
  Decimal? minimum(
    LiveOrderContext data,
    LiveOrderDraft draft,
    OrderSizeUnit unit, {
    bool both = false,
  }) => minimumOrderSize(context: data, draft: draft, unit: unit, bothDirections: both);

  test('limit minimum includes notional and rounds up on the quantity offset grid', () {
    final data = minimumContext(minimum: '0.003', step: '0.01');
    final draft = liveDraft(price: '100');
    final quantity = minimum(data, draft, OrderSizeUnit.base)!;
    expect(quantity, Decimal.parse('0.053'));
    expect(data.rules.validate(draft.withQuantity('$quantity'), data.markPrice), isNull);
    expect(
      data.rules.validate(
        draft.withQuantity('${quantity - Decimal.parse('0.01')}'),
        data.markPrice,
      ),
      'liveOrderNotionalFilter',
    );
    expect(minimum(data, draft, OrderSizeUnit.quote), Decimal.parse('5.3'));
  });

  test('market minimum uses its own lot filter and independent mark/notional and book/conversion prices', () {
    final data = minimumContext(minimum: '0.1', marketMinimum: '0.06');
    final draft = liveDraft(market: true);
    expect(minimum(data, draft, OrderSizeUnit.base), Decimal.parse('0.06'));
    expect(minimum(data, draft, OrderSizeUnit.quote), Decimal.parse('6.06'));
    expect(minimum(data, draft.withDirection(false), OrderSizeUnit.quote), Decimal.parse('5.94'));
    final shared = minimum(data, draft, OrderSizeUnit.quote, both: true)!;
    for (final buy in [true, false]) {
      final entry = draft.withDirection(buy);
      final size = LiveOrderSize(unit: OrderSizeUnit.quote, text: '$shared').resolve(data, entry);
      expect(size.failure, isNull);
      expect(data.rules.validate(entry.withQuantity(size.quantity), data.markPrice), isNull);
    }
  });

  test('conditional market uses limit lot filters, current mark for notional and trigger for amount conversion', () {
    final data = minimumContext(minimum: '0.07', marketMinimum: '0.1');
    final draft = liveDraft(
      market: true,
      trigger: const LiveOrderTrigger(
        kind: LiveOrderTriggerKind.stop,
        basis: LiveOrderTriggerBasis.mark,
        price: '180',
        protect: false,
      ),
    );
    expect(minimum(data, draft, OrderSizeUnit.base), Decimal.parse('0.07'));
    expect(minimum(data, draft, OrderSizeUnit.quote), Decimal.parse('12.6'));
  });

  test('BBO minimum follows the selected executable book and amount conversion', () {
    final data = minimumContext();
    final draft = liveDraft(price: '', peg: LiveOrderPeg.counterparty);
    final hint = minimum(data, draft, OrderSizeUnit.quote, both: true)!;
    for (final buy in [true, false]) {
      final entry = draft.withDirection(buy);
      final size = LiveOrderSize(unit: OrderSizeUnit.quote, text: '$hint').resolve(data, entry);
      expect(
        data.rules.validate(
          entry.withQuantity(size.quantity),
          data.markPrice,
          pegReference: data.referenceExecutionPrice(entry),
        ),
        isNull,
      );
    }
  });

  test('missing price, absent book, and impossible maximum never invent a minimum', () {
    expect(minimum(minimumContext(), liveDraft(price: ''), OrderSizeUnit.quote), isNull);
    expect(
      minimum(minimumContext(ask: null), liveDraft(market: true), OrderSizeUnit.quote),
      isNull,
    );
    expect(
      minimum(
        minimumContext(ask: null),
        liveDraft(price: '', peg: LiveOrderPeg.counterparty),
        OrderSizeUnit.base,
      ),
      isNull,
    );
    expect(
      minimum(minimumContext(maximum: '0.002'), liveDraft(price: '100'), OrderSizeUnit.base),
      isNull,
    );
  });

  test('one-way reduce-only keeps its notional exemption', () {
    final data = minimumContext();
    expect(
      minimum(data, liveDraft(reduceOnly: true, price: '100'), OrderSizeUnit.base),
      Decimal.parse('0.001'),
    );
  });

  test('tiny thresholds keep exact decimal digits and never round below a valid step', () {
    final data = minimumContext(
      minimum: '0.000000000000000003',
      step: '0.00000000000000001',
      notional: '0.0000000000000005',
    );
    final draft = liveDraft(price: '99.1');
    final hint = minimum(data, draft, OrderSizeUnit.quote)!;
    final size = LiveOrderSize(unit: OrderSizeUnit.quote, text: '$hint').resolve(data, draft);
    expect(size.failure, isNull);
    expect(data.rules.validate(draft.withQuantity(size.quantity), data.markPrice), isNull);
  });
}
