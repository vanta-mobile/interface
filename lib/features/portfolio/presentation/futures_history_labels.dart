import '../../../l10n/generated/app_localizations.dart';

String futuresIncomeLabel(AppLocalizations l10n, String type) =>
    l10n.futuresHistoryIncomeType(type);
String futuresHistoryStatus(AppLocalizations l10n, String status) => switch (status) {
  'NEW' => l10n.openOrdersNew,
  'PARTIALLY_FILLED' => l10n.openOrdersPartiallyFilled,
  'FILLED' => l10n.historyFilled,
  'CANCELED' => l10n.historyCanceled,
  'EXPIRED' || 'EXPIRED_IN_MATCH' => l10n.historyExpired,
  'REJECTED' => l10n.historyRejected,
  'PENDING_CANCEL' => l10n.historyPendingCancel,
  _ => l10n.historyUnknownCode(status),
};
String futuresHistoryOrderType(AppLocalizations l10n, String type) =>
    {
      'LIMIT',
      'MARKET',
      'STOP',
      'STOP_MARKET',
      'TAKE_PROFIT',
      'TAKE_PROFIT_MARKET',
      'TRAILING_STOP_MARKET',
      'LIQUIDATION',
    }.contains(type)
    ? l10n.notificationOrderType(type)
    : l10n.historyUnknownCode(type);
String futuresHistoryPosition(AppLocalizations l10n, String side) => switch (side) {
  'BOTH' => l10n.openOrdersOneWay,
  'LONG' => l10n.openOrdersLongSide,
  'SHORT' => l10n.openOrdersShortSide,
  _ => l10n.historyUnknownCode(side),
};
