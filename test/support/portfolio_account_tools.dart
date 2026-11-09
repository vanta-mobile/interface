import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_account_details.dart';

/// Component tests exercise the retained account tools on their own route.
Future<void> openPortfolioAccountTools(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(Navigator).first))
      .push<void>(MaterialPageRoute(builder: (_) => const PortfolioAccountDetails()));
  await tester.pumpAndSettle();
}
