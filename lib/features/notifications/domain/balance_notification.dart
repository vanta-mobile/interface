part of 'account_notification.dart';

/// Only balances included in this event, never a complete account snapshot.
class BalanceNotification extends AccountNotification {
  BalanceNotification({
    required DateTime eventTime,
    required this.transactionTime,
    required this.reason,
    required Iterable<AccountBalanceUpdate> balances,
  }) : balances = List.unmodifiable(balances),
       super(eventTime);
  final DateTime transactionTime;
  final String reason;
  final List<AccountBalanceUpdate> balances;
  @override
  bool get critical => false;
  @override
  String get dedupeKey {
    final content =
        balances
            .map(
              (b) => jsonEncode([
                b.asset,
                b.walletBalance.toString(),
                b.crossWalletBalance.toString(),
                b.change?.toString(),
              ]),
            )
            .toList()
          ..sort();
    return jsonEncode([
      'PERP',
      'BALANCE',
      eventTime.millisecondsSinceEpoch,
      transactionTime.millisecondsSinceEpoch,
      reason,
      content,
    ]);
  }
}
