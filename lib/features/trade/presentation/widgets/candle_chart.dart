import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/market_failure.dart';
import '../../../../core/strings.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market.dart';
import '../../application/chart_preferences.dart';
import '../../application/navigation_provider.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'chart_price_viewport.dart';
import 'chart_controls.dart';
import 'chart_toolbar.dart';
import 'trade_icon.dart';
import 'primitives.dart';
import '../../../../core/presentation/status_view.dart';

class CandleChart extends ConsumerStatefulWidget {
  const CandleChart({super.key, this.expanded = false, this.viewportHeight, this.flat = false});
  final bool expanded;
  final bool flat;
  final double? viewportHeight;
  @override
  ConsumerState<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends ConsumerState<CandleChart> {
  Market? _lastChart;
  // Set once a phone turns landscape, so leaving fullscreen keeps the normal
  // page until the device returns to portrait and cannot loop back into it.
  bool _landscapeHandled = false;

  void _followOrientation() {
    if (widget.expanded) return;
    final size = MediaQuery.sizeOf(context);
    if (size.width <= size.height) {
      _landscapeHandled = false;
      return;
    }
    final chartTab = ref.watch(futuresWorkspaceTabProvider) == FuturesWorkspaceTab.chart;
    if (_landscapeHandled || !chartTab || size.shortestSide >= 600) return;
    _landscapeHandled = true;
    // Rotating under another page (including fullscreen) does not reopen it later.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openChartFullscreen(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    _followOrientation();
    final preferences = ref.watch(chartPreferencesProvider);
    final data = ref.watch(marketProvider);
    final interval = ref.watch(intervalProvider);
    final symbol = ref.watch(symbolProvider);
    final source = ref.watch(marketSyncProvider);
    final gap = source?.series.missingRange;
    final quote = ref.watch(currentMarketProvider);
    // A visual snapshot only. Never expose old data to prices or trading state.
    if (_lastChart?.symbol != symbol) _lastChart = null;
    if (quote != null) _lastChart = quote;
    final previous = _lastChart;
    final chartData = quote != null
        ? AsyncData<Market>(quote)
        : source?.failure != null
        ? AsyncError<Market>(MarketFailure(source!.failure!), StackTrace.empty)
        : !data.isLoading && data.hasError
        ? AsyncError<Market>(data.error!, data.stackTrace!)
        : const AsyncLoading<Market>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        // The K-line tab follows the Figma `chart` component (12.08): 104px
        // lower panes. Fullscreen keeps its own compact panes (02.17).
        final secondaryHeight = widget.expanded ? (wide ? 78.0 : 62.0) : 104.0;
        final extraHeight =
            (preferences.volume ? secondaryHeight : 0) +
            (preferences.secondary != 'none' ? secondaryHeight : 0) +
            (preferences.main == 'none' ? 0 : 12);
        // Fullscreen keeps only the timeframe row above the canvas (02.17).
        final mainHeight = widget.expanded
            ? math.max(150.0, (widget.viewportHeight ?? 640) - 45 - extraHeight)
            : wide
            ? 360.0
            : 285.0;
        final notice = gap != null || quote?.failure != null
            ? quote?.failure ?? tr(context, 'gap')
            : null;
        final historyFailure = widget.expanded ? null : quote?.historyFailure;
        final canvas = SizedBox(
          key: const Key('chart-canvas-area'),
          height: mainHeight + extraHeight,
          child: chartData.when(
            skipLoadingOnRefresh: false,
            data: (market) => ChartPriceViewport(
              market: market,
              loading: false,
              interval: interval,
              preferences: preferences,
              mainHeight: mainHeight,
              secondaryHeight: secondaryHeight,
            ),
            loading: () => ChartPriceViewport(
              market: previous,
              loading: true,
              interval: interval,
              preferences: preferences,
              mainHeight: mainHeight,
              secondaryHeight: secondaryHeight,
            ),
            error: (error, _) => Center(
              child: SingleChildScrollView(
                child: StatusFailureView(
                  key: const Key('chart-load-failure'),
                  padding: const EdgeInsets.all(16),
                  message: error is MarketFailure
                      ? error.message
                      : tr(context, 'marketUnavailable'),
                  onRetry: () async {
                    final sync = ref.read(marketSyncProvider);
                    if (sync == null) {
                      ref.invalidate(instrumentsProvider);
                    } else {
                      sync.retry();
                    }
                    ref.invalidate(marketProvider);
                    await ref.read(marketProvider.future);
                  },
                ),
              ),
            ),
          ),
        );
        final noticeRow = notice == null
            ? null
            : Container(
                height: _noticeHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: Text(
                  notice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TradeTypography.small.copyWith(color: TradeColors.warning),
                ),
              );
        if (widget.expanded) {
          return Panel(
            flat: widget.flat,
            child: Column(
              children: [
                ChartTimeframes(trailing: _FullscreenButton(expanded: widget.expanded)),
                const Divider(),
                ?noticeRow,
                canvas,
              ],
            ),
          );
        }
        final height =
            2 +
            _timeframeHeight +
            _ohlcHeight +
            (noticeRow == null ? 0 : _noticeHeight) +
            mainHeight +
            extraHeight +
            (historyFailure == null ? 0 : _historyHeight) +
            _indicatorHeight +
            _actionHeight;
        return SizedBox(
          key: const Key('chart-component'),
          height: height,
          child: OverflowBox(
            // Bleed past the workspace's 16px gutters, as designed.
            minWidth: constraints.maxWidth + 32,
            maxWidth: constraints.maxWidth + 32,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: TradeColors.background,
                border: Border.symmetric(horizontal: BorderSide(color: TradeColors.line)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: _timeframeHeight - 1, child: ChartTimeframeRow()),
                  const Divider(height: 1, thickness: 1, color: TradeColors.line),
                  SizedBox(
                    height: _ohlcHeight,
                    child: ChartOhlcRow(market: quote),
                  ),
                  ?noticeRow,
                  canvas,
                  if (historyFailure != null)
                    SizedBox(
                      height: _historyHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: ref.read(chartHistoryProvider.notifier).loadOlder,
                          child: Text(
                            '$historyFailure · ${tr(context, 'retry')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TradeTypography.small.copyWith(color: TradeColors.warning),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: _indicatorHeight, child: ChartIndicatorRow()),
                  const SizedBox(height: _actionHeight, child: ChartActionBar()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const _timeframeHeight = 36.0, _ohlcHeight = 28.0, _noticeHeight = 20.0;
  static const _historyHeight = 36.0, _indicatorHeight = 36.0, _actionHeight = 48.0;
}

class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({required this.expanded});
  final bool expanded;
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('chart-expand'),
    tooltip: tr(context, expanded ? 'exitFullscreen' : 'fullscreen'),
    onPressed: expanded ? () => Navigator.maybePop(context) : () => openChartFullscreen(context),
    icon: expanded
        ? const TradeIcon('chart-exit-fullscreen', size: 16, color: TradeColors.text)
        : const Icon(Icons.fullscreen_rounded, size: 18, color: TradeColors.text),
  );
}

Future<void> openChartFullscreen(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (context) => const ChartFullscreenPage()),
);

/// Landscape fullscreen chart (Figma 02.17): only timeframes, chart and the
/// exit control. This page is the one documented exception to never locking
/// orientation: it requests landscape while open and restores the system
/// default when it closes.
class ChartFullscreenPage extends StatefulWidget {
  const ChartFullscreenPage({super.key});
  @override
  State<ChartFullscreenPage> createState() => _ChartFullscreenPageState();
}

class _ChartFullscreenPageState extends State<ChartFullscreenPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // The 02.17 frame has no status or navigation bar.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // An empty list restores the app's normal rotation behavior.
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Tablets in split view may ignore the landscape request. Only there the
    // landscape layout is turned a quarter clockwise instead. The tree stays
    // the same either way so the chart keeps its scroll and zoom.
    final turned = media.size.width <= media.size.height && media.size.shortestSide >= 600;
    final safe = media.padding;
    final chart = RotatedBox(
      key: const Key('chart-fullscreen-rotation'),
      quarterTurns: turned ? 1 : 0,
      child: MediaQuery(
        data: turned
            ? media.copyWith(
                size: Size(media.size.height - safe.vertical, media.size.width - safe.horizontal),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              )
            : media,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: CandleChart(expanded: true, flat: true, viewportHeight: constraints.maxHeight),
          ),
        ),
      ),
    );
    return Scaffold(
      key: const Key('chart-fullscreen'),
      backgroundColor: TradeColors.background,
      body: SafeArea(child: chart),
    );
  }
}
