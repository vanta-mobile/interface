import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/presentation/live_order_mode_selector.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/trade/presentation/widgets/trade_option_sheet.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/main_order_live_pricing.dart';

Widget _app(Widget child, {String locale = 'en', double scale = 1}) => MaterialApp(
  theme: vantaTheme(),
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  const modes = [
    LiveOrderEntryMode.market,
    LiveOrderEntryMode.limit,
    LiveOrderEntryMode.stopLimit,
    LiveOrderEntryMode.stopMarket,
    LiveOrderEntryMode.trailing,
    LiveOrderEntryMode.postOnly,
    LiveOrderEntryMode.scaled,
  ];
  for (final locale in ['en', 'zh']) {
    for (final size in [const Size(393, 852), const Size(320, 700), const Size(844, 390)]) {
      testWidgets('order sheet selects every supported type at $size in $locale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        var selected = LiveOrderEntryMode.limit;
        var changes = 0;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) => LiveOrderModeSelector(
                selected: selected,
                remembered: LiveOrderEntryMode.stopLimit,
                enabled: true,
                compact: true,
                onSelected: (value) => setState(() {
                  selected = value;
                  changes++;
                }),
              ),
            ),
            locale: locale,
            scale: size.width == 393 ? 1 : 2,
          ),
        );
        for (final mode in modes) {
          await tester.tap(find.byKey(const Key('trade-order-type')));
          await tester.pumpAndSettle();
          final sheet = find.byKey(const Key('order-type-sheet'));
          final rows = tester
              .widgetList<TradeOptionRow<LiveOrderEntryMode>>(
                find.descendant(
                  of: sheet,
                  matching: find.byType(TradeOptionRow<LiveOrderEntryMode>),
                ),
              )
              .toList();
          expect(rows.map((row) => row.option.value), modes);
          expect(rows.singleWhere((row) => row.selected).option.value, selected);
          expect(rows.every((row) => !row.emphasizeSelected), isTrue);
          expect(find.byType(BackdropFilter), findsOneWidget);
          expect(find.byKey(const Key('order-mode-option-twap')), findsNothing);
          expect(find.byKey(const Key('order-mode-option-chase')), findsNothing);
          if (locale == 'en') {
            expect(rows.map((row) => row.option.label), [
              'Market',
              'Limit',
              'Stop Limit',
              'Stop Market',
              'Trailing Stop',
              'Post Only',
              'Scaled Order',
            ]);
          }
          final option = find.byKey(Key('order-mode-option-${mode.name}'));
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
          expect(selected, mode);
          expect(tester.takeException(), isNull);
        }
        expect(changes, 7);
        await tester.tap(find.byKey(const Key('trade-order-type')));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byKey(const Key('order-type-sheet'))));
        await tester.tap(find.byTooltip(l.close));
        await tester.pumpAndSettle();
        expect(changes, 7);
        await tester.tap(find.byKey(const Key('trade-order-type')));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('order-type-sheet')), findsNothing);
        expect(changes, 7);
      });
    }
  }

  testWidgets('disabled order selector cannot open', (tester) async {
    await tester.pumpWidget(
      _app(
        LiveOrderModeSelector(
          selected: LiveOrderEntryMode.limit,
          remembered: LiveOrderEntryMode.stopLimit,
          enabled: false,
          compact: true,
          onSelected: (_) => fail('Disabled selector changed type'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('trade-order-type')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-type-sheet')), findsNothing);
  });

  testWidgets('production embedded form changes mode without submitting', (tester) async {
    final f = MainOrderLiveFixture();
    try {
      await tester.runAsync(f.open);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: _app(const LiveOrderScreen(symbol: 'BTCUSDT', embedded: true)),
        ),
      );
      await tester.pumpAndSettle();
      final reads = (f.orders.reads, f.capacities.reads);
      await tester.tap(find.byKey(const Key('trade-order-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('order-mode-option-postOnly')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector)).selected,
        LiveOrderEntryMode.postOnly,
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
