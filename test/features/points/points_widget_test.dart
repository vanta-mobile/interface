import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/motion/animated_number_text.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/domain/points.dart';
import 'package:vanta/features/points/presentation/points_page.dart';
import 'package:vanta/features/points/presentation/total_leaderboard_page.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/points.dart';
import '../../support/trade_fixture.dart' as app;
import '../../support/navigation_fixture.dart' show tapNavigationControl;

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    TestPointsRepository? repository,
    TestIdentityRepository? identity,
    String language = 'en',
    double width = 390,
    double height = 844,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = identity ?? TestIdentityRepository();
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [
        pointsClockProvider.overrideWithValue(() => now),
        pointsRepositoryProvider.overrideWithValue(
          repository ?? TestPointsRepository(now: () => now),
        ),
        identityRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: PointsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> show(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await show(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String number(WidgetTester tester, String key) =>
      tester.widget<AnimatedNumberText>(find.byKey(Key(key))).value;
  String metric(WidgetTester tester, String key) => tester
      .widget<AnimatedNumberText>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(AnimatedNumberText)).first,
      )
      .value;

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('signed out shows unknown personal points, login entry and the current period', (
    tester,
  ) async {
    final repository = TestPointsRepository(now: () => now);
    final container = await mount(tester, repository: repository);
    final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
    expect(number(tester, 'points-total'), '—');
    expect(find.byKey(const Key('points-login')), findsOneWidget);
    expect(find.textContaining(l10n.pointsLoginHint), findsOneWidget);
    expect(find.text('Vanta campaign 17'), findsWidgets);
    expect(find.text(l10n.pointsStatusActive), findsOneWidget);
    expect(find.text('29 Oct, 00:00 – 5 Nov, 00:00 · UTC+0'), findsOneWidget);
    expect(metric(tester, 'points-period-card'), '1,000,000');
    expect(metric(tester, 'points-period-mine'), '—');
    expect(repository.calls.where((c) => c.startsWith('wallet:')), isEmpty);
    expect(repository.calls, containsAll(['current', 'cycles', 'board:total', 'board:17']));
    await show(tester, find.byKey(const Key('points-row-1')));
    expect(find.byKey(const Key('points-period-rank')), findsNothing);
    expect(tester.takeException(), null);
    await close(tester, container);
  });

  testWidgets('signed-in wallet loads its points, ranks and highlighted row', (tester) async {
    final repository = TestPointsRepository(now: () => now)
      ..historyRows = [
        WalletCampaignPoints(campaign: 17, points: Decimal.parse('8420.46'), name: 'x'),
      ];
    final identity = TestIdentityRepository()..restored = pointsIdentity;
    final container = await mount(tester, repository: repository, identity: identity);
    final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
    expect(number(tester, 'points-total'), '123');
    expect(find.text('#1'), findsWidgets);
    expect(find.byKey(const Key('points-login')), findsNothing);
    expect(metric(tester, 'points-period-mine'), '8,420.5');
    await show(tester, find.byKey(const Key('points-period-rank')));
    await show(tester, find.byKey(const Key('points-row-1')));
    expect(find.text(l10n.pointsYouSuffix('0x1111…1111')), findsOneWidget);
    expect(identity.wallets, 0);

    identity.events.add(
      const AuthIdentity(
        id: 'points-test',
        walletAddress: '0x2222222222222222222222222222222222222222',
        walletKind: WalletKind.external,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      repository.calls,
      containsAll([
        'wallet:0x2222222222222222222222222222222222222222',
        'history:0x2222222222222222222222222222222222222222',
      ]),
    );
    expect(find.text(l10n.pointsYouSuffix('0x1111…1111')), findsNothing);
    expect(tester.takeException(), null);
    await close(tester, container);
  });

  testWidgets('wallet outside a full top 100 is not reported as unranked', (tester) async {
    final repository = TestPointsRepository(now: () => now)..rowCount = 100;
    final identity = TestIdentityRepository()
      ..restored = const AuthIdentity(
        id: 'outside',
        walletAddress: '0x9999999999999999999999999999999999999999',
        walletKind: WalletKind.external,
      );
    final container = await mount(tester, repository: repository, identity: identity);
    final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
    expect(find.textContaining(l10n.pointsOutsideTop), findsOneWidget);
    expect(find.textContaining(l10n.pointsNotRanked), findsNothing);
    await close(tester, container);
  });

  testWidgets('period sheet switches leaderboard and resets pagination', (tester) async {
    final repository = TestPointsRepository(now: () => now);
    final container = await mount(tester, repository: repository);
    final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
    await tap(tester, 'points-board-next');
    expect(find.text(l10n.pointsPageIndicator(2, 2)), findsOneWidget);
    expect(find.byKey(const Key('points-row-21')), findsOneWidget);
    await tap(tester, 'points-period-selector');
    expect(find.text(l10n.pointsSelectPeriod), findsOneWidget);
    final options = tester
        .widgetList<InkWell>(
          find.byWidgetPredicate(
            (w) => w is InkWell && RegExp(r'points-period-\d').hasMatch('${w.key}'),
          ),
        )
        .map((w) => w.key)
        .toList();
    expect(options, [const Key('points-period-17'), const Key('points-period-1')]);
    await tester.tap(find.byKey(const Key('points-period-1')));
    await tester.pumpAndSettle();
    expect(container.read(pointsPeriodProvider), 1);
    expect(repository.calls, contains('board:1'));
    expect(find.text(l10n.pointsStatusSettled), findsOneWidget);
    expect(find.text(l10n.pointsHistoricalPeriod), findsOneWidget);
    await show(tester, find.byKey(const Key('points-row-1')));
    expect(find.text(l10n.pointsPageIndicator(1, 2)), findsOneWidget);
    expect(tester.takeException(), null);
    await close(tester, container);
  });

  testWidgets('empty ranking shows the design empty state without fabricated rows', (tester) async {
    final repository = TestPointsRepository(now: () => now)..rowCount = 0;
    final container = await mount(tester, repository: repository);
    final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
    await show(tester, find.byKey(const Key('points-board-empty')));
    expect(find.text(l10n.pointsNoRankingsTitle), findsOneWidget);
    expect(find.byKey(const Key('points-row-1')), findsNothing);
    await close(tester, container);
  });

  testWidgets('failed first leaderboard read shows the API cause and retry recovers', (
    tester,
  ) async {
    final repository = TestPointsRepository(now: () => now)
      ..failures['board:17'] = const PointsFailure('pointsNetwork');
    final container = await mount(tester, repository: repository);
    final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
    await show(tester, find.byKey(const Key('points-refresh-board')));
    expect(find.text(l10n.pointsNetwork), findsOneWidget);
    repository.failures.clear();
    await tap(tester, 'points-refresh-board');
    await show(tester, find.byKey(const Key('points-row-1')));
    expect(find.text(l10n.pointsNetwork), findsNothing);
    await close(tester, container);
  });

  testWidgets('pull to refresh waits for every section', (tester) async {
    final repository = TestPointsRepository(now: () => now);
    final identity = TestIdentityRepository()..restored = pointsIdentity;
    final container = await mount(tester, repository: repository, identity: identity);
    repository.calls.clear();
    await container.read(pointsPageRefreshProvider)();
    expect(
      repository.calls,
      unorderedEquals([
        'current',
        'cycles',
        'board:total',
        'board:17',
        'wallet:$pointsTestAddress',
        'history:$pointsTestAddress',
      ]),
    );
    await close(tester, container);
  });

  testWidgets('total leaderboard page shows total and current points', (tester) async {
    final container = await mount(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
    await tap(tester, 'points-view-total');
    expect(find.byType(TotalLeaderboardPage), findsOneWidget);
    expect(find.text(l10n.pointsTotalCurrent), findsOneWidget);
    expect(find.text(l10n.pointsCurrentValue('80')), findsWidgets);
    await tap(tester, 'points-total-back');
    expect(find.byType(TotalLeaderboardPage), findsNothing);
    await close(tester, container);
  });

  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets('layout holds at $spec with text 1.5', (tester) async {
      // Without a current campaign the latest published period is the default.
      final repository = TestPointsRepository(now: () => now)
        ..noCurrent = true
        ..campaignRows = [
          PointsCampaign(
            number: 17,
            name: 'Vanta Genesis Contributors Program — 很长的积分周期名称 (Season 1 Epoch 17)',
            pool: Decimal.fromInt(1000000),
            start: now,
            end: now.add(const Duration(days: 7)),
            status: 'ACTIVE',
            current: true,
            broker: 'vanta_exchange',
          ),
        ];
      final identity = TestIdentityRepository()..restored = pointsIdentity;
      final container = await mount(
        tester,
        repository: repository,
        identity: identity,
        width: spec.$1,
        height: spec.$2,
        language: spec.$3,
        scale: 1.5,
      );
      expect(find.text('Season 1 · Epoch 17'), findsWidgets);
      await tap(tester, 'points-board-next');
      await tap(tester, 'points-view-total');
      expect(tester.takeException(), null);
      await close(tester, container);
    });
  }

  testWidgets('Points tab opens the page and disposes readers when leaving', (tester) async {
    final repository = TestPointsRepository();
    final container = app.setup(tester, pointsRepository: repository);
    await app.launch(tester, container);
    expect(repository.calls, isEmpty);
    await tapNavigationControl(tester, 'navigation-points');
    expect(find.byKey(const Key('points-page')), findsOneWidget);
    expect(repository.calls, contains('current'));
    await tapNavigationControl(tester, 'navigation-futures');
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.exists(currentPointsCampaignProvider), false);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
