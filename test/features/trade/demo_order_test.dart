import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/domain/demo_order.dart';

OrderDraft draft({
  bool market = true,
  String quantity = '0.01',
  String price = '80000',
  bool reduce = false,
  bool buy = true,
}) => OrderDraft(
  symbol: 'BTCUSDT',
  buy: buy,
  market: market,
  quantity: quantity,
  price: price,
  leverage: 10,
  reduceOnly: reduce,
);
void main() {
  test('decimal margin and fee are exact; invalid input and insufficient funds rejected', () {
    final order = draft(quantity: '0.00123', price: '81234.56');
    expect(order.notional, Decimal.parse('99.9185088'));
    expect(order.margin, Decimal.parse('9.99185088'));
    expect(order.fee, Decimal.parse('0.0499592544'));
    expect(draft(quantity: '0').validate(Decimal.fromInt(10000)), 'invalidQuantity');
    expect(draft(quantity: '0.000001').validate(Decimal.fromInt(10000)), 'invalidQuantity');
    expect(draft(price: '0').validate(Decimal.fromInt(10000)), 'invalidPrice');
    expect(draft(quantity: '100').validate(Decimal.fromInt(10000)), 'insufficient');
  });
  test('demo orders reserve funds; cancel releases reservation; close realizes PnL', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(accountProvider.notifier);
    expect(notifier.submit(draft()), 'connect');
    notifier.connect();
    expect(notifier.submit(draft(market: false)), null);
    var state = container.read(accountProvider);
    expect(state.orders, hasLength(1));
    expect(state.available, Decimal.fromInt(9920));
    notifier.cancel(state.orders.single.id);
    expect(container.read(accountProvider).available, Decimal.fromInt(10000));
    expect(notifier.submit(draft()), null);
    state = container.read(accountProvider);
    expect(state.positions, hasLength(1));
    expect(state.balance, Decimal.parse('9999.6'));
    notifier.close(state.positions.single.id, Decimal.fromInt(81000));
    state = container.read(accountProvider);
    expect(state.positions, isEmpty);
    expect(state.balance, Decimal.parse('10009.195'));
  });
  test('reduce only cannot create exposure; valid partial reduction keeps remaining quantity', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(accountProvider.notifier)..connect();
    expect(notifier.submit(draft(reduce: true, buy: false)), 'reduceHint');
    notifier.submit(draft());
    expect(notifier.submit(draft(reduce: true, buy: false, quantity: '0.005')), null);
    expect(container.read(accountProvider).positions.single.draft.quantity, '0.005');
  });
}
