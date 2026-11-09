import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/spot_history_provider.dart';
import 'package:vanta/features/portfolio/data/spot_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/spot_history.dart';
import 'package:vanta/features/portfolio/presentation/spot_history_record_card.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/portfolio_account_tools.dart';
import '../../support/identity_repository.dart';
import '../../support/spot_history.dart';
import '../../support/trade_fixture.dart';

Future<void> enterHistory(
  WidgetTester tester, {
  SpotHistoryKind kind = SpotHistoryKind.orders,
}) async {
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  await openPortfolioAccountTools(tester);
  await tester.tap(find.text(l10n.accountSpotTab));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(Key('spot-history-${kind.name}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('spot-history-${kind.name}')));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target, {bool upward = false}) async {
  final scrollable = find
      .descendant(of: find.byKey(const Key('spot-history-page')), matching: find.byType(Scrollable))
      .first;
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, upward ? -200 : 200, scrollable: scrollable);
  }
  await tester.ensureVisible(target);
}

Future<void> read(WidgetTester tester, {bool settle = true}) async {
  await reveal(tester, find.byKey(const Key('read-spot-history')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('read-spot-history')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> close(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}

void main() {
  testWidgets('signed-out history is separate from demo and only read opens login', (tester) async {
    final identity = TestIdentityRepository();
    final repository = TestSpotHistoryRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      spotHistoryRepository: repository,
      historyClock: () => historyNow,
      language: const Locale('en'),
    );
    await launch(tester, container);
    container.read(accountProvider.notifier).connect();
    await enterHistory(tester);
    expect(repository.queries, isEmpty);
    expect(find.byKey(const Key('history-empty')), findsNothing);
    expect(find.text('10000.00'), findsNothing);
    expect(
      find.text('The Spot orders API does not return orders created more than seven days ago.'),
      findsOneWidget,
    );
    await read(tester);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(repository.queries, isEmpty);
    expect(tester.takeException(), null);
    await close(tester, container);
  });

  testWidgets(
    'manual orders retain active and terminal status; failure preserves results and filters',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final query = SpotHistoryQuery(kind: SpotHistoryKind.orders, window: historyWindow);
      final repository = TestSpotHistoryRepository()
        ..records = mapSpotHistory(
          [
            spotOrderRow(),
            spotOrderRow(id: 2, status: 'CANCELED'),
            spotOrderRow(id: 3, status: 'PARTIALLY_FILLED', executed: '1'),
          ],
          address: accountAddress,
          query: query,
          receivedAt: historyNow,
          units: mapSpotSymbolUnits(spotSymbols()),
        ).records;
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        spotHistoryRepository: repository,
        historyClock: () => historyNow,
        language: const Locale('en'),
      );
      await launch(tester, container);
      await enterHistory(tester);
      expect(repository.queries, isEmpty);
      await read(tester);
      expect(repository.queries.length, 1);
      expect(find.byType(SpotHistoryRecordCard), findsNWidgets(3));
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Partially filled'), findsOneWidget);
      expect(find.text('1.100000000000000001 USDT'), findsNWidgets(3));
      repository.failure = const AccountReadFailure('accountPermissionRequired', code: -2015);
      await read(tester);
      expect(find.byType(SpotHistoryRecordCard), findsNWidgets(3));
      expect(find.byKey(const Key('history-snapshot-stale')), findsOneWidget);
      expect(find.textContaining('Aster error code: -2015'), findsOneWidget);
      await reveal(tester, find.byType(TextFormField), upward: true);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), ' BNBUSDT ');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(container.read(spotHistoryProvider).query.scope, 'BNBUSDT');
      expect(find.byType(SpotHistoryRecordCard), findsNothing);
      expect(repository.queries.length, 2);
      expect(tester.takeException(), null);
      await close(tester, container);
    },
  );

  testWidgets('trade and ledger records stay distinct with fees, units and copyable references', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestSpotHistoryRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      spotHistoryRepository: repository,
      historyClock: () => historyNow,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await enterHistory(tester, kind: SpotHistoryKind.trades);
    expect(repository.queries, isEmpty);
    await read(tester);
    expect(find.text('-0.000000000000000001 BNB'), findsOneWidget);
    expect(find.text('Filled quantity'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '1002'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '349661'), findsOneWidget);
    await tester.ensureVisible(find.text('Transaction history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaction history'));
    await tester.pumpAndSettle();
    expect(find.text('Asset (optional)'), findsOneWidget);
    expect(find.byType(SpotHistoryRecordCard), findsNothing);
    expect(repository.queries.length, 1);
    await read(tester);
    expect(find.text('-500.000000000000000001 ASTER'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '1759115482304540227'), findsOneWidget);
    expect(find.text('Trade ID'), findsNothing);
    expect(repository.queries.map((q) => q.kind), [
      SpotHistoryKind.trades,
      SpotHistoryKind.transactions,
    ]);
    expect(tester.takeException(), null);
    await close(tester, container);
  });

  testWidgets(
    'saturation is visible; failed continuation preserves records and retries same window',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestSpotHistoryRepository()..rawCount = 1000;
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        spotHistoryRepository: repository,
        historyClock: () => historyNow,
        language: const Locale('en'),
      );
      await launch(tester, container);
      await enterHistory(tester);
      await read(tester);
      expect(find.textContaining('selected range is not fully checked'), findsOneWidget);
      expect(find.byKey(const Key('continue-spot-history')), findsOneWidget);
      final first = container.read(spotHistoryProvider).account;
      repository.failure = const AccountReadFailure('accountNetwork');
      await tester.ensureVisible(find.byKey(const Key('continue-spot-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continue-spot-history')));
      await tester.pumpAndSettle();
      expect(container.read(spotHistoryProvider).account, same(first));
      expect(find.byType(SpotHistoryRecordCard), findsOneWidget);
      repository.failure = null;
      repository.rawCount = 1;
      await tester.ensureVisible(find.byKey(const Key('continue-spot-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continue-spot-history')));
      await tester.pumpAndSettle();
      expect(repository.queries.length, 3);
      expect(repository.queries[1], repository.queries[2]);
      expect(container.read(spotHistoryProvider).pending.length, 1);
      expect(tester.takeException(), null);
      await close(tester, container);
    },
  );

  testWidgets(
    'display pagination does not sign and language change preserves current page and query',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestSpotHistoryRepository()
        ..records = mapSpotHistory(
          List.generate(21, (i) => spotOrderRow(id: i + 1)),
          address: accountAddress,
          query: SpotHistoryQuery(kind: SpotHistoryKind.orders, window: historyWindow),
          receivedAt: historyNow,
        ).records;
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        spotHistoryRepository: repository,
        historyClock: () => historyNow,
        language: const Locale('en'),
      );
      await launch(tester, container);
      await enterHistory(tester);
      await read(tester);
      expect(find.byType(SpotHistoryRecordCard), findsNWidgets(10));
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.byKey(const Key('history-next')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('history-next')));
        await tester.pumpAndSettle();
      }
      expect(find.byType(SpotHistoryRecordCard), findsOneWidget);
      expect(find.text('Page 3 of 3 loaded pages'), findsOneWidget);
      final query = container.read(spotHistoryProvider).query;
      container.read(localeProvider.notifier).select('zh');
      await tester.pumpAndSettle();
      expect(find.text('已加载记录第3／3页'), findsOneWidget);
      expect(container.read(spotHistoryProvider).query, same(query));
      expect(repository.queries.length, 1);
      expect(tester.takeException(), null);
      await close(tester, container);
    },
  );

  testWidgets('stop and back release pending read and discard late response', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestSpotHistoryRepository()..gate = Completer<void>();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      spotHistoryRepository: repository,
      historyClock: () => historyNow,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await enterHistory(tester);
    await read(tester, settle: false);
    expect(tester.widget<FilledButton>(find.byKey(const Key('read-spot-history'))).onPressed, null);
    await reveal(tester, find.byKey(const Key('stop-spot-history')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('stop-spot-history')));
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SpotHistoryRecordCard), findsNothing);
    expect(find.text('This read was stopped. You can try again.'), findsOneWidget);
    repository.gate = Completer<void>();
    await read(tester, settle: false);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(container.read(spotHistoryProvider).busy, false);
    expect(container.read(spotHistoryProvider).account, null);
    expect(repository.queries.length, 2);
    expect(tester.takeException(), null);
    await close(tester, container);
  });

  for (final variant in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('history fits ${variant.$1}x${variant.$2} ${variant.$4} and clears on logout', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestSpotHistoryRepository()..rawCount = 1000;
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        spotHistoryRepository: repository,
        historyClock: () => historyNow,
        language: Locale(variant.$4),
        width: variant.$1,
        scale: variant.$3,
      );
      tester.view.physicalSize = Size(variant.$1, variant.$2);
      await launch(tester, container);
      await enterHistory(tester, kind: SpotHistoryKind.transactions);
      await read(tester);
      await tester.ensureVisible(find.byType(SpotHistoryRecordCard));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      final snapshot = container.read(spotHistoryProvider).account;
      container.read(localeProvider.notifier).select(variant.$4 == 'en' ? 'zh' : 'en');
      await tester.pumpAndSettle();
      expect(container.read(spotHistoryProvider).account, same(snapshot));
      await tester.pump(const Duration(seconds: 31));
      expect(find.byKey(const Key('history-snapshot-stale')), findsOneWidget);
      identity.events.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-wallet')), findsNothing);
      expect(find.byType(SpotHistoryRecordCard), findsNothing);
      expect(container.read(spotHistoryProvider).query.scope, isEmpty);
      expect(tester.takeException(), null);
      await close(tester, container);
    });
  }

  testWidgets('custom trade dates use UTC calendar days and allow segmented longer history', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestSpotHistoryRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      spotHistoryRepository: repository,
      historyClock: () => historyNow,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await enterHistory(tester, kind: SpotHistoryKind.trades);
    await tester.ensureVisible(find.byKey(const Key('history-dates')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-dates')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(DateRangePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '10/01/2026');
    await tester.enterText(fields.at(1), '11/01/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final range = container.read(spotHistoryProvider).query.window;
    expect(range.start, DateTime.utc(2026, 10, 1).millisecondsSinceEpoch);
    expect(range.end, DateTime.utc(2026, 11, 2).millisecondsSinceEpoch - 1);
    expect(range.fitsRequest, false);
    expect(repository.queries, isEmpty);
    expect(tester.takeException(), null);
    await close(tester, container);
  });
}
