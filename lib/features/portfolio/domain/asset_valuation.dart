import 'package:decimal/decimal.dart';

class AssetUsdIndex {
  const AssetUsdIndex({
    required this.symbol,
    required this.usd,
    required this.time,
    this.bidRate,
    this.askRate,
  });
  final String symbol;
  final Decimal usd;
  // Absolute USD per asset rates, not percentage discounts.
  final Decimal? bidRate, askRate;
  final DateTime time;
}

class AssetIndexSnapshot {
  AssetIndexSnapshot({required this.receivedAt, required Map<String, AssetUsdIndex> indices})
    : indices = Map.unmodifiable(indices);
  final DateTime receivedAt;
  final Map<String, AssetUsdIndex> indices;

  /// Exact forward lookup in the asset/USD index directory, never a perpetual
  /// contract price or a guessed stablecoin peg.
  AssetUsdIndex? forAsset(String asset) => indices['${asset}USD'];
}

abstract interface class AssetIndexRepository {
  Future<AssetIndexSnapshot> read();
}

class AssetIndexState {
  const AssetIndexState({
    required this.checkedAt,
    this.snapshot,
    this.loading = false,
    this.failed = false,
    this.active = true,
  });
  final DateTime checkedAt;
  final AssetIndexSnapshot? snapshot;
  final bool loading, failed, active;
  bool fresh(AssetUsdIndex quote) =>
      active &&
      !failed &&
      snapshot != null &&
      !snapshot!.receivedAt.isAfter(checkedAt.add(const Duration(seconds: 30))) &&
      checkedAt.difference(snapshot!.receivedAt) < const Duration(seconds: 60) &&
      !quote.time.isAfter(checkedAt.add(const Duration(seconds: 30))) &&
      checkedAt.difference(quote.time) < const Duration(seconds: 90);
}

/// BTC division is rounded only for display. The dust predicate uses exact
/// cross multiplication, so values at the 0.0001 BTC threshold never slip over.
class AssetAmountValue {
  const AssetAmountValue._({
    this.usd,
    this.btc,
    this.priceTime,
    this.fresh = false,
    this.btcFresh = false,
    this.aboveLowBalanceThreshold,
  });
  factory AssetAmountValue(Decimal quantity, String asset, AssetIndexState prices) {
    if (quantity == Decimal.zero) {
      return AssetAmountValue._(
        usd: Decimal.zero,
        btc: Decimal.zero,
        fresh: true,
        btcFresh: true,
        aboveLowBalanceThreshold: false,
      );
    }
    final quote = prices.snapshot?.forAsset(asset);
    if (quote == null) return const AssetAmountValue._();
    final usd = quantity * quote.usd;
    final btcPrice = prices.snapshot?.forAsset('BTC');
    final fresh = prices.fresh(quote);
    return AssetAmountValue._(
      usd: usd,
      priceTime: quote.time,
      fresh: fresh,
      btcFresh: fresh && btcPrice != null && prices.fresh(btcPrice),
      btc: btcPrice == null
          ? null
          : (usd / btcPrice.usd).toDecimal(
              scaleOnInfinitePrecision: usd.scale + btcPrice.usd.precision + 24,
              toBigInt: (value) => value.round(),
            ),
      aboveLowBalanceThreshold: btcPrice == null || !fresh || !prices.fresh(btcPrice)
          ? null
          : usd * Decimal.fromInt(10000) > btcPrice.usd,
    );
  }
  final Decimal? usd, btc;
  final DateTime? priceTime;
  final bool fresh, btcFresh;
  final bool? aboveLowBalanceThreshold;
}

class AssetWalletValue {
  AssetWalletValue(Iterable<AssetAmountValue> values, AssetIndexState prices) {
    for (final value in values) {
      if (value.usd == null) {
        missing++;
      } else {
        known++;
        usd += value.usd!;
      }
      if (!value.fresh && value.usd != null) stale++;
    }
    final quote = prices.snapshot?.forAsset('BTC');
    btc = usd == Decimal.zero
        ? Decimal.zero
        : quote == null
        ? null
        : (usd / quote.usd).toDecimal(
            scaleOnInfinitePrecision: usd.scale + quote.usd.precision + 24,
            toBigInt: (value) => value.round(),
          );
    btcFresh = usd == Decimal.zero || quote != null && prices.fresh(quote);
  }
  Decimal usd = Decimal.zero;
  Decimal? btc;
  bool btcFresh = false;
  int missing = 0, stale = 0, known = 0;
}
