import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../core/errors/api_error_details.dart';
import '../../auth/data/vanta_api_session_repository.dart';
import '../domain/portfolio_stats.dart';
import 'portfolio_stats_mapper.dart';

/// Read-only `Portfolio` tag of the Vanta API, scoped to the session's current
/// operating account (no `account_id`: the server default is that account).
class PortfolioStatsRepository {
  const PortfolioStatsRepository(this.session);
  final VantaApiSessionRepository session;

  static const summaryPath = '/v1/portfolio/summary';
  static const curvePath = '/v1/portfolio/curve';
  static const calendarPath = '/v1/portfolio/calendar';

  Future<PortfolioPeriodSummary> summary(PortfolioStatsPeriod period) =>
      _read(summaryPath, {'period': period.query}, mapPortfolioSummary);

  Future<PortfolioCurve> valueCurve(PortfolioStatsPeriod period) =>
      _read(curvePath, {'period': period.query, 'metric': 'value'}, mapValueCurve);

  Future<PortfolioCurve> pnlCurve(PortfolioStatsPeriod period) =>
      _read(curvePath, {'period': period.query, 'metric': 'pnl'}, mapPnlCurve);

  /// One UTC month, ending today for the current month (span ≤ 31 days < 90).
  Future<PortfolioCalendarMonth> calendar(DateTime month, {required DateTime today}) {
    final first = DateTime.utc(month.year, month.month);
    final last = DateTime.utc(month.year, month.month + 1, 0);
    final end = today.isBefore(last) ? today : last;
    return _read(calendarPath, {
      'from': _day(first),
      'to': _day(end.isBefore(first) ? first : end),
    }, (json) => mapCalendar(json, month: first));
  }

  Future<T> _read<T>(
    String path,
    Map<String, String> query,
    T Function(Map<String, Object?>) map,
  ) async {
    final json = await session.get(path, query: query);
    try {
      return map(json);
    } on FormatException {
      throw VantaApiFailure(
        vantaApiDataInvalid,
        details: ApiErrorDetails(cause: ApiErrorCause.invalidResponse, endpoint: path),
      );
    }
  }

  static String _day(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
