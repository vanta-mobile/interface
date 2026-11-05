import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/asset_yield.dart';

AssetYieldQuote assetYieldFixture(YieldAsset asset, DateTime now) => AssetYieldQuote(
  asset: asset,
  percent: Decimal.parse(asset == YieldAsset.usdf ? '11.45' : '1.4499999999999999'),
  basePercent: asset == YieldAsset.usdf ? Decimal.parse('1.75') : null,
  tradePercent: asset == YieldAsset.usdf ? Decimal.parse('9.70') : null,
  sourceDay: DateTime.utc(now.year, now.month, now.day),
  receivedAt: now,
);

class TestAssetYieldRepository implements AssetYieldRepository {
  TestAssetYieldRepository({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  final calls = <YieldAsset>[];
  final quotes = <YieldAsset, AssetYieldQuote>{};
  final failures = <YieldAsset, Object>{};
  final gates = <YieldAsset, Completer<AssetYieldQuote>>{};
  @override
  Future<AssetYieldQuote> read(YieldAsset asset) async {
    calls.add(asset);
    if (gates[asset] case final gate?) return gate.future;
    if (failures[asset] case final failure?) throw failure;
    return quotes[asset] ?? assetYieldFixture(asset, now());
  }
}
