import 'package:decimal/decimal.dart';

import '../../market/domain/market_precision.dart';
import 'live_order_draft.dart';
import 'live_order_size.dart';

enum OrderPrefillType { limit, market }

/// Order terms suggested from outside the form, such as a deep link. They only
/// fill inputs; the user still picks Long/Short, reviews and signs.
class OrderFormPrefill {
  const OrderFormPrefill({required this.symbol, this.type, this.price, this.size});

  final String symbol;
  final OrderPrefillType? type;

  /// Limit price as typed text; never set for market orders.
  final String? price;
  final LiveOrderSize? size;

  bool get isEmpty => type == null && price == null && size == null;

  /// Keeps only terms the market can represent exactly. A value off the price
  /// tick or quantity step is dropped, never rounded, so the user is not shown
  /// different terms from the ones the link asked for.
  OrderFormPrefill fit(MarketPrecision precision) {
    final keepPrice = price != null && _onIncrement(price!, precision.priceTick);
    final keepSize = switch (size) {
      null => false,
      LiveOrderSize(unit: OrderSizeUnit.base, :final text) => _onIncrement(
        text,
        precision.quantityStep,
      ),
      LiveOrderSize(unit: OrderSizeUnit.quote, :final text) => _onIncrement(text, '0.01'),
    };
    return OrderFormPrefill(
      symbol: symbol,
      type: type,
      price: keepPrice ? price : null,
      size: keepSize ? size : null,
    );
  }
}

/// A strictly positive plain decimal; rejects signs, exponents and commas.
Decimal? parsePrefillDecimal(String? text) {
  final value = text == null ? null : parseOrderDecimal(text.trim());
  return value != null && value > Decimal.zero ? value : null;
}

bool _onIncrement(String text, String? increment) {
  final value = parsePrefillDecimal(text), step = Decimal.tryParse(increment ?? '');
  if (value == null) return false;
  if (step == null || step <= Decimal.zero) return true;
  return (value % step) == Decimal.zero;
}
