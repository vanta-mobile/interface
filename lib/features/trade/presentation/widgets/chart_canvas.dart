import 'package:flutter/material.dart';
import 'package:k_chart_plus/k_chart_plus.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../market/domain/market.dart';
import '../../application/chart_preferences.dart';
import 'chart_touch_scroll.dart';
import 'chart_entities.dart';

/// Package entities are mutable, so they stay confined to this adapter.
class ChartCanvas extends StatefulWidget {
  const ChartCanvas({
    super.key,
    required this.market,
    required this.preferences,
    required this.mainHeight,
    required this.secondaryHeight,
    this.onLoadOlder,
  });
  final Market market;
  final ChartPreferences preferences;
  final double mainHeight, secondaryHeight;
  final VoidCallback? onLoadOlder;
  @override
  State<ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends State<ChartCanvas> {
  late List<KLineEntity> entities;
  late List<MainIndicator<dynamic, dynamic>> indicators;
  late List<SecondaryIndicator<dynamic, dynamic>> secondary;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(ChartCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.market != widget.market ||
        oldWidget.preferences.main != widget.preferences.main ||
        oldWidget.preferences.secondary != widget.preferences.secondary) {
      _prepare();
    } else if (oldWidget.preferences.parameters != widget.preferences.parameters ||
        oldWidget.preferences.chartType != widget.preferences.chartType) {
      _prepare();
    }
  }

  void _prepare() {
    entities = chartEntities(
      widget.market.candles,
      heikinAshi: widget.preferences.chartType == KChartType.heikinAshi,
    );
    final params = widget.preferences.parameters;
    List<int> ints(String name) => params[name].map((value) => value.toInt()).toList();
    indicators = switch (widget.preferences.main) {
      'MA' => [MAIndicator(calcParams: ints('MA'))],
      'BOLL' => [
        BOLLIndicator(period: params['BOLL'][0].toInt(), multiplier: params['BOLL'][1].toDouble()),
      ],
      _ => [],
    };
    secondary = switch (widget.preferences.secondary) {
      'MACD' => [MACDIndicator(calcParams: ints('MACD'))],
      'KDJ' => [KDJIndicator(calcParams: ints('KDJ'))],
      'RSI' => [RSIIndicator(calcParams: ints('RSI'))],
      'WR' => [WRIndicator(calcParams: ints('WR'))],
      'CCI' => [CCIIndicator(calcParams: ints('CCI'))],
      _ => [],
    };
    DataUtil.calculateAll(entities, indicators, secondary);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ChartTouchScroll(
      child: ClipRect(
        child: KChartWidget(
          entities,
          const KChartStyle(),
          const KChartColors(
            bgColor: AppColors.surface,
            upColor: AppColors.positive,
            dnColor: AppColors.negative,
            volUpColor: AppColors.positiveDepth,
            volDnColor: AppColors.negativeDepth,
            gridColor: AppColors.line,
            defaultTextColor: AppColors.muted,
            nowPriceUpColor: AppColors.positive,
            nowPriceDnColor: AppColors.negative,
            maxColor: AppColors.secondary,
            minColor: AppColors.secondary,
            ma5Color: AppColors.warning,
            ma10Color: AppColors.accent,
            crossColor: AppColors.secondary,
            crossTextColor: AppColors.text,
            selectFillColor: AppColors.raised,
            selectBorderColor: AppColors.line,
            kLineColor: AppColors.accent,
            kLineFillColors: [AppColors.accentSoft, AppColors.surface],
          ),
          mainIndicators: indicators,
          secondaryIndicators: secondary,
          volHidden: !widget.preferences.volume,
          isTrendLine: false,
          isLine: widget.preferences.line,
          chartType: widget.preferences.chartType,
          priceScale: widget.preferences.priceScale,
          currentPrice: widget.market.price.toDouble(),
          onLoadMore: (right) {
            if (!right) widget.onLoadOlder?.call();
          },
          fixedLength: marketDrawingDecimals(
            widget.market.candles.expand((c) => [c.open, c.high, c.low, c.close]),
            minimum: widget.market.precision.priceDecimals,
          ),
          xFrontPadding: 65,
          rightPadding: (constraints.maxWidth * .18).clamp(48, 100),
          maxRightPadding: constraints.maxWidth * .6,
          mBaseHeight: widget.mainHeight,
          mSecondaryHeight: widget.secondaryHeight,
          isTapShowInfoDialog: true,
          detailBuilder: (entity) {
            final raw = widget.market.candles.firstWhere((c) => c.time == entity.time);
            return Container(
              key: const Key('candle-detail'),
              width: (constraints.maxWidth - 20).clamp(156, 240),
              padding: const EdgeInsets.all(8),
              color: AppColors.raised,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in [
                    ('open', raw.open),
                    ('candleHigh', raw.high),
                    ('candleLow', raw.low),
                    ('candleClose', raw.close),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr(context, entry.$1),
                              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                marketNumber(
                                  entry.$2,
                                  minimumDecimals: widget.market.precision.priceDecimals,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
