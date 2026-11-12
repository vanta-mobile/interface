import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/market_failure.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market.dart';
import '../../application/chart_preferences.dart';
import '../../application/navigation_provider.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'chart_price_viewport.dart';
import 'chart_axis_controls.dart';
import 'chart_market_status.dart';
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
        final secondaryHeight = wide ? 78.0 : 62.0;
        final extraHeight =
            (preferences.volume ? secondaryHeight : 0) +
            (preferences.secondary != 'none' ? secondaryHeight : 0) +
            (preferences.main == 'none' ? 0 : 12);
        // Fullscreen keeps only the timeframe row above the canvas (02.17).
        final mainHeight = widget.expanded
            ? math.max(150.0, (widget.viewportHeight ?? 640) - 45 - extraHeight)
            : wide
            ? 300.0
            : 210.0;
        final canvasHeight = mainHeight + extraHeight;
        return Panel(
          flat: widget.flat,
          child: Column(
            children: [
              ChartTimeframes(trailing: _FullscreenButton(expanded: widget.expanded)),
              const Divider(),
              if (!widget.expanded) _CandleLegend(market: quote),
              if (gap != null || quote?.failure != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    quote?.failure ?? tr(context, 'gap'),
                    style: const TextStyle(fontSize: 10, color: AppColors.warning),
                  ),
                ),
              SizedBox(
                key: const Key('chart-canvas-area'),
                height: canvasHeight,
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
              ),
              if (!widget.expanded) ...[
                const Divider(),
                const ChartAxisControls(),
                const ChartIndicatorShortcuts(),
                const Divider(),
                const ChartMarketStatus(depth: false),
              ],
            ],
          ),
        );
      },
    );
  }
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

class _CandleLegend extends StatelessWidget {
  const _CandleLegend({required this.market});
  final Market? market;
  @override
  Widget build(BuildContext context) {
    final candle = market?.candles.lastOrNull;
    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final value in [
              ('open', candle?.open),
              ('candleHigh', candle?.high),
              ('candleLow', candle?.low),
              ('candleClose', candle?.close),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${tr(context, value.$1)} ',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      TextSpan(
                        text: value.$2 == null
                            ? '—'
                            : marketNumber(
                                value.$2!,
                                minimumDecimals: market?.precision.priceDecimals ?? 0,
                              ),
                        style: TextStyle(
                          color: candle == null
                              ? AppColors.secondary
                              : candle.close >= candle.open
                              ? AppColors.positive
                              : AppColors.negative,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 9, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
