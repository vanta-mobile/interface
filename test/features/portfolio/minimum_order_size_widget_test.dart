import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/main_order_live_pricing.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    for (final width in [320.0, 430.0]) {
      testWidgets('Min placeholder follows unit, price and preserves typed input: $locale $width', (
        tester,
      ) async {
        final f = MainOrderLiveFixture();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(f.close);
        await tester.runAsync(f.open);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: f.container,
            child: MaterialApp(
              theme: vantaTheme(),
              locale: Locale(locale),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: LiveOrderScreen(symbol: 'BTCUSDT'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('live-order-quantity'));
        String? hint() => tester.widget<TextField>(field).decoration!.hintText;
        expect(hint(), ''); // Missing limit price cannot produce a quote threshold.
        await tester.enterText(find.byKey(const Key('live-order-price')), '100');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(hint(), 'Min 5');
        expect(find.text('USDT'), findsWidgets);
        await tester.ensureVisible(field);
        await tester.enterText(field, '10');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('live-order-unit')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('BTC').last);
        await tester.pumpAndSettle();
        expect(hint(), 'Min 0.05');
        expect(tester.widget<TextField>(field).controller!.text, '');
        // Each unit retains its independent input; the hint never fills it.
        await tester.enterText(field, '');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('Min 0.05'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('live-order-price')), '100.1');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('live-order-unit')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('USDT').last);
        await tester.pumpAndSettle();
        expect(hint(), 'Min 5.005');
        expect(tester.widget<TextField>(field).controller!.text, '10');
        await tester.enterText(field, '');
        await tester.pumpAndSettle();
        expect(find.text('Min 5.005'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
      });
    }
  }
}
