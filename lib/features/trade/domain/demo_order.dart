import 'package:decimal/decimal.dart';

import '../../market/domain/market_precision.dart';

final demoFeeRate = Decimal.parse('0.0005');

class OrderDraft {
  const OrderDraft({
    required this.symbol,
    required this.buy,
    required this.market,
    required this.quantity,
    required this.price,
    required this.leverage,
    this.reduceOnly = false,
    this.precision = const MarketPrecision(quantityStep: '0.00001'),
  });
  final String symbol, quantity, price;
  final bool buy, market, reduceOnly;
  final int leverage;
  final MarketPrecision precision;

  Decimal get parsedQuantity => Decimal.tryParse(quantity) ?? Decimal.zero;
  Decimal get parsedPrice => Decimal.tryParse(price) ?? Decimal.zero;
  Decimal get notional => parsedQuantity * parsedPrice;
  Decimal get fee => notional * demoFeeRate;
  Decimal get margin =>
      (notional / Decimal.fromInt(leverage)).toDecimal(scaleOnInfinitePrecision: 8);

  String? validate(Decimal available) {
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(quantity) ||
        parsedQuantity <= Decimal.zero ||
        !precision.acceptsQuantity(parsedQuantity)) {
      return 'invalidQuantity';
    }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(price) ||
        parsedPrice <= Decimal.zero ||
        (!market && !precision.acceptsPrice(parsedPrice))) {
      return 'invalidPrice';
    }
    if (leverage < 1 || leverage > 100) return 'leverageHint';
    if (!reduceOnly && margin + fee > available) return 'insufficient';
    return null;
  }
}

class DemoOrder {
  const DemoOrder({required this.id, required this.draft, required this.status});
  final String id;
  final OrderDraft draft;
  final String status;
  DemoOrder withStatus(String value) => DemoOrder(id: id, draft: draft, status: value);
}

class DemoAccount {
  const DemoAccount({
    this.connected = false,
    required this.balance,
    this.positions = const [],
    this.orders = const [],
    this.history = const [],
  });
  factory DemoAccount.initial() => DemoAccount(balance: Decimal.fromInt(10000));
  final bool connected;
  final Decimal balance;
  final List<DemoOrder> positions, orders, history;
  Decimal get reserved =>
      [...positions, ...orders].fold(Decimal.zero, (sum, order) => sum + order.draft.margin);
  Decimal get available => balance - reserved;
}
