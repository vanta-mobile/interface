import 'package:decimal/decimal.dart';

import '../../../core/exact_json.dart';
import '../../../core/domain/wallet_operation.dart';
import '../domain/position_margin_adjustment.dart';
import 'position_leverage_mapper.dart';

/// Preserve fractional response numbers without passing money through double.
Object? decodePositionMarginJson(String source) {
  Object? normalize(Object? value) => switch (value) {
    FundingJsonNumber n => n.integer ?? n.text,
    List<dynamic> list => list.map(normalize).toList(),
    Map<String, dynamic> map => map.map((k, v) => MapEntry(k, normalize(v))),
    _ => value,
  };
  return normalize(decodeFundingJson(source));
}

Decimal marginDecimal(Object? value) {
  if (value is! String && value is! int) throw const FormatException();
  final s = '$value';
  if (s.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(s)) throw const FormatException();
  return Decimal.parse(s);
}

List<MarginRiskTier> mapMarginRiskTiers(Object? payload, String symbol) {
  final base = mapLeverageBrackets(payload, symbol);
  final map = payload is List ? payload.single : payload;
  final rows = (map as Map<String, dynamic>)['brackets'] as List;
  final result = <MarginRiskTier>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i] as Map<String, dynamic>;
    final rate = marginDecimal(row['maintMarginRatio']), cum = marginDecimal(row['cum']);
    if (rate < Decimal.zero ||
        rate >= Decimal.one ||
        cum < Decimal.zero ||
        i == 0 && cum != Decimal.zero ||
        i > 0 &&
            (rate < result.last.rate ||
                cum != result.last.cumulative + base[i].floor * (rate - result.last.rate))) {
      throw const FormatException();
    }
    result.add(MarginRiskTier(floor: base[i].floor, cap: base[i].cap, rate: rate, cumulative: cum));
  }
  return List.unmodifiable(result);
}

/// Match the original operation, not a coincidental change in wallet balance.
DateTime? matchMarginHistory(Object? payload, WalletOperationRecord record, DateTime now) {
  if (payload is! List || payload.length > 500) throw const FormatException();
  final terms = record.terms;
  DateTime? matched;
  for (final raw in payload) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final id = raw['clientTranId'];
    if (id != null && id is! String) throw const FormatException();
    if (id != terms['clientTranId']) continue;
    final amount = marginDecimal(raw['amount']), time = raw['time'];
    if (matched != null ||
        raw['symbol'] != terms['symbol'] ||
        raw['positionSide'] != terms['side'] ||
        raw['asset'] != terms['asset'] ||
        raw['type'].toString() != terms['type'] ||
        raw['deltaType'] != 'USER_ADJUST' ||
        amount != Decimal.parse(terms['amount']!) ||
        time is! int ||
        time < record.preparedAt.millisecondsSinceEpoch - 30000 ||
        time > now.millisecondsSinceEpoch + 30000) {
      throw const FormatException();
    }
    matched = DateTime.fromMillisecondsSinceEpoch(time, isUtc: true);
  }
  return matched;
}
