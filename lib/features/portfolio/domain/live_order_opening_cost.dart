import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// Validated, same-snapshot exposure in quote units. One-way orders reserve
/// the larger directional exposure; hedge opening orders add gross exposure.
/// The caller must supply actual pending notionals, including zero explicitly.
class LiveOrderOpeningExposure {
  LiveOrderOpeningExposure.oneWay({
    required this.markPrice,
    required this.leverage,
    required this.positionQuantity,
    required this.buyOrderNotional,
    required this.sellOrderNotional,
  }) : hedgeGrossNotional = null {
    _validate();
  }

  LiveOrderOpeningExposure.hedge({
    required this.markPrice,
    required this.leverage,
    required Decimal grossNotional,
  }) : positionQuantity = Decimal.zero,
       buyOrderNotional = Decimal.zero,
       sellOrderNotional = Decimal.zero,
       hedgeGrossNotional = grossNotional {
    _validate();
  }

  final Decimal markPrice, positionQuantity, buyOrderNotional, sellOrderNotional;
  final int leverage;
  final Decimal? hedgeGrossNotional;
  bool get hedge => hedgeGrossNotional != null;
  Decimal get signedNotional => positionQuantity * markPrice;
  Decimal get currentNotional => hedgeGrossNotional ??
      _max((signedNotional + buyOrderNotional).abs(), (signedNotional - sellOrderNotional).abs());

  void _validate() {
    if (markPrice <= Decimal.zero ||
        leverage <= 0 ||
        buyOrderNotional < Decimal.zero ||
        sellOrderNotional < Decimal.zero ||
        hedgeGrossNotional != null && hedgeGrossNotional! < Decimal.zero) {
      throw ArgumentError('Invalid opening exposure');
    }
  }

  Decimal openingQuantity({required bool buy, required Decimal quantity}) {
    if (quantity < Decimal.zero) throw ArgumentError('Invalid order quantity');
    final closes = !hedge && (buy ? positionQuantity < Decimal.zero : positionQuantity > Decimal.zero);
    return closes ? _max(quantity - positionQuantity.abs(), Decimal.zero) : quantity;
  }

  Decimal notionalAfter({required bool buy, required Decimal quantity, required Decimal price}) {
    if (quantity < Decimal.zero || price <= Decimal.zero) {
      throw ArgumentError('Invalid opening order');
    }
    final added = quantity * price;
    if (hedge) return hedgeGrossNotional! + added;
    return _max(
      (signedNotional + buyOrderNotional + (buy ? added : Decimal.zero)).abs(),
      (signedNotional - sellOrderNotional - (buy ? Decimal.zero : added)).abs(),
    );
  }

  /// [marginPrice] is the order type's assumed execution price. [lossPrice]
  /// is the entered limit or market assumption used for opening loss. Neither
  /// is a quote-input conversion, fee rate, actual fill, or liquidation price.
  LiveOrderOpeningCost cost({
    required bool buy,
    required Decimal quantity,
    required Decimal marginPrice,
    required Decimal lossPrice,
  }) {
    if (lossPrice <= Decimal.zero) throw ArgumentError('Invalid opening price');
    final after = notionalAfter(buy: buy, quantity: quantity, price: marginPrice);
    final opened = openingQuantity(buy: buy, quantity: quantity);
    final increment = hedge ? quantity * marginPrice : _max(after - currentNotional, Decimal.zero);
    final lossPerUnit = _max(buy ? lossPrice - markPrice : markPrice - lossPrice, Decimal.zero);
    return LiveOrderOpeningCost(
      initialMargin: increment / Decimal.fromInt(leverage),
      openingLoss: opened * lossPerUnit,
      openingQuantity: opened,
      notionalAfter: after,
    );
  }
}

class LiveOrderOpeningCost {
  const LiveOrderOpeningCost({
    required this.initialMargin,
    required this.openingLoss,
    required this.openingQuantity,
    required this.notionalAfter,
  });
  final Rational initialMargin;
  final Decimal openingLoss, openingQuantity, notionalAfter;
  Rational get total => initialMargin + openingLoss.toRational();
}

Decimal _max(Decimal a, Decimal b) => a > b ? a : b;
