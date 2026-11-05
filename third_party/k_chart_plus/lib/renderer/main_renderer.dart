import 'package:flutter/material.dart';
import 'package:k_chart_plus/indicator/indicator_template.dart';
import '../entity/candle_entity.dart';
import '../utils/number_util.dart';
import 'base_chart_renderer.dart';
import '../styles/chart_options.dart';
import 'price_series_renderer.dart';

enum VerticalTextAlignment { left, right }

//For TrendLine
double? trendLineMax;
double? trendLineScale;
double? trendLineContentRec;

class MainRenderer extends BaseChartRenderer<CandleEntity> {
  late double mCandleWidth;
  late double mCandleLineWidth;
  List<MainIndicator> indicatorLi;
  bool isLine;
  final KChartType chartType;
  final KPriceAxis priceAxis;

  //绘制的内容区域
  late Rect _contentRect;
  double _contentPadding = 5.0;
  final KChartStyle chartStyle;
  final KChartColors chartColors;
  final double mLineStrokeWidth = 1.0;
  double scaleX;
  late Paint mLinePaint;
  final VerticalTextAlignment verticalTextAlignment;
  final double mBottomPadding;

  MainRenderer(
    Rect mainRect,
    double maxValue,
    double minValue,
    double topPadding,
    this.indicatorLi,
    this.isLine,
    int fixedLength,
    this.chartStyle,
    this.chartColors,
    this.scaleX,
    this.verticalTextAlignment,
    this.mBottomPadding, {
    this.chartType = KChartType.candles,
    this.priceAxis = const KPriceAxis(KPriceScale.regular, 1),
  }) : super(
          chartRect: mainRect,
          maxValue: maxValue,
          minValue: minValue,
          topPadding: topPadding,
          fixedLength: fixedLength,
          gridColor: chartColors.gridColor,
        ) {
    mCandleWidth = this.chartStyle.candleWidth;
    mCandleLineWidth = this.chartStyle.candleLineWidth;
    mLinePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = mLineStrokeWidth
      ..color = this.chartColors.kLineColor;
    _contentRect = Rect.fromLTRB(
      chartRect.left,
      chartRect.top + _contentPadding,
      chartRect.right,
      chartRect.bottom - _contentPadding,
    );
    if (this.maxValue == this.minValue) {
      this.maxValue *= 1.005;
      this.minValue /= 1.005;
    }
    scaleY = _contentRect.height /
        (priceAxis.coordinate(this.maxValue) - priceAxis.coordinate(this.minValue));
  }

  @override
  void drawText(Canvas canvas, CandleEntity data, double x) {
    double y = 2.0;
    for (int i = 0; i < indicatorLi.length; ++i) {
      TextSpan? span = indicatorLi[i].drawFigure(data, fixedLength, chartColors);
      if (span == null) return;
      TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      tp.layout(minWidth: 0, maxWidth: chartRect.width - chartStyle.space);

      Offset offset = Offset(x, y);

      canvas.drawRect(
        Rect.fromLTRB(
          offset.dx - 2,
          offset.dy - 2,
          tp.width + offset.dx + 2,
          tp.height + offset.dy + 2,
        ),
        Paint()..color = this.chartColors.bgColor.withAlpha(80),
      );

      tp.paint(canvas, offset);

      y = y + tp.height + 2.0; // update y
    }
  }

  @override
  void drawChart(CandleEntity lastPoint, CandleEntity curPoint, double lastX, double curX,
      Size size, Canvas canvas) {
    if (chartType == KChartType.candles ||
        chartType == KChartType.hollowCandles ||
        chartType == KChartType.heikinAshi) {
      drawCandle(curPoint, canvas, curX);
    } else {
      drawPriceSeries(
          canvas: canvas,
          last: lastPoint,
          point: curPoint,
          lastX: lastX,
          x: curX,
          getY: getY,
          rect: _contentRect,
          type: chartType,
          colors: chartColors,
          width: mCandleWidth,
          scaleX: scaleX,
          baseline: priceAxis.reference);
    }
    for (final indicator in indicatorLi) {
      indicator.drawChart(lastPoint, curPoint, lastX, curX, getY, canvas, chartColors);
    }
  }

  Shader? mLineFillShader;
  Path? mLinePath, mLineFillPath;
  Paint mLineFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  //画折线图
  drawPolyline(double lastPrice, double curPrice, Canvas canvas, double lastX, double curX) {
//    drawLine(lastPrice + 100, curPrice + 100, canvas, lastX, curX, ChartColors.kLineColor);
    mLinePath ??= Path();

//    if (lastX == curX) {
//      mLinePath.moveTo(lastX, getY(lastPrice));
//    } else {
////      mLinePath.lineTo(curX, getY(curPrice));
//      mLinePath.cubicTo(
//          (lastX + curX) / 2, getY(lastPrice), (lastX + curX) / 2, getY(curPrice), curX, getY(curPrice));
//    }
    if (lastX == curX) lastX = 0; //起点位置填充
    mLinePath!.moveTo(lastX, getY(lastPrice));
    mLinePath!.cubicTo(
      (lastX + curX) / 2,
      getY(lastPrice),
      (lastX + curX) / 2,
      getY(curPrice),
      curX,
      getY(curPrice),
    );

    //画阴影
    mLineFillShader ??= LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      tileMode: TileMode.clamp,
      colors: this.chartColors.kLineFillColors,
    ).createShader(
      Rect.fromLTRB(
        chartRect.left,
        chartRect.top,
        chartRect.right,
        chartRect.bottom,
      ),
    );
    mLineFillPaint..shader = mLineFillShader;

