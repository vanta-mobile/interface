import 'package:decimal/decimal.dart';

import '../domain/withdraw_info.dart';

WithdrawInfo mapWithdrawInfo(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
}) {
  Map<String, dynamic> object(Object? value) =>
      value is Map<String, dynamic> ? value : throw const FormatException();
  Decimal? money(Object? value) {
    if (value == null) return null;
    if (value is! String || value.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(value)) {
      throw const FormatException();
    }
    return Decimal.parse(value);
  }

  final root = object(payload), balances = object(root['balances']);
  if (balances.length > 1000) throw const FormatException();
  final assets = <String, WithdrawAssetInfo>{};
  for (final entry in balances.entries) {
    final row = object(entry.value), name = entry.key;
    if (!RegExp(r'^[\p{L}\p{N}_.-]{1,60}$', unicode: true).hasMatch(name) ||
        row['currency'] != name) {
      throw const FormatException();
    }
    final chainRows = object(row['chainBalances']), chains = <int, WithdrawChainInfo>{};
    if (chainRows.length > 100) throw const FormatException();
    for (final e in chainRows.entries) {
      final raw = object(e.value), id = raw['chainId'];
      if (id is! int || id <= 0 || id.toString() != e.key) throw const FormatException();
      final fee = money(raw['withdrawFee']);
      if (fee != null && fee < Decimal.zero) throw const FormatException();
      chains[id] = WithdrawChainInfo(
        chainId: id,
        spotMaxAmount: money(raw['spotMaxWithdrawAmount']),
        perpMaxAmount: money(raw['perpMaxWithdrawAmount']),
        chainLimit: money(raw['chainLimit']),
        fee: fee,
      );
    }
    assets[name] = WithdrawAssetInfo(
      asset: name,
      chains: chains,
      spotTotalAmount: money(row['spotTotalWithdrawAmount']),
      perpTotalAmount: money(row['perpTotalWithdrawAmount']),
      dailyLimitUsd: money(row['dailyLimit']),
    );
  }
  return WithdrawInfo(
    address: address,
    receivedAt: receivedAt.toUtc(),
    assets: assets,
    userDailyLimitUsd: money(root['userDailyLimit']),
    userRemainingDailyLimitUsd: money(root['userRemainingDailyLimit']),
    totalDailyLimitUsd: money(root['totalDailyLimit']),
    totalRemainingDailyLimitUsd: money(root['totalRemainingDailyLimit']),
  );
}
