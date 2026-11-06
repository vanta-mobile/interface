import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/presentation/main_order_capacity_panel.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_live_pricing.dart';
import '../../support/main_order_revaluation.dart';

void main() {
  late MainOrderLiveFixture f;
  late ValueNotifier<String> input;
  setUp(() {
    f = MainOrderLiveFixture();
    input = ValueNotifier('1');
    (f.payload['assets'] as List).single['crossWalletBalance'] = '10';
    (f.payload['assets'] as List).single['availableBalance'] = '10';
    f.capacities.transform = (context) => withRevaluationFacts(
      assembledCapacity(context: context, payload: f.payload, receivedAt: f.now, now: f.now),
      takerFee: d('0.001'),
    );
  });
  tearDown(() async {
    input.dispose();
    await f.close();
  });
  Future<void> open(
    WidgetTester tester, {
    String locale = 'en',
    Size size = const Size(430, 900),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(f.open);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: f.container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder(
                valueListenable: input,
                builder: (context, value, _) => MainOrderCapacityPanel(
                  data: f.orders.context,
                  draft: liveDraft(price: '100'),
                  unit: OrderSizeUnit.base,
                  input: value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String line(WidgetTester tester, String side) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(Key('main-order-liquidation-$side')),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data)
      .join('|');
  testWidgets('both post-fill prices change with input and disappear with missing quotes', (
    tester,
  ) async {
    try {
      await open(tester);
      expect(line(tester, 'buy'), contains('≈ 90.55 USDT'));
      expect(line(tester, 'sell'), contains('≈ 109.35 USDT'));
      input.value = '0.5';
      await tester.pumpAndSettle();
      expect(line(tester, 'buy'), contains('≈ 80.50 USDT'));
      expect(line(tester, 'sell'), contains('≈ 119.30 USDT'));
      await tester.runAsync(() async {
        f.now = f.now.add(const Duration(seconds: 11));
        // New Mark without new book/Last cannot keep an old preview alive.
        f.marks.emit(revaluationMarks({'BTCUSDT': '110'}, time: f.now));
        await f.flush();
      });
      await tester.pumpAndSettle();
      expect(line(tester, 'buy'), endsWith('|—'));
      expect(line(tester, 'sell'), endsWith('|—'));
      expect(input.value, '0.5');
      expect(tester.takeException(), null);
    } finally {
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });
  for (final locale in ['en', 'zh']) {
    testWidgets('localized post-fill rows support $locale enlarged landscape and blank input', (
      tester,
    ) async {
      try {
        await open(tester, locale: locale, size: const Size(844, 390), scale: 1.5);
        expect(
          line(tester, 'buy'),
          contains(locale == 'zh' ? '成交后预估强平价' : 'Estimated liquidation price after fill'),
        );
        expect(line(tester, 'buy'), contains('≈ 90.55 USDT'));
        input.value = '';
        await tester.pumpAndSettle();
        expect(line(tester, 'buy'), endsWith('|—'));
        expect(line(tester, 'sell'), endsWith('|—'));
        expect(tester.takeException(), null);
      } finally {
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      }
    });
  }
  testWidgets('narrow Chinese preview keeps the calculation basis readable', (tester) async {
    try {
      await open(tester, locale: 'zh', size: const Size(320, 700), scale: 1.5);
      expect(line(tester, 'sell'), contains('≈ 109.35 USDT'));
      expect(find.textContaining('其他价格和抵押汇率保持当前值'), findsOneWidget);
      expect(tester.takeException(), null);
    } finally {
      await tester.pumpWidget(const SizedBox());
      f.disposeContainer();
    }
  });
}
