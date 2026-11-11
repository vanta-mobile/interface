import 'package:decimal/decimal.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../domain/aster_open_orders.dart';

/// Display labels shared by the open-order card and its details sheet.
String openOrderType(AppLocalizations l10n, AsterOpenOrder order) {
  if (order.timeInForce == 'HIDDEN') return l10n.openOrdersHidden;
  return switch (order.originalType ?? order.type) {
    'LIMIT' => l10n.openOrdersLimit,
    'MARKET' => l10n.openOrdersMarket,
    'STOP' => l10n.openOrdersStopLimit,
    'STOP_MARKET' => l10n.openOrdersStopMarket,
    'TAKE_PROFIT' => l10n.openOrdersTakeProfitLimit,
    'TAKE_PROFIT_MARKET' => l10n.openOrdersTakeProfitMarket,
    'TRAILING_STOP_MARKET' => l10n.openOrdersTrailingStop,
    _ => l10n.openOrdersOtherType,
  };
}

String openOrderPrice(AppLocalizations l10n, AsterOpenOrder order) {
  if (order.pegPriceType != null && order.price == Decimal.zero) return l10n.openOrdersBbo;
  if (order.price > Decimal.zero) return marketNumber(order.price);
  if (order.type == 'MARKET' || order.type.endsWith('_MARKET')) return l10n.openOrdersMarket;
  return openOrderPlaceholder;
}

bool isTrailingOrder(AsterOpenOrder order) =>
    (order.originalType ?? order.type) == 'TRAILING_STOP_MARKET';

bool isConditionalOrder(AsterOpenOrder order) =>
    isTrailingOrder(order) || (order.stopPrice ?? Decimal.zero) > Decimal.zero;

/// Stop orders fire when price moves against the order side; take-profit
/// orders fire when it moves in favour. Null for orders without a stop price.
String? openOrderTrigger(AppLocalizations l10n, AsterOpenOrder order) {
  final stop = order.stopPrice;
  if (isTrailingOrder(order) || stop == null || stop <= Decimal.zero) return null;
  final price = marketNumber(stop);
  final basis = switch (order.workingType) {
    'MARK_PRICE' => l10n.mark,
    'CONTRACT_PRICE' => l10n.lastPrice,
    _ => null,
  };
  final buy = order.side == 'BUY';
  final operator = switch (order.originalType ?? order.type) {
    'STOP' || 'STOP_MARKET' => buy ? '>=' : '<=',
    'TAKE_PROFIT' || 'TAKE_PROFIT_MARKET' => buy ? '<=' : '>=',
    _ => null,
  };
  if (basis == null || operator == null) return price;
  return l10n.openOrdersTriggerCondition(basis, operator, price);
}

const openOrderPlaceholder = '--';
