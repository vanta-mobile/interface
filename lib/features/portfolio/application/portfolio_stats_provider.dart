import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/request_scope.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../data/portfolio_stats_repository.dart';
import '../domain/portfolio_overview.dart';
import '../domain/portfolio_stats.dart';
import 'portfolio_overview_provider.dart';

final portfolioStatsRepositoryProvider = Provider<PortfolioStatsRepository?>((ref) {
  final session = ref.watch(vantaApiSessionRepositoryProvider);
  return session == null ? null : PortfolioStatsRepository(session);
});

/// The ready session's wallet. Reads re-run when it changes, so statistics
/// from a previous wallet are never shown for the next one.
final _statsAddressProvider = Provider<String?>((ref) {
  final session = ref.watch(vantaApiSessionProvider);
  return session.ready ? session.address : null;
});

Future<T?> _read<T>(Ref ref, Future<T> Function(PortfolioStatsRepository) read) {
  final repository = ref.watch(portfolioStatsRepositoryProvider);
  if (ref.watch(_statsAddressProvider) == null || repository == null) return Future.value();
  return RequestScope.run(() => ref.mounted, () => read(repository));
}

// Implicit provider retry is disabled: failures surface to the section, and a
// 429 must not be retried before Retry-After.
final portfolioSummaryProvider = FutureProvider.autoDispose
    .family<PortfolioPeriodSummary?, PortfolioStatsPeriod>(
      retry: (_, _) => null,
      (ref, period) => _read(ref, (r) => r.summary(period)),
    );
final portfolioValueCurveProvider = FutureProvider.autoDispose
    .family<PortfolioCurve?, PortfolioStatsPeriod>(
      retry: (_, _) => null,
      (ref, period) => _read(ref, (r) => r.valueCurve(period)),
    );
final portfolioPnlCurveProvider = FutureProvider.autoDispose
    .family<PortfolioCurve?, PortfolioStatsPeriod>(
      retry: (_, _) => null,
      (ref, period) => _read(ref, (r) => r.pnlCurve(period)),
    );

/// Keyed by the UTC first day of the month.
final portfolioCalendarProvider = FutureProvider.autoDispose
    .family<PortfolioCalendarMonth?, DateTime>(
      retry: (_, _) => null,
      (ref, month) => _read(ref, (r) => r.calendar(month, today: _today(ref))),
    );

DateTime _today(Ref ref) {
  final now = ref.read(vantaApiClockProvider)().toUtc();
  return DateTime.utc(now.year, now.month, now.day);
}

/// Why a section without data shows the failure state instead of a skeleton.
enum PortfolioStatsBlock {
  /// No `VANTA_API_ORIGIN` / relying party in this build.
  unavailable,

  /// No session: never signed, rejected, expired or revoked.
  signIn,

  /// A SIWE request is waiting for the user's wallet; this is not loading.
  signing,

  /// The session is ready but the read failed.
  failed,
}

/// Display state for a statistics section. [loading] is true only while a
/// session is restored or a read runs and the section has nothing to show;
/// retained values stay visible during refresh.
class PortfolioStatsView {
  const PortfolioStatsView(
    this.performance, {
    this.loading = false,
    this.historyLoading = false,
    this.failure,
    this.block,
  });
  final PortfolioPerformance performance;

  /// Summary metrics and the history series load independently.
  final bool loading, historyLoading;

  /// Session or read failure; with retained data it is shown as a caption.
  final Object? failure;

  /// Set only when the section has no data at all.
  final PortfolioStatsBlock? block;
}

PortfolioStatsPeriod portfolioStatsPeriod(String label) => switch (label) {
  '24h' => PortfolioStatsPeriod.day,
  '14D' => PortfolioStatsPeriod.twoWeeks,
  '30D' => PortfolioStatsPeriod.month,
  'All' => PortfolioStatsPeriod.all,
  _ => PortfolioStatsPeriod.week,
};

/// Main page: today's PnL, the 7D card and the total-value history of [period].
final portfolioPerformanceProvider = Provider.autoDispose
    .family<PortfolioStatsView, PortfolioStatsPeriod>((ref, period) {
      final preview = _previewView(ref, history: period, metrics: PortfolioStatsPeriod.week);
      if (preview != null) return preview;
      final today = ref.watch(portfolioSummaryProvider(PortfolioStatsPeriod.day));
      final week = ref.watch(portfolioSummaryProvider(PortfolioStatsPeriod.week));
      final curve = ref.watch(portfolioValueCurveProvider(period));
      return _view(
        ref,
        [today, week],
        curve,
        (today: today.value, summary: week.value, curve: curve.value),
      );
    });

/// PnL details: [period] summary, cumulative PnL history and today's PnL.
final portfolioPnlPerformanceProvider = Provider.autoDispose
    .family<PortfolioStatsView, PortfolioStatsPeriod>((ref, period) {
      final preview = _previewView(ref, history: period, metrics: period);
      if (preview != null) return preview;
      final today = ref.watch(portfolioSummaryProvider(PortfolioStatsPeriod.day));
      final summary = ref.watch(portfolioSummaryProvider(period));
      final curve = ref.watch(portfolioPnlCurveProvider(period));
      return _view(
        ref,
        [today, summary],
        curve,
        (today: today.value, summary: summary.value, curve: curve.value),
      );
    });

