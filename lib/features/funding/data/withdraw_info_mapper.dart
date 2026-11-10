import 'package:decimal/decimal.dart';

import '../../../core/exact_json.dart';
import '../domain/withdraw_info.dart';

/// Keeps non-integer numbers as exact text. Integers (server time, business
/// `code`, chain IDs) stay ints, so the shared transport reads them unchanged.
Object? decodeWithdrawInfoJson(String source) {
  Object? integers(Object? value) => switch (value) {
    FundingJsonNumber(:final integer?) => integer,
    Map<String, dynamic> map => {for (final e in map.entries) e.key: integers(e.value)},
    List<dynamic> list => [for (final item in list) integers(item)],
    _ => value,
  };
  return integers(decodeFundingJson(source));
}

/// Quantities may arrive as documented strings, exact JSON numbers or
/// exponent notation. A malformed asset row is left unknown instead of
/// discarding every other asset's limits; malformed totals stay unknown.
WithdrawInfo mapWithdrawInfo(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
}) {
  Map<String, dynamic> object(Object? value) =>
      value is Map<String, dynamic> ? value : throw const FormatException();
  Decimal? money(Object? value) {
    final text = switch (value) {
      null => null,
      FundingJsonNumber(:final text) => text,
      int whole => '$whole',
      String text when text.trim().isEmpty => null,
      String text => text.trim(),
      _ => throw const FormatException(),
    };
    if (text == null) return null;
    if (text.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?(?:[eE][+-]?\d{1,3})?$').hasMatch(text)) {
      throw const FormatException();
    }
    return Decimal.parse(text);
  }

  Decimal? optionalMoney(Object? value) {
    try {
      return money(value);
    } on FormatException {
      return null;
    }
  }

  int? chainId(Object? value) => switch (value) {
    int id => id,
    FundingJsonNumber(:final integer) => integer,
    String text => int.tryParse(text),
    _ => null,
  };

  WithdrawAssetInfo asset(String name, Object? value) {
    final row = object(value), currency = row['currency'];
    if (currency != null && currency != name) throw const FormatException();
    final chainRows = row['chainBalances'] == null
        ? const <String, dynamic>{}
        : object(row['chainBalances']);
    if (chainRows.length > 100) throw const FormatException();
    final chains = <int, WithdrawChainInfo>{};
    for (final e in chainRows.entries) {
      final raw = object(e.value), id = chainId(raw['chainId'] ?? e.key);
      if (id == null || id <= 0 || id.toString() != e.key) throw const FormatException();
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
    return WithdrawAssetInfo(
      asset: name,
      chains: chains,
      spotTotalAmount: money(row['spotTotalWithdrawAmount']),
      perpTotalAmount: money(row['perpTotalWithdrawAmount']),
      dailyLimitUsd: money(row['dailyLimit']),
    );
  }

  final root = object(payload);
  final balances = switch (root['balances']) {
    null || [] => const <String, dynamic>{},
    final value => object(value),
  };
  if (balances.length > 1000) throw const FormatException();
  final assets = <String, WithdrawAssetInfo>{};
  for (final entry in balances.entries) {
    if (!RegExp(r'^[\p{L}\p{N}_.-]{1,60}$', unicode: true).hasMatch(entry.key)) continue;
    try {
      assets[entry.key] = asset(entry.key, entry.value);
    } on FormatException {
      // Unknown for this asset only; never substituted by a balance or zero.
    }
  }
  return WithdrawInfo(
    address: address,
    receivedAt: receivedAt.toUtc(),
    assets: assets,
    userDailyLimitUsd: optionalMoney(root['userDailyLimit']),
    userRemainingDailyLimitUsd: optionalMoney(root['userRemainingDailyLimit']),
    totalDailyLimitUsd: optionalMoney(root['totalDailyLimit']),
    totalRemainingDailyLimitUsd: optionalMoney(root['totalRemainingDailyLimit']),
  );
}
