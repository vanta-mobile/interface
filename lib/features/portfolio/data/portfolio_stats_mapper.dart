import 'package:decimal/decimal.dart';

import '../domain/portfolio_stats.dart';

/// Maps contract payloads (`docs/contracts/vanta-api/openapi.yaml`). Every
/// amount is a decimal string; a malformed field rejects the whole response.
PortfolioPeriodSummary mapPortfolioSummary(Map<String, Object?> json) => PortfolioPeriodSummary(
  from: _date(json['from']),
  to: _date(json['to']),
  pnl: portfolioNetPnl(
    realized: _decimal(json['realized_pnl_usd']),
    fees: _decimal(json['fees_usd']),
    funding: _decimal(json['funding_fee_usd']),
  ),
  volume: _decimal(json['volume_usd']),
  equityStart: _nullableDecimal(json['equity_start_usd']),
  equityEnd: _nullableDecimal(json['equity_end_usd']),
  partial: _bool(json['partial']),
);

/// `metric=value`: `equity_close_usd` per bucket.
PortfolioCurve mapValueCurve(Map<String, Object?> json) {
  if (json['metric'] != 'value') throw const FormatException('metric');
  return PortfolioCurve(
    _points(json)
        .map((p) => PortfolioCurvePoint(_time(p['bucket']), _decimal(p['equity_close_usd']))),
  );
}

/// `metric=pnl`: cumulative net PnL across the returned buckets.
PortfolioCurve mapPnlCurve(Map<String, Object?> json) {
  if (json['metric'] != 'pnl') throw const FormatException('metric');
  var total = Decimal.zero;
  return PortfolioCurve([
    for (final p in _points(json))
      PortfolioCurvePoint(
        _time(p['bucket']),
        total += portfolioNetPnl(
          realized: _decimal(p['realized_pnl_usd']),
          fees: _decimal(p['fees_usd']),
          funding: _decimal(p['funding_fee_usd']),
        ),
      ),
  ]);
}

PortfolioCalendarMonth mapCalendar(Map<String, Object?> json, {required DateTime month}) {
  final items = json['items'];
  if (items is! List) throw const FormatException('items');
  final days = <DateTime, Decimal>{};
  for (final item in items) {
    if (item is! Map<String, Object?>) throw const FormatException('item');
    days[_date(item['day'])] = portfolioNetPnl(
      realized: _decimal(item['realized_pnl_usd']),
      fees: _decimal(item['fees_usd']),
      funding: _decimal(item['funding_fee_usd']),
    );
  }
  return PortfolioCalendarMonth(month: month, days: days);
}

Iterable<Map<String, Object?>> _points(Map<String, Object?> json) {
  final points = json['points'];
  if (points is! List) throw const FormatException('points');
  final mapped = [
    for (final p in points) p is Map<String, Object?> ? p : throw const FormatException('point'),
  ];
  return mapped..sort((a, b) => _time(a['bucket']).compareTo(_time(b['bucket'])));
}

final _decimalPattern = RegExp(r'^-?[0-9]+(\.[0-9]+)?$');

Decimal _decimal(Object? value) {
  if (value is! String || value.length > 80 || !_decimalPattern.hasMatch(value)) {
    throw const FormatException('decimal');
  }
  return Decimal.parse(value);
}

Decimal? _nullableDecimal(Object? value) => value == null ? null : _decimal(value);

bool _bool(Object? value) => value is bool ? value : throw const FormatException('bool');

DateTime _time(Object? value) {
  final time = value is String ? DateTime.tryParse(value) : null;
  return time?.toUtc() ?? (throw const FormatException('timestamp'));
}

DateTime _date(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('date');
  }
  final day = DateTime.parse('${value}T00:00:00Z');
  return DateTime.utc(day.year, day.month, day.day);
}
