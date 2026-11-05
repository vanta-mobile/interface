import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/scaled_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import 'trade_fixture.dart';

Future<void> visible(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> tap(WidgetTester tester, String key, {bool settle = true}) async {
  await visible(tester, key);
  await tester.tap(find.byKey(Key(key)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> field(WidgetTester tester, String key, String value) async {
  await visible(tester, key);
  await tester.enterText(find.byKey(Key(key)), value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, ProviderContainer container) async {
  await launch(tester, container);
  openScaledOrder(tester.element(find.byType(Navigator).first), 'BTCUSDT');
  await tester.pumpAndSettle();
  await tap(tester, 'scaled-read');
}

Future<void> fill(WidgetTester tester) async {
  await field(tester, 'scaled-low', '79000');
  await field(tester, 'scaled-high', '81000');
  await tap(tester, 'scaled-unit-base');
  await field(tester, 'scaled-quantity', '0.008');
  await field(tester, 'scaled-count', '3');
}

AppLocalizations messages(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ScaledOrderScreen)));
