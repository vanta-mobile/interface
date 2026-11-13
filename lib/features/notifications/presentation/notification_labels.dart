import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../funding/domain/transfer_history.dart';
import '../../funding/presentation/transfer_history_components.dart';
import '../../funding/presentation/transfer_record_details.dart';
import '../domain/account_notification.dart';

String notificationTitle(AppLocalizations l10n, AccountNotification event) => switch (event) {
  BalanceNotification() => l10n.notificationBalanceTitle,
  TransferNotification(:final record) => l10n.notificationTransferTitle(
    record.type.name,
    record.status.name,
  ),
  SpotOrderNotification(:final status) => l10n.spotNotificationOrderTitle(status),
  MarginNotification() => l10n.notificationMarginTitle,
  OrderNotification(risk: OrderRisk.liquidation) => l10n.notificationLiquidationTitle,
  OrderNotification(risk: OrderRisk.adl) => l10n.notificationAdlTitle,
  OrderNotification(:final status) => l10n.notificationOrderTitle(status),
};
String notificationSide(AppLocalizations l10n, String side) => switch (side) {
  'LONG' => l10n.openOrdersLongSide,
  'SHORT' => l10n.openOrdersShortSide,
  _ => l10n.openOrdersOneWay,
};

String notificationMarketLabel(AppLocalizations l10n, AccountNotification event) => switch (event) {
  SpotOrderNotification() => l10n.spot,
  TransferNotification(:final record) when record.market == TransferMarket.spot => l10n.spot,
  _ => l10n.notificationPerp,
};

String notificationStatusLabel(AppLocalizations l10n, AccountNotification event) => switch (event) {
  BalanceNotification() => l10n.notificationBalanceTitle,
  TransferNotification(:final record) => l10n.assetHistoryStatus(record.status.name),
  MarginNotification() ||
  OrderNotification(risk: OrderRisk.liquidation) => l10n.notificationCritical,
  OrderNotification(risk: OrderRisk.adl) => l10n.notificationAdlChip,
  OrderNotification(:final status) ||
  SpotOrderNotification(:final status) => l10n.notificationStatus(status),
};

/// One-line inbox summary. Amounts keep every reported decimal; units stay
/// unknown until verified from the relevant market directory.
String notificationSummary(
  AppLocalizations l10n,
  AccountNotification event, {
  String? base,
  String? quote,
}) {
  String amount(Decimal value, String? unit) => '$value ${unit ?? l10n.accountUnitUnavailable}';
  String order(
    String status,
    String symbol,
    String side,
    Decimal last,
    Decimal filled,
    Decimal quantity,
    Decimal average,
  ) => l10n.notificationOrderSummary(
    status,
    symbol,
    side,
    amount(last, base),
    quantity == Decimal.zero ? amount(filled, base) : '$filled / ${amount(quantity, base)}',
    amount(average, quote),
  );
  return switch (event) {
    BalanceNotification(:final balances) => l10n.notificationAssetsChanged(balances.length),
    TransferNotification(:final record) => l10n.notificationTransferSummary(
      '${record.type.name}_${record.status.name}',
      historyAmount(record),
      notificationMarketLabel(l10n, event),
      transferNetworkLabel(l10n, record.chainId),
    ),
    MarginNotification(:final positions) => l10n.notificationMarginSummary(
      positions.map((p) => p.symbol).toSet().join(', '),
    ),
    OrderNotification(risk: OrderRisk.liquidation, :final symbol) =>
      l10n.notificationLiquidationSummary(symbol),
    OrderNotification(risk: OrderRisk.adl, :final symbol) => l10n.notificationAdlSummary(symbol),
    OrderNotification e => order(
      e.status,
      e.symbol,
      l10n.notificationOrderSide(e.side),
      e.lastQuantity,
      e.filledQuantity,
      e.quantity,
      e.averagePrice,
    ),
    SpotOrderNotification e => order(
      e.status,
      e.symbol,
      l10n.spotOrderSide(e.side),
      e.lastQuantity,
      e.filledQuantity,
      e.quantity,
      e.averagePrice,
    ),
  };
}

/// Inbox rows show device-local clock time; groups are local calendar days.
String notificationClock(DateTime time) => DateFormat('HH:mm').format(time.toLocal());

DateTime notificationDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String notificationDayLabel(AppLocalizations l10n, DateTime day, DateTime now) {
  final today = notificationDay(now);
  if (day == today) return l10n.notificationToday;
  return DateFormat(day.year == today.year ? 'MM-dd' : 'yyyy-MM-dd').format(day);
}
