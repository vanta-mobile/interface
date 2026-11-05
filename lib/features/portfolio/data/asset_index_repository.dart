import 'package:decimal/decimal.dart';

import '../domain/asset_valuation.dart';
import 'aster_account_service.dart';

AssetIndexSnapshot mapAssetIndices(Object? payload, {required DateTime receivedAt}) {
  if (payload is! List || payload.length > 5000) throw const FormatException();
  final result = <String, AssetUsdIndex>{};
  for (final raw in payload) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final symbol = raw['symbol'], price = raw['index'], time = raw['time'];
    if (symbol is! String ||
        !RegExp(r'^[\p{L}\p{N}_.-]{1,60}USD$', unicode: true).hasMatch(symbol) ||
        result.containsKey(symbol) ||
        price is! String ||
        price.length > 160 ||
        !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(price) ||
        time is! int ||
        time <= 0 ||
        time > 253402300799999) {
      throw const FormatException();
    }
    final usd = Decimal.parse(price);
    if (usd <= Decimal.zero) throw const FormatException();
    final bid = _optionalRate(raw['bidRate']), ask = _optionalRate(raw['askRate']);
    final validRates = bid != null && ask != null && bid <= ask;
    result[symbol] = AssetUsdIndex(
      symbol: symbol,
      usd: usd,
      bidRate: validRates ? bid : null,
      askRate: validRates ? ask : null,
      time: DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
    );
  }
  return AssetIndexSnapshot(receivedAt: receivedAt.toUtc(), indices: result);
}

// Optional collateral fields must not corrupt an otherwise valid price index.
// Missing/malformed rates remain unavailable; never synthesize from index or buffers.
Decimal? _optionalRate(Object? value) {
  if (value is! String || value.length > 160 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) {
    return null;
  }
  return Decimal.parse(value);
}

class AsterAssetIndexRepository implements AssetIndexRepository {
  AsterAssetIndexRepository(this.service, {DateTime Function()? now}) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final DateTime Function() now;
  @override
  Future<AssetIndexSnapshot> read() async =>
      mapAssetIndices(await service.assetIndices(), receivedAt: now());
}
