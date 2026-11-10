import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

/// Exercise the user's tab selection; launch helpers retain the real default.
Future<void> selectWorkspace(WidgetTester tester, {required bool chart}) async {
  final tabs = find.byKey(const Key('trade-workspace-tabs'));
  final l10n = AppLocalizations.of(tester.element(tabs));
  await tester.ensureVisible(tabs);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: tabs,
      matching: find.byTooltip(chart ? l10n.quickOrderChartTab : l10n.trade),
    ),
  );
  await tester.pumpAndSettle();
}
