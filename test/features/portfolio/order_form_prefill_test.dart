import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/market/domain/market_precision.dart';
import 'package:vanta/features/portfolio/application/order_form_prefill_provider.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/order_form_prefill.dart';
import 'package:vanta/features/trade/application/navigation_provider.dart';

const _precision = MarketPrecision(priceTick: '0.1', quantityStep: '0.001');

OrderFormPrefill _prefill({String? price, LiveOrderSize? size, String symbol = 'BTCUSDT'}) =>
    OrderFormPrefill(symbol: symbol, type: OrderPrefillType.limit, price: price, size: size);

void main() {
  test('keeps exact market increments and drops anything that would need rounding', () {
    final kept = _prefill(
      price: '101.5',
      size: const LiveOrderSize(unit: OrderSizeUnit.base, text: '2.125'),
    ).fit(_precision);
    expect((kept.type, kept.price, kept.size?.text), (OrderPrefillType.limit, '101.5', '2.125'));

    final dropped = _prefill(
      price: '101.55',
      size: const LiveOrderSize(unit: OrderSizeUnit.base, text: '2.1255'),
    ).fit(_precision);
    expect((dropped.type, dropped.price, dropped.size), (OrderPrefillType.limit, null, null));

    for (final (text, kept) in [('100', true), ('100.25', true), ('100.255', false)]) {
      final quote = _prefill(
        size: LiveOrderSize(unit: OrderSizeUnit.quote, text: text),
      ).fit(_precision);
      expect(quote.size != null, kept, reason: text);
    }
    // Without known increments only well-formed positive decimals remain.
    final unknown = _prefill(
      price: '0',
      size: const LiveOrderSize(unit: OrderSizeUnit.base, text: '1'),
    ).fit(const MarketPrecision());
    expect((unknown.price, unknown.size?.text), (null, '1'));
  });

  test('a pending prefill is abandoned when the market or page changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prefill = container.read(orderFormPrefillProvider.notifier);
    prefill.propose(const OrderFormPrefill(symbol: 'BTCUSDT'));
    expect(
      container.read(orderFormPrefillProvider),
      isNull,
      reason: 'empty suggestions are dropped',
    );

    prefill.propose(_prefill(price: '1'));
    container.read(symbolProvider.notifier).select('BTCUSDT');
    expect(container.read(orderFormPrefillProvider), isNotNull);
    container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(container.read(orderFormPrefillProvider), isNull);

    prefill.propose(_prefill(price: '1', symbol: 'ETHUSDT'));
    container.read(appDestinationProvider.notifier).select(AppDestination.portfolio);
    expect(container.read(orderFormPrefillProvider), isNull);
  });
}
