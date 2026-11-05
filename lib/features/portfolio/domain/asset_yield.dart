import 'package:decimal/decimal.dart';

enum YieldAsset {
  usdf('USDF'),
  asbnb('ASBNB');

  const YieldAsset(this.symbol);
  final String symbol;
  static YieldAsset? forSymbol(String symbol) => switch (symbol) {
    'USDF' => usdf,
    'ASBNB' => asbnb,
    _ => null,
  };
}

/// Published annualized percentage, independent of wallet balances and returns.
/// [sourceDay] is a calendar label from the publisher, not a precise timestamp.
class AssetYieldQuote {
  const AssetYieldQuote({
    required this.asset,
    required this.percent,
    required this.sourceDay,
    required this.receivedAt,
    this.basePercent,
    this.tradePercent,
    this.updatedAt,
  });
  final YieldAsset asset;
  final Decimal percent;
  final Decimal? basePercent, tradePercent;
  final DateTime sourceDay, receivedAt;
  final DateTime? updatedAt;

  bool freshAt(DateTime now) {
    final utc = now.toUtc(), receipt = receivedAt.toUtc();
    final today = DateTime.utc(utc.year, utc.month, utc.day);
    return !utc.isBefore(receipt.subtract(const Duration(seconds: 30))) &&
        utc.isBefore(receipt.add(const Duration(minutes: 5))) &&
        !sourceDay.isAfter(today) &&
        today.difference(sourceDay).inDays <= 2 &&
        (updatedAt == null || !updatedAt!.isAfter(utc.add(const Duration(seconds: 30))));
  }
}

abstract interface class AssetYieldRepository {
  Future<AssetYieldQuote> read(YieldAsset asset);
}

class AssetYieldState {
  const AssetYieldState({
    required this.checkedAt,
    this.quote,
    this.loading = false,
    this.active = true,
    this.failureKey,
  });
  final DateTime checkedAt;
  final AssetYieldQuote? quote;
  final bool loading, active;
  final String? failureKey;
  bool get stale => quote != null && (!active || failureKey != null || !quote!.freshAt(checkedAt));
}
