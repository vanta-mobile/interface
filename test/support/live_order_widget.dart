import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Existing scenarios entering coin quantities explicitly choose that unit;
/// the production first-visit default is now the PRD's quote-amount input.
Future<void> selectLiveBase(WidgetTester tester) async {
  final scroll = find
      .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pumpAndSettle();
  final chip = find.byKey(const Key('live-order-unit-base'));
  await tester.scrollUntilVisible(chip, 160, scrollable: scroll);
  await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
  await tester.pumpAndSettle();
  if (!tester.widget<ChoiceChip>(chip).selected) {
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }
}
