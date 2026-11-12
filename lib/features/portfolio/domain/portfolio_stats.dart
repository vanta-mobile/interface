import 'package:decimal/decimal.dart';

/// Contract `PeriodValue`; the UI periods map one-to-one.
enum PortfolioStatsPeriod {
  day('24h'),
  week('7d'),
  twoWeeks('14d'),
  month('30d'),
  all('all');

  const PortfolioStatsPeriod(this.query);
  final String query;
}

/// Contract PnL basis: realized PnL − trading fees + funding fee (funding is
/// signed, fees are a non-negative cost). Unrealized PnL is not included.
Decimal portfolioNetPnl({
  required Decimal realized,
  required Decimal fees,
  required Decimal funding,
}) => realized - fees + funding;

/// `GET /v1/portfolio/summary`. Missing equity stays null, never zero.
class PortfolioPeriodSummary {
  const PortfolioPeriodSummary({
    required this.from,
    required this.to,
    required this.pnl,
    required this.volume,
    required this.partial,
    this.equityStart,
    this.equityEnd,
  });
  final DateTime from, to;
  final Decimal pnl, volume;
  final Decimal? equityStart, equityEnd;

  /// Funding was not reported for traded days; its zero is not a real zero.
  final bool partial;

  /// Percentage of the period's starting equity; null without a positive base.
  Decimal? get returnPercent {
    final base = equityStart;
    if (base == null || base <= Decimal.zero) return null;
    return (pnl * Decimal.fromInt(100) / base).toDecimal(scaleOnInfinitePrecision: 8);
  }
}

class PortfolioCurvePoint {
  const PortfolioCurvePoint(this.bucket, this.value);
  final DateTime bucket;
  final Decimal value;
}

/// Ordered buckets that have data; missing days are absent, not zero.
class PortfolioCurve {
  PortfolioCurve(Iterable<PortfolioCurvePoint> points) : points = List.unmodifiable(points);
  final List<PortfolioCurvePoint> points;
}

/// `GET /v1/portfolio/calendar`: only UTC days that have data.
class PortfolioCalendarMonth {
  PortfolioCalendarMonth({required this.month, required Map<DateTime, Decimal> days})
    : days = Map.unmodifiable(days);
  final DateTime month;
  final Map<DateTime, Decimal> days;
}
