import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/domain/points.dart';
import 'package:vanta/features/points/presentation/points_page.dart';
import 'package:vanta/features/points/presentation/wallet_points_panel.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/points.dart';
import '../../support/trade_fixture.dart' as app;

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Widget child = const PointsPage(),
    TestPointsRepository? repository,
    TestIdentityRepository? identity,
    String language = 'en',
    double width = 390,
    double height = 844,
    double scale = 1,
    bool settle = true,
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
          home: Scaffold(body: child),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return container;
  }

  Widget scroll(Widget child) => ListView(padding: const EdgeInsets.all(16), children: [child]);
  Future<void> show(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        500,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 100,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await show(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets(
    'removed selected cycle remains selected after refresh and does not substitute another period',
    (tester) async {
      final repository = TestPointsRepository(now: () => now);
      final container = await mount(tester, repository: repository);
      await show(tester, find.byKey(const Key('points-board-select-null')));
      await tester.tap(find.byKey(const Key('points-board-select-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vanta campaign 1').last);
      await tester.pumpAndSettle();
      repository.campaignRows = [];
      await tap(tester, 'points-refresh-cycles');
      expect(find.byKey(const Key('points-board-select-1')), findsOneWidget);
      expect(container.read(pointsLeaderboardProvider(1)).snapshot!.value.campaign, 1);
      expect(repository.calls.where((e) => e == 'board:total').length, 1);
      expect(tester.takeException(), null);
      await close(tester, container);
    },
  );

  testWidgets(
    'missing previously selected history stays unknown instead of zero or accumulated total',
    (tester) async {
      final repository = TestPointsRepository(now: () => now);
      final identity = TestIdentityRepository()..restored = pointsIdentity;
      final container = await mount(
        tester,
        child: scroll(const WalletPointsPanel()),
        repository: repository,
        identity: identity,
      );
      await tap(tester, 'points-read-wallet');
      await show(tester, find.byKey(const Key('points-history-select-null')));
      await tester.tap(find.byKey(const Key('points-history-select-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vanta campaign 1').last);
      await tester.pumpAndSettle();
      repository.historyRows = [];
      await tap(tester, 'points-refresh-history');
      expect(find.byKey(const Key('points-history-select-1')), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('123.000000000000000001'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(tester.takeException(), null);
      await close(tester, container);
    },
  );

  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets('public source, long cycle selector, pagination at $spec / text1.5', (
      tester,
    ) async {
      final repository = TestPointsRepository(now: () => now)
        ..campaignRows = [
          PointsCampaign(
            number: 1,
            name: 'Vanta Genesis Contributors Program — 很长的历史积分周期名称 Season 1 Epoch 16',
            pool: pointsCampaignFixture(1).pool,
            start: now,
            end: now.add(const Duration(days: 7)),
            status: 'ACTIVE',
            current: false,
            broker: 'vanta_exchange',
          ),
        ];
      final container = await mount(
        tester,
        repository: repository,
        width: spec.$1,
        height: spec.$2,
        language: spec.$3,
        scale: 1.5,
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
      expect(find.text(l10n.pointsProgramScope), findsOneWidget);
      await show(tester, find.byKey(const Key('points-board-select-null')));
      await tester.tap(find.byKey(const Key('points-board-select-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(repository.campaignRows!.first.name).last);
      await tester.pumpAndSettle();
      expect(repository.calls, contains('board:1'));
      await tap(tester, 'points-board-next');
      expect(find.text(l10n.pointsPageNumber(2, 2)), findsOneWidget);
      expect(find.text(l10n.pointsRankNumber('21')), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is SelectableText && w.data == pointsTestAddress),
        findsNothing,
      );
      expect(tester.takeException(), null);
      await close(tester, container);
    });
  }
  testWidgets('signed-out wallet shows unknown scores and connect action without personal reads', (
    tester,
  ) async {
    final repository = TestPointsRepository(now: () => now);
    final container = await mount(
      tester,
      child: scroll(const WalletPointsPanel()),
      repository: repository,
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(WalletPointsPanel)));
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text(l10n.pointsWalletRequired), findsOneWidget);
    expect(find.byKey(const Key('points-connect')), findsOneWidget);
    expect(repository.calls, isEmpty);
    await close(tester, container);
  });
  testWidgets(
    'explicit read renders exact scores and history; address switch clears personal values',
    (tester) async {
      final repository = TestPointsRepository(now: () => now);
      final identity = TestIdentityRepository()..restored = pointsIdentity;
      final container = await mount(
        tester,
        child: scroll(const WalletPointsPanel()),
        repository: repository,
        identity: identity,
      );
      expect(repository.calls, ['board:total']);
      expect(find.text('123.000000000000000001'), findsNothing);
      await tap(tester, 'points-read-wallet');
      expect(find.text('123.000000000000000001'), findsNWidgets(2));
      expect(
        find.byWidgetPredicate((w) => w is SelectableText && w.data == pointsTestAddress),
        findsOneWidget,
      );
      await show(tester, find.byKey(const Key('points-history-select-null')));
      await tester.tap(find.byKey(const Key('points-history-select-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vanta campaign 1').last);
      await tester.pumpAndSettle();
      expect(find.text('100'), findsNWidgets(2));
      identity.events.add(
        const AuthIdentity(
          id: 'points-test',
          walletAddress: '0x2222222222222222222222222222222222222222',
          walletKind: WalletKind.external,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('123.000000000000000001'), findsNothing);
      expect(find.byKey(const Key('points-history-select-null')), findsOneWidget);
      expect(repository.calls.where((e) => e.startsWith('wallet:')).length, 1);
      expect(identity.wallets, 0);
      expect(tester.takeException(), null);
      await close(tester, container);
    },
  );
  testWidgets('summary and history failures retain independent values and support safe retry', (
    tester,
  ) async {
    final repository = TestPointsRepository(now: () => now);
    final identity = TestIdentityRepository()..restored = pointsIdentity;
    final container = await mount(
      tester,
      child: scroll(const WalletPointsPanel()),
      repository: repository,
      identity: identity,
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(WalletPointsPanel)));
    await tap(tester, 'points-read-wallet');
    repository.failures['wallet:$pointsTestAddress'] = const PointsFailure('pointsNetwork');
    await tap(tester, 'points-refresh-wallet');
    expect(find.text('123.000000000000000001'), findsNWidgets(2));
    expect(find.text(l10n.pointsNetwork), findsOneWidget);
    expect(container.read(walletPointsHistoryProvider).stale, false);
    repository.failures.clear();
    await tap(tester, 'points-refresh-wallet');
    expect(find.text(l10n.pointsNetwork), findsNothing);
    await close(tester, container);
  });
  testWidgets('empty current cycle and ranking are explicit, no fabricated zero or rank', (
    tester,
  ) async {
    final repository = TestPointsRepository(now: () => now)
      ..noCurrent = true
      ..rowCount = 0;
    final container = await mount(tester, repository: repository);
    final l10n = AppLocalizations.of(tester.element(find.byType(PointsPage)));
    expect(find.text(l10n.pointsNoCurrentCampaign), findsOneWidget);
    await show(tester, find.byKey(const Key('points-board-select-null')));
    expect(find.text(l10n.pointsNoRankings), findsOneWidget);
    expect(find.text(l10n.pointsRankNumber('1')), findsNothing);
    expect(tester.takeException(), null);
    await close(tester, container);
  });
  testWidgets('stopped loading discards late personal result and exposes a retry', (tester) async {
    final repository = TestPointsRepository(now: () => now);
    repository.gates['wallet:$pointsTestAddress'] = Completer();
    final identity = TestIdentityRepository()..restored = pointsIdentity;
    final container = await mount(
      tester,
      child: scroll(const WalletPointsPanel()),
      repository: repository,
      identity: identity,
    );
    await show(tester, find.byKey(const Key('points-read-wallet')));
    await tester.tap(find.byKey(const Key('points-read-wallet')));
    await tester.pump();
    await show(tester, find.byKey(const Key('points-stop-wallet')));
    await tester.tap(find.byKey(const Key('points-stop-wallet')));
    await tester.pump();
    repository.gates.remove('wallet:$pointsTestAddress')!.complete();
    await tester.pumpAndSettle();
    expect(find.text('123.000000000000000001'), findsNothing);
    await tap(tester, 'points-refresh-wallet');
    expect(find.text('123.000000000000000001'), findsNWidgets(2));
    await close(tester, container);
  });
  testWidgets('app Points destination opens real page and disposes readers when leaving', (
    tester,
  ) async {
    final repository = TestPointsRepository();
    final container = app.setup(tester, pointsRepository: repository);
    await app.launch(tester, container);
    expect(repository.calls, isEmpty);
    await tester.tap(find.byIcon(Icons.diamond_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('points-page')), findsOneWidget);
    expect(repository.calls, contains('current'));
    await tester.tap(find.byIcon(Icons.swap_calls_rounded));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.exists(currentPointsCampaignProvider), false);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets('explicit wallet scores survive page scrolling at $spec / text1.5', (tester) async {
      final repository = TestPointsRepository(now: () => now);
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
      await tap(tester, 'points-read-wallet');
      final previous = container.read(walletPointsProvider).snapshot;
      expect(previous, isNotNull);
      await tap(tester, 'points-board-next');
      await show(tester, find.byKey(const Key('points-read-wallet')));
      expect(container.read(walletPointsProvider).snapshot, same(previous));
      expect(find.text('123.000000000000000001'), findsNWidgets(2));
      expect(repository.calls.where((e) => e.startsWith('wallet:')).length, 1);
      expect(tester.takeException(), null);
      await close(tester, container);
    });
  }
}
