import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
import 'package:vanta/features/portfolio/presentation/live_order_mode_selector.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

export 'package:vanta/features/portfolio/domain/live_order_entry_mode.dart';
export 'package:vanta/features/portfolio/presentation/live_order_mode_selector.dart';

Future<void> _show(WidgetTester t, Finder target) async {
  final scroll = find
      .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
      .first;
  t.state<ScrollableState>(scroll).position.jumpTo(0);
  await t.pumpAndSettle();
  await t.scrollUntilVisible(target, 150, scrollable: scroll);
  await Scrollable.ensureVisible(t.element(target), alignment: .5);
  await t.pumpAndSettle();
}

Future<void> chooseOrderMode(WidgetTester t, LiveOrderEntryMode mode) async {
  if (mode == LiveOrderEntryMode.limit || mode == LiveOrderEntryMode.market) {
    final target = find.byKey(Key('order-mode-${mode.name}'));
    await _show(t, target);
    await t.tap(target);
  } else {
    await _show(t, find.byKey(const Key('order-mode-more')));
    await t.tap(find.byKey(const Key('order-mode-more')));
    await t.pumpAndSettle();
    final scroll = find
        .descendant(of: find.byKey(const Key('order-mode-menu')), matching: find.byType(Scrollable))
        .first;
    final option = find.byKey(Key('order-mode-option-${mode.name}'));
    await t.scrollUntilVisible(option, 150, scrollable: scroll);
    await Scrollable.ensureVisible(t.element(option), alignment: .5);
    await t.pumpAndSettle();
    await t.tap(option);
  }
  await t.pumpAndSettle();
}

Future<void> chooseOrderExecution(WidgetTester t, bool market) async {
  final screen = t.widget<LiveOrderScreen>(find.byType(LiveOrderScreen).last);
  if (screen.closingSide == null && !screen.initialConditional) {
    await _show(t, find.byKey(const Key('order-mode-more')));
    final current = t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector)).selected;
    await chooseOrderMode(
      t,
      current.conditional
          ? market
                ? LiveOrderEntryMode.stopMarket
                : LiveOrderEntryMode.stopLimit
          : market
          ? LiveOrderEntryMode.market
          : LiveOrderEntryMode.limit,
    );
    return;
  }
  final target = find.byKey(const Key('live-order-type'));
  await _show(t, target);
  final l = AppLocalizations.of(t.element(target));
  await t.tap(find.descendant(of: target, matching: find.text(market ? l.market : l.limit)));
  await t.pumpAndSettle();
}

/// Follow the replacement opening-mode UI; dedicated closing controls remain.
Future<bool> toggleOrderMode(WidgetTester t, String oldControl) async {
  if (oldControl != 'live-order-conditional' && oldControl != 'live-order-trailing') return false;
  final screen = t.widget<LiveOrderScreen>(find.byType(LiveOrderScreen).last);
  if (screen.closingSide != null || screen.initialConditional) return false;
  await _show(t, find.byKey(const Key('order-mode-more')));
  final current = t.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector)).selected;
  final mode = oldControl == 'live-order-trailing'
      ? current == LiveOrderEntryMode.trailing
            ? LiveOrderEntryMode.market
            : LiveOrderEntryMode.trailing
      : current.conditional
      ? current.marketExecution
            ? LiveOrderEntryMode.market
            : LiveOrderEntryMode.limit
      : current.marketExecution
      ? LiveOrderEntryMode.stopMarket
      : LiveOrderEntryMode.stopLimit;
  await chooseOrderMode(t, mode);
  return true;
}

Future<void> expectOrderModeLocked(WidgetTester t) async {
  await _show(t, find.byKey(const Key('order-mode-more')));
  expect(t.widget<ChoiceChip>(find.byKey(const Key('order-mode-more'))).onSelected, null);
  expect(t.widget<ChoiceChip>(find.byKey(const Key('order-mode-limit'))).onSelected, null);
  expect(t.widget<ChoiceChip>(find.byKey(const Key('order-mode-market'))).onSelected, null);
}
