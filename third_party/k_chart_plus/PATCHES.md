# Local changes to k_chart_plus 1.0.4

Source: https://pub.dev/packages/k_chart_plus/versions/1.0.4
Upstream: https://github.com/TrangLeQuynh/k_chart_plus
The original source license is retained in LICENSE.

The original horizontal-drag and scale recognizers compete in Flutter's
gesture arena. A drag or long press accepted before the second finger lands
prevents the scale recognizer from receiving pinch updates.

`lib/k_chart_pinch.dart` observes two touch pointers independently of that
arena. `k_chart_widget.dart` applies their distance ratio to the existing
chart scale, cancels fling/crosshair on pinch, and suppresses single-finger
callbacks until all fingers are lifted. Scaling is clamped to the original
0.5–2.2 range. Candle/indicator algorithms, market data and depth are unchanged.

The viewport also supports optional screen-space `rightPadding` and
`maxRightPadding`. It accepts negative scroll offsets to expose future space,
with per-viewport bounds shared by drag, fling and paint. Pinch preserves the
future offset in logical pixels, and resize clamps the actual painted offset
before the next drag resumes. Defaults preserve upstream behavior when these
options are absent. No synthetic candles or prices are added for the blank area.

Regression tests are in the application's test/chart_gestures_test.dart and
test/chart_future_space_test.dart and test/widget_test.dart. The local source copy is required at runtime; editing
the global pub cache would not ship the fix to another machine.

The application also exposes time-based price styles (candles, hollow candles,
OHLC bars, line, markers, steps, area, baseline, columns, high-low and derived
Heikin Ashi). `chart_options.dart` defines the styles and regular/log/percentage/
indexed axes; price transformations are confined to the main renderer. Indicator
values stay in quote units; on Heikin Ashi they use the derived chart candles.
Source domain OHLC is unchanged. A separate current-price input lets
derived candles retain the actual quote marker. Percentage/indexed labels use
the first visible candle's open as their reference.

MA/BOLL/MACD/KDJ/RSI/WR/CCI accept configured periods. Hardcoded RSI/WR/KDJ
lookbacks and labels now follow these values. BOLL uses population standard
deviation and starts at the first complete period, with decimal multipliers.
Backward loading is emitted by direct drags as well as flings. Widget updates
preserve the time anchor while history is prepended or live bars are appended.
Additional regression coverage is in `test/features/trade/chart_*_test.dart`.

NumberUtil.format now returns just the grouped integer when decimal flooring
leaves no fractional part. Depth price tooltips previously repeated the integer
after a decimal point whenever precision was nonzero. Regression coverage is in
`test/features/market/market_precision_test.dart`.
