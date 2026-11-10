import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Use the Portfolio connection entry so auth flows do not depend on trading
/// header controls, their placement, or the selected chart / trade workspace.
Future<void> openWalletLogin(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('navigation-portfolio')));
  await tester.pumpAndSettle();
  final connect = find.byKey(const Key('portfolio-login'));
  expect(connect, findsOneWidget);
  await tester.ensureVisible(connect);
  await tester.tap(connect);
  await tester.pumpAndSettle();
}

Future<void> closeWalletLogin(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.pump();
}
