import 'aster_account.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';

import 'futures_history.dart';
import 'portfolio_account_tools.dart';
import 'identity_repository.dart';
import 'trade_fixture.dart';

Future<ProviderContainer> launchFuturesHistory(
  WidgetTester tester,
  TestFuturesHistoryRepository repository, {
  TestIdentityRepository? identity,
  double width = 390,
  double height = 844,
  double scale = 1,
  String language = 'en',
  bool fromOrders = false,
}) async {
  final auth = identity ?? (TestIdentityRepository()..restored = signingIdentity);
  addTearDown(auth.dispose);
  final container = setup(
    tester,
    identityRepository: auth,
    futuresHistoryRepository: repository,
    futuresHistoryClock: () => futuresHistoryNow,
    width: width,
    scale: scale,
    language: Locale(language),
  );
  tester.view.physicalSize = Size(width, height);
  await launch(tester, container);
  if (!fromOrders) {
    await openPortfolioAccountTools(tester);
  }
  final entry = find.byKey(const Key('open-futures-history'));
  if (entry.evaluate().isEmpty) {
    await tester.scrollUntilVisible(entry, 250, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(entry);
  await tester.pumpAndSettle();
  await tester.tap(entry);
  await tester.pumpAndSettle();
  expect(repository.queries, isEmpty);
  return container;
}

Future<void> revealFutures(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const Key('futures-history-page')),
        matching: find.byType(Scrollable),
      )
      .first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(target, 250, scrollable: scrollable);
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pump();
}

Future<void> tapFutures(WidgetTester tester, String key, {bool settle = true}) async {
  final target = find.byKey(Key(key));
  await revealFutures(tester, target);
  await tester.tap(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> chooseFuturesKind(WidgetTester tester, FuturesHistoryKind kind) =>
    tapFutures(tester, 'futures-history-kind-${kind.name}');

Future<void> setFuturesSymbol(WidgetTester tester, String symbol) async {
  final field = find.byType(TextFormField).first;
  await revealFutures(tester, field);
  await tester.enterText(field, symbol);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> closeFuturesHistory(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}
