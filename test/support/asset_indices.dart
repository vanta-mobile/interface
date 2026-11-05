import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';

AssetIndexSnapshot assetIndexFixture(
  DateTime time, {
  Map<String, String> prices = const {'USDT': '0.99836', 'BTC': '80000', 'ETH': '3000'},
  DateTime? receivedAt,
}) => AssetIndexSnapshot(
  receivedAt: receivedAt ?? time,
  indices: {
    for (final e in prices.entries)
      '${e.key}USD': AssetUsdIndex(symbol: '${e.key}USD', usd: Decimal.parse(e.value), time: time),
  },
);

class TestAssetIndexRepository implements AssetIndexRepository {
  TestAssetIndexRepository({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  int calls = 0;
  Object? failure;
  AssetIndexSnapshot? result;
  Completer<AssetIndexSnapshot>? gate;
  @override
  Future<AssetIndexSnapshot> read() async {
    calls++;
    if (gate case final pending?) return pending.future;
    if (failure case final error?) throw error;
    return result ?? assetIndexFixture(now());
  }
}
