import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/trade/presentation/widgets/futures_workspace_tabs.dart';
import 'package:vanta/features/trade/presentation/widgets/market_sheet.dart';

import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';

void main() {
  testWidgets('blank header space neither opens the selector nor keeps the keyboard focus', (
    t,
  ) async {
    final f = NavigationFixture(t, signedIn: false);
    await launch(t, f.container);
    final selector = find.byKey(const Key('trade-market-selector'));
    final symbol = t.getRect(selector);
    final tabs = t.getRect(find.byType(FuturesWorkspaceTabs));
    expect(tabs.left - symbol.right, greaterThan(40)); // the tap area ends at the symbol
    final focus = Focus.of(
      t.element(find.descendant(of: selector, matching: find.byType(Row)).first),
    )..requestFocus();
    await t.pump();
    expect(focus.hasFocus, isTrue);
    await t.tapAt(Offset((symbol.right + tabs.left) / 2, symbol.center.dy));
    await t.pumpAndSettle();
    expect(find.byType(MarketSheet), findsNothing);
    expect(focus.hasFocus, isFalse);
    await t.tap(selector);
    await t.pumpAndSettle();
    expect(find.byType(MarketSheet), findsOneWidget);
    expect(t.takeException(), isNull);
    await f.close(t);
  });
}