/// The month's daily net PnL; preview keeps its labelled static sample.
final portfolioCalendarViewProvider = Provider.autoDispose.family<PortfolioStatsView, DateTime>((
  ref,
  month,
) {
  if (ref.watch(portfolioPreviewProvider)) {
    return PortfolioStatsView(ref.watch(portfolioOverviewProvider).performance);
  }
  final calendar = ref.watch(portfolioCalendarProvider(month));
  return PortfolioStatsView(
    PortfolioPerformance(dailyPnl: calendar.value?.days ?? const {}),
    loading: _loading(ref, [calendar]),
    failure: _failure(ref, [calendar]),
    block: _block(ref, [calendar]),
  );
});

/// The static sample only covers 7D; other ranges show unavailable.
PortfolioStatsView? _previewView(
  Ref ref, {
  required PortfolioStatsPeriod history,
  required PortfolioStatsPeriod metrics,
}) {
  if (!ref.watch(portfolioPreviewProvider)) return null;
  final p = ref.watch(portfolioOverviewProvider).performance;
  const week = PortfolioStatsPeriod.week;
  return PortfolioStatsView(
    PortfolioPerformance(
      pnl: metrics == week ? p.pnl : null,
      returnPercent: metrics == week ? p.returnPercent : null,
      volume: metrics == week ? p.volume : null,
      todayPnl: p.todayPnl,
      todayPercent: p.todayPercent,
      history: history == week ? p.history : const [],
      start: metrics == week || history == week ? p.start : null,
      end: metrics == week || history == week ? p.end : null,
    ),
  );
}

PortfolioStatsView _view(
  Ref ref,
  List<AsyncValue<Object?>> summaries,
  AsyncValue<Object?> history,
  ({PortfolioPeriodSummary? today, PortfolioPeriodSummary? summary, PortfolioCurve? curve}) data,
) {
  final points = data.curve?.points ?? const <PortfolioCurvePoint>[];
  return PortfolioStatsView(
    PortfolioPerformance(
      pnl: data.summary?.pnl,
      returnPercent: data.summary?.returnPercent,
      volume: data.summary?.volume,
      todayPnl: data.today?.pnl,
      todayPercent: data.today?.returnPercent,
      history: points.map((p) => p.value),
      start: points.isEmpty ? null : points.first.bucket,
      end: points.isEmpty ? null : points.last.bucket,
    ),
    loading: _loading(ref, summaries),
    historyLoading: _loading(ref, [history]),
    failure: _failure(ref, [...summaries, history]),
    block: _block(ref, [...summaries, history]),
  );
}

bool _loading(Ref ref, List<AsyncValue<Object?>> sources) {
  final session = ref.watch(vantaApiSessionProvider);
  final empty = sources.every((s) => s.value == null);
  return empty &&
      (session.status == VantaApiSessionStatus.restoring ||
          session.ready && sources.any((s) => s.isLoading));
}

PortfolioStatsBlock? _block(Ref ref, List<AsyncValue<Object?>> sources) {
  if (sources.any((s) => s.value != null)) return null;
  return switch (ref.watch(vantaApiSessionProvider).status) {
    VantaApiSessionStatus.unavailable => PortfolioStatsBlock.unavailable,
    VantaApiSessionStatus.signedOut => PortfolioStatsBlock.signIn,
    VantaApiSessionStatus.signing => PortfolioStatsBlock.signing,
    VantaApiSessionStatus.restoring => null,
    VantaApiSessionStatus.ready =>
      sources.any((s) => s.hasError && !s.isLoading) ? PortfolioStatsBlock.failed : null,
  };
}

Object? _failure(Ref ref, List<AsyncValue<Object?>> sources) {
  for (final source in sources) {
    if (source.hasError && !source.isLoading) return source.error;
  }
  final session = ref.watch(vantaApiSessionProvider);
  return session.ready || session.pending ? null : session.failure;
}

/// Refresh every visible statistics read, including failures. Missing sessions
/// use the explicit sign-in action; navigation and refresh never prompt a wallet.
Future<void> refreshPortfolioStats(Ref ref, {DateTime? calendarMonth}) async {
  if (ref.read(portfolioPreviewProvider)) return;
  if (!ref.mounted || !ref.read(vantaApiSessionProvider).ready) return;
  final reads = <Future<Object?>>[
    for (final period in PortfolioStatsPeriod.values) ...[
      if (ref.exists(portfolioSummaryProvider(period)))
        ref.refresh(portfolioSummaryProvider(period).future),
      if (ref.exists(portfolioValueCurveProvider(period)))
        ref.refresh(portfolioValueCurveProvider(period).future),
      if (ref.exists(portfolioPnlCurveProvider(period)))
        ref.refresh(portfolioPnlCurveProvider(period).future),
    ],
    if (calendarMonth != null) ref.refresh(portfolioCalendarProvider(calendarMonth).future),
  ];
  await Future.wait(reads.map((read) => read.catchError((Object _) => null)));
}

/// The section action signs in when needed, then awaits all statistics reads.
final portfolioStatsRefreshProvider = Provider<Future<void> Function({DateTime? calendarMonth})>(
  (ref) => ({calendarMonth}) async {
    await ref.read(vantaApiSessionProvider.notifier).ensure();
    if (ref.mounted) await refreshPortfolioStats(ref, calendarMonth: calendarMonth);
  },
);