    mLineFillPath ??= Path();

    mLineFillPath!.moveTo(lastX, chartRect.height + chartRect.top);
    mLineFillPath!.lineTo(lastX, getY(lastPrice));
    mLineFillPath!.cubicTo(
      (lastX + curX) / 2,
      getY(lastPrice),
      (lastX + curX) / 2,
      getY(curPrice),
      curX,
      getY(curPrice),
    );
    mLineFillPath!.lineTo(curX, chartRect.height + chartRect.top);
    mLineFillPath!.close();

    canvas.drawPath(mLineFillPath!, mLineFillPaint);
    mLineFillPath!.reset();

    canvas.drawPath(
      mLinePath!,
      mLinePaint..strokeWidth = (mLineStrokeWidth / scaleX).clamp(0.1, 1.0),
    );
    mLinePath!.reset();
  }

  void drawCandle(CandleEntity curPoint, Canvas canvas, double curX) {
    var high = getY(curPoint.high);
    var low = getY(curPoint.low);
    var open = getY(curPoint.open);
    var close = getY(curPoint.close);
    double r = mCandleWidth / 2;
    double lineR = mCandleLineWidth / 2;
    if (open >= close) {
      // 实体高度>= CandleLineWidth
      if (open - close < mCandleLineWidth) {
        open = close + mCandleLineWidth;
      }
      chartPaint.color = this.chartColors.upColor;
      chartPaint.style =
          chartType == KChartType.hollowCandles ? PaintingStyle.stroke : PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(curX - r, close, curX + r, open),
        chartPaint,
      );
      chartPaint.style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(curX - lineR, high, curX + lineR, low),
        chartPaint,
      );
    } else if (close > open) {
      // 实体高度>= CandleLineWidth
      if (close - open < mCandleLineWidth) {
        open = close - mCandleLineWidth;
      }
      chartPaint.color = this.chartColors.dnColor;
      canvas.drawRect(
        Rect.fromLTRB(curX - r, open, curX + r, close),
        chartPaint,
      );
      canvas.drawRect(
        Rect.fromLTRB(curX - lineR, high, curX + lineR, low),
        chartPaint,
      );
    }
  }

  @override
  void drawVerticalText(canvas, textStyle, int gridRows) {
    double rowSpace = chartRect.height / gridRows;
    for (var i = 0; i <= gridRows; ++i) {
      final coordinate = priceAxis.coordinate(maxValue) -
          (priceAxis.coordinate(maxValue) - priceAxis.coordinate(minValue)) * i / gridRows;
      final value = priceAxis.price(coordinate);
      TextSpan span = TextSpan(
        text: priceAxis.format(value, fixedLength),
        style: textStyle,
      );
      TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();

      double offsetX;
      switch (verticalTextAlignment) {
        case VerticalTextAlignment.left:
          offsetX = this.chartStyle.space;
          break;
        case VerticalTextAlignment.right:
          offsetX = chartRect.width - tp.width - this.chartStyle.space;
          break;
      }

      if (i == 0) {
        tp.paint(canvas, Offset(offsetX, topPadding));
      } else {
        tp.paint(
          canvas,
          Offset(offsetX, rowSpace * i - tp.height + topPadding),
        );
      }
    }
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
//    final int gridRows = 4, gridColumns = 4;
    double rowSpace = chartRect.height / gridRows;
    for (int i = 0; i <= gridRows; i++) {
      canvas.drawLine(
        Offset(0, rowSpace * i + topPadding),
        Offset(chartRect.width, rowSpace * i + topPadding),
        gridPaint,
      );
    }
    double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= columnSpace; i++) {
      canvas.drawLine(
        Offset(columnSpace * i, 0),
        Offset(columnSpace * i, chartRect.bottom),
        gridPaint,
      );
    }

    /// draw top grid
    canvas.drawLine(
      Offset(0, 0),
      Offset(chartRect.width, 0),
      gridPaint..color,
    );

    /// draw bottom grid
    canvas.drawLine(
      Offset(0, chartRect.bottom + mBottomPadding),
      Offset(chartRect.width, chartRect.bottom + mBottomPadding),
      gridPaint..color,
    );
  }

  @override
  double getY(double y) {
    //For TrendLine
    updateTrendLineData();
    if (priceAxis.mode == KPriceScale.logarithmic && y <= 0)
      return _contentRect.bottom + _contentRect.height;
    return (priceAxis.coordinate(maxValue) - priceAxis.coordinate(y)) * scaleY + _contentRect.top;
  }

  void updateTrendLineData() {
    trendLineMax = maxValue;
    trendLineScale = scaleY;
    trendLineContentRec = _contentRect.top;
  }
}
