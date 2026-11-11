import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/presentation/embedded_time_in_force_selector.dart';
import 'package:vanta/features/portfolio/presentation/live_order_embedded_controls.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/main_order_live_pricing.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    for (final size in [const Size(393, 852), const Size(320, 700), const Size(844, 390)]) {
      testWidgets('design policy sheet selects and cancels at $size in $locale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        var selected = LiveOrderTimeInForce.gtc;
        await tester.pumpWidget(
          MaterialApp(
            theme: vantaTheme(),
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.width == 393 ? 1 : 2)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: size.width == 393 ? 361 : 202,
                  child: StatefulBuilder(
                    builder: (context, setState) => EmbeddedCheckRow(
                      key: const Key('reduce-row'),
                      label: 'Reduce only',
                      value: false,
                      onChanged: (_) {},
                      trailing: EmbeddedTimeInForceSelector(
                        key: const Key('policy'),
                        selected: selected,
                        available: const {LiveOrderTimeInForce.gtc, LiveOrderTimeInForce.ioc},
                        onChanged: (value) => setState(() => selected = value),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final entry = find.byKey(const Key('policy'));
        final caret = find.descendant(of: entry, matching: find.byType(SvgPicture));
        expect(
          tester.getRect(caret).right,
          tester.getRect(find.byKey(const Key('reduce-row'))).right,
        );
        expect(tester.getSize(entry).height, greaterThanOrEqualTo(44));
        await tester.tap(entry);
        await tester.pumpAndSettle();
        final sheet = find.byKey(const Key('time-in-force-sheet'));
        final l = AppLocalizations.of(tester.element(sheet));
        expect(find.text(l.timeInForceTitle), findsOneWidget);
        expect(find.text(l.timeInForceGtc), findsOneWidget);
        expect(find.text(l.timeInForceIoc), findsOneWidget);
        expect(find.textContaining('GTX'), findsNothing);
        expect(find.textContaining('FOK'), findsNothing);
        expect(find.byType(BackdropFilter), findsOneWidget);
        final gtc = tester.widget<Text>(find.text(l.timeInForceGtc));
        expect(gtc.style!.fontWeight, FontWeight.w700);
        await tester.ensureVisible(find.text(l.timeInForceIoc));
        await tester.tap(find.text(l.timeInForceIoc));
        await tester.pumpAndSettle();
        expect(selected, LiveOrderTimeInForce.ioc);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.text(l.timeInForceIoc)).style!.fontWeight, FontWeight.w700);
        await tester.tap(find.byTooltip(l.close));
        await tester.pumpAndSettle();
        expect(selected, LiveOrderTimeInForce.ioc);
        expect(sheet, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('advanced form changes GTC to IOC without reading or submitting', (tester) async {
    final f = MainOrderLiveFixture();
    try {
      await tester.runAsync(f.open);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: MaterialApp(
            theme: vantaTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: LiveOrderScreen(symbol: 'BTCUSDT', embedded: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('live-order-advanced')));
      await tester.pumpAndSettle();
      final reads = (f.orders.reads, f.capacities.reads);
      await tester.ensureVisible(find.byKey(const Key('live-order-policy')));
      await tester.tap(find.byKey(const Key('live-order-policy')));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byKey(const Key('time-in-force-sheet'))));
      await tester.tap(find.text(l.timeInForceIoc));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EmbeddedTimeInForceSelector>(find.byKey(const Key('live-order-policy')))
            .selected,
        LiveOrderTimeInForce.ioc,
      );
      expect((f.orders.reads, f.capacities.reads), reads);
      expect(f.orders.submits, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await f.close();
    }
  });
}
