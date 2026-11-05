import 'package:decimal/decimal.dart';

/// A partial update: omitted records retain their prior values. Neither the
/// event nor its balance-change field proves account/list completeness.
class AccountUpdate {
  AccountUpdate({
    required this.eventTime,
    required this.transactionTime,
    required Iterable<AccountBalanceUpdate> balances,
    required Iterable<AccountPositionUpdate> positions,
    this.reason,
  }) : balances = List.unmodifiable(balances),
       positions = List.unmodifiable(positions);
  final DateTime eventTime, transactionTime;
  final String? reason;
  final List<AccountBalanceUpdate> balances;
  final List<AccountPositionUpdate> positions;
}

class AccountBalanceUpdate {
  const AccountBalanceUpdate({
    required this.asset,
    required this.walletBalance,
    required this.crossWalletBalance,
    this.change,
  });
  final String asset;
  final Decimal walletBalance, crossWalletBalance;
  final Decimal? change;
  bool sameValues(AccountBalanceUpdate other) =>
      walletBalance == other.walletBalance && crossWalletBalance == other.crossWalletBalance;
}

class AccountPositionUpdate {
  const AccountPositionUpdate({
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.entryPrice,
    required this.unrealizedProfit,
    required this.isolated,
    required this.isolatedWallet,
  });
  final String symbol, side;
  final Decimal quantity, entryPrice, unrealizedProfit, isolatedWallet;
  final bool isolated;
  String get key => '$symbol:$side';
  bool sameValues(AccountPositionUpdate other) =>
      quantity == other.quantity &&
      entryPrice == other.entryPrice &&
      unrealizedProfit == other.unrealizedProfit &&
      isolated == other.isolated &&
      isolatedWallet == other.isolatedWallet;
}
