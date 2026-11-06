import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/motion/animated_number_text.dart';

Widget buildTestApp(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Both RepaintBoundary and FractionalTranslation are ambient in a
  // MaterialApp, so scope the check to the widget under test.
  final rolling = find.descendant(
    of: find.byType(AnimatedNumberText),
    matching: find.byType(FractionalTranslation),
  );

  group('compareFormattedAmounts', () {
    test('compares rounded compact values across suffix boundaries', () {
      expect(compareFormattedAmounts('1,000K', '1M'), NumberTrend.flat);
      expect(compareFormattedAmounts('999.999K', '0.99M'), NumberTrend.down);
      expect(compareFormattedAmounts('-999.999K', '-0.99M'), NumberTrend.up);
      expect(compareFormattedAmounts('0T', '1'), NumberTrend.up);
      expect(compareFormattedAmounts('0', '-1K'), NumberTrend.down);
      expect(
        compareFormattedAmounts('9007199254740992.000001', '9007199254740992.000002'),
        NumberTrend.up,
      );
    });

    test('accepts both USD sign positions produced by the formatter', () {
      expect(compareFormattedAmounts(r'$-1.20', r'$-1.10'), NumberTrend.up);
      expect(compareFormattedAmounts(r'-$1.20K', r'-$1.10K'), NumberTrend.up);
    });

    test('reads the direction of the formatted shapes the app renders', () {
      expect(compareFormattedAmounts(r'$182.40', r'$182.45'), NumberTrend.up);
      expect(compareFormattedAmounts(r'$182.45', r'$182.40'), NumberTrend.down);
      expect(compareFormattedAmounts(r'$9.99', r'$10.01'), NumberTrend.up);
      expect(compareFormattedAmounts(r'$1,999', r'$2,000'), NumberTrend.up);
      expect(compareFormattedAmounts('+2.31%', '+2.4%'), NumberTrend.up);
      expect(compareFormattedAmounts('-2.31%', '-2.4%'), NumberTrend.down);
      expect(compareFormattedAmounts('-1%', '+1%'), NumberTrend.up);
      expect(compareFormattedAmounts(r'$980K', r'$1.2M'), NumberTrend.up);
      expect(compareFormattedAmounts('154.2K', '154.2K'), NumberTrend.flat);
      expect(compareFormattedAmounts('-0%', '0'), NumberTrend.flat);
    });

    test('gives up on values that are not numbers', () {
      expect(compareFormattedAmounts('—', r'$10'), isNull);
      expect(compareFormattedAmounts(r'$10', '—'), isNull);
      expect(compareFormattedAmounts('', r'$10'), isNull);
    });
  });

  Future<void> pumpValue(WidgetTester tester, String value) =>
      tester.pumpWidget(buildTestApp(AnimatedNumberText(value, key: const Key('n'))));

  testWidgets('sits as a plain Text until the value changes', (tester) async {
    await pumpValue(tester, r'$182.40');

    expect(find.text(r'$182.40'), findsOneWidget);
    expect(rolling, findsNothing);
  });

  testWidgets('turns only the characters that changed', (tester) async {
    await pumpValue(tester, r'$182.40');
    await pumpValue(tester, r'$182.45');
    await tester.pump(const Duration(milliseconds: 40));

    // Every character is its own cell; only the last one has two faces.
    for (final unchanged in [r'$', '1', '8', '2', '.', '4']) {
      expect(find.text(unchanged), findsOneWidget);
    }
    expect(find.text('0'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(rolling, findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.text(r'$182.45'), findsOneWidget);
    expect(rolling, findsNothing);
  });

  testWidgets('can skip initial data and animate later live updates', (tester) async {
    Widget app(String value) =>
        buildTestApp(AnimatedNumberText(value, key: const Key('n'), animateFirstChange: false));

    await tester.pumpWidget(app(r'$100'));
    await tester.pumpWidget(app(r'$110'));
    await tester.pump();
    expect(find.text(r'$110'), findsOneWidget);
    expect(rolling, findsNothing);

    await tester.pumpWidget(app(r'$120'));
    await tester.pump(const Duration(milliseconds: 40));
    expect(rolling, findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('digits stay opaque so the turn reads as a wheel', (tester) async {
    await pumpValue(tester, r'$100');
    await pumpValue(tester, r'$110');
    await tester.pump(const Duration(milliseconds: 200));

    final faded = find.descendant(
      of: find.byType(AnimatedNumberText),
      matching: find.byType(Opacity),
    );
    expect(faded, findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a widening amount turns in from an empty wheel', (tester) async {
    await pumpValue(tester, r'$99');
    await pumpValue(tester, r'$101');
    await tester.pump(const Duration(milliseconds: 40));

    // Paired from the right: '$99' becomes ' $99' against '$101', so every
    // cell differs and the leading one turns in from blank.
    expect(rolling, findsNWidgets(8));

    await tester.pumpAndSettle();
    expect(find.text(r'$101'), findsOneWidget);
  });

  testWidgets('settles back to a plain Text with no animation running', (tester) async {
    await pumpValue(tester, r'$100');
    await pumpValue(tester, r'$110');
    await tester.pumpAndSettle();

    expect(rolling, findsNothing);
    expect(find.text(r'$110'), findsOneWidget);
  });

  testWidgets('animates a number while preserving its asset suffix', (tester) async {
    Widget app(String amount) => buildTestApp(
      AnimatedNumberText('$amount USDC', key: const Key('n'), comparisonValue: amount),
    );

    await tester.pumpWidget(app('0.12'));
    await tester.pumpWidget(app('0.15'));
    await tester.pump(const Duration(milliseconds: 40));

    expect(rolling, findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('0.15 USDC'), findsOneWidget);
  });

  testWidgets('swaps without motion when the value is not a number', (tester) async {
    await pumpValue(tester, r'$100');
    await pumpValue(tester, '—');
    await tester.pump();

    expect(find.text('—'), findsOneWidget);
    expect(rolling, findsNothing);
  });

  testWidgets('honours the platform request for reduced motion', (tester) async {
    Widget app(String value) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: buildTestApp(AnimatedNumberText(value)),
    );
    await tester.pumpWidget(app(r'$100'));
    await tester.pumpWidget(app(r'$110'));
    await tester.pump();

    expect(find.text(r'$110'), findsOneWidget);
    expect(rolling, findsNothing);
  });

  testWidgets('exposes one complete value to screen readers during motion', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpValue(tester, r'$100');
      await pumpValue(tester, r'$110');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.bySemanticsLabel(r'$110'), findsOneWidget);
      expect(find.bySemanticsLabel('0'), findsNothing);
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('zero duration replaces the value immediately', (tester) async {
    Widget app(String value) => buildTestApp(AnimatedNumberText(value, duration: Duration.zero));
    await tester.pumpWidget(app('1'));
    await tester.pumpWidget(app('2'));
    expect(find.text('2'), findsOneWidget);
    expect(rolling, findsNothing);
  });

  testWidgets('uses the latest comparison even when the displayed text is unchanged', (
    tester,
  ) async {
    Widget app(String value, String comparison) =>
        buildTestApp(AnimatedNumberText(value, comparisonValue: comparison));
    await tester.pumpWidget(app('1', '1.1'));
    await tester.pumpWidget(app('1', '1.9'));
    await tester.pumpWidget(app('2', '1.8'));
    await tester.pump(const Duration(milliseconds: 200));

    final incoming = tester.widget<FractionalTranslation>(rolling.first);
    expect(incoming.translation.dy, lessThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('wraps on narrow layouts with enlarged text during motion', (tester) async {
    Widget app(String value) => buildTestApp(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: SizedBox(width: 120, child: AnimatedNumberText(value, softWrap: true)),
      ),
    );
    await tester.pumpWidget(app(r'$1,234,567.89'));
    await tester.pumpWidget(app(r'$1,234,567.90'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(r'$1,234,567.90'), findsOneWidget);
  });
}
