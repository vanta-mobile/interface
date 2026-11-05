import 'package:decimal/decimal.dart';

import '../../../core/exact_json.dart';
import '../domain/asset_yield.dart';

AssetYieldQuote mapAssetYield(
  Object? payload, {
  required YieldAsset asset,
  required DateTime receivedAt,
}) {
  if (payload is! Map<String, dynamic>) throw const FormatException();
  final data = payload['data'];
  if (data is! Map<String, dynamic>) throw const FormatException();
  final Decimal percent;
  final DateTime sourceDay;
  Decimal? base, trade;
  DateTime? updatedAt;
  switch (asset) {
    case YieldAsset.usdf:
      if (payload['success'] != true || payload['code'] != '000000') {
        throw const FormatException();
      }
      Map<String, dynamic> first(Object? rows) {
        if (rows is! List ||
            rows.isEmpty ||
            rows.length > 5000 ||
            rows.first is! Map<String, dynamic>) {
          throw const FormatException();
        }
        return rows.first as Map<String, dynamic>;
      }
      final baseRow = first(data['baseApyList']), tradeRow = first(data['tradeApyList']);
      sourceDay = _day(baseRow['day']);
      if (_day(tradeRow['day']) != sourceDay) throw const FormatException();
      base = _decimal(baseRow['apy']);
      trade = _decimal(tradeRow['apy']);
      percent = base + trade;
    case YieldAsset.asbnb:
      if (payload['code'] != '000000000') throw const FormatException();
      // The publisher supplies a ratio; USDF already supplies percentage points.
      percent = _decimal(data['comprehensiveApy']) * Decimal.fromInt(100);
      sourceDay = _day(data['time']);
      if (data['updateTime'] case final raw?) {
        final int? value = raw is FundingJsonNumber
            ? raw.integer
            : raw is int
            ? raw
            : null;
        if (value == null || value <= 0 || value > 253402300799999) throw const FormatException();
        updatedAt = DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
  }
  return AssetYieldQuote(
    asset: asset,
    percent: percent,
    basePercent: base,
    tradePercent: trade,
    sourceDay: sourceDay,
    updatedAt: updatedAt,
    receivedAt: receivedAt.toUtc(),
  );
}

Decimal _decimal(Object? raw) {
  final text = raw is FundingJsonNumber
      ? raw.text
      : raw is String
      ? raw
      : null;
  if (text == null || text.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(text)) {
    throw const FormatException();
  }
  return Decimal.parse(text);
}

DateTime _day(Object? raw) {
  if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
    throw const FormatException();
  }
  final parsed = DateTime.tryParse('${raw}T00:00:00Z');
  if (parsed == null || parsed.year < 1970 || parsed.toIso8601String().substring(0, 10) != raw) {
    throw const FormatException();
  }
  return parsed;
}
