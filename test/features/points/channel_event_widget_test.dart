import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/points/application/event_engagement_provider.dart';
import 'package:vanta/features/points/application/event_media_provider.dart';
import 'package:vanta/features/points/application/event_registration_provider.dart';
import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/application/trading_event_provider.dart';
import 'package:vanta/features/points/domain/event_engagement.dart';
import 'package:vanta/features/points/data/trading_event_mapper.dart';
import 'package:vanta/features/points/domain/event_registration.dart';
import 'package:vanta/features/points/presentation/trading_event_page.dart';
import 'package:vanta/features/points/presentation/trading_events_page.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/channel_events.dart';
import '../../support/identity_repository.dart';
import '../../support/points.dart';
import '../../support/trading_events.dart';

const _identity = AuthIdentity(
  id: 'channel',
  walletAddress: pointsTestAddress,
  walletKind: WalletKind.external,
  signingAvailable: true,
);
void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  late TestPointsRepository points;
  late TestEventEngagementRepository actions;
  late TestIdentityRepository identity;
  late ProviderContainer container;
  late List<Uri> links;
  Future<void> mount(
    WidgetTester tester, {
    Widget home = const TradingEventPage(id: 17),
    String locale = 'en',
    Size size = const Size(390, 844),
    double scale = 1,
    bool authenticated = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    points = TestPointsRepository(now: () => now)
      ..eventValue = channelEventFixture()
      ..channelEventRows = [channelEventFixture()]
      ..registered = true
      ..taskProgress = taskProgressFixture();
    actions = TestEventEngagementRepository();
    identity = TestIdentityRepository()..restored = authenticated ? _identity : null;
    links = [];
    container = ProviderContainer(
      overrides: [
        pointsClockProvider.overrideWithValue(() => now),
        pointsRepositoryProvider.overrideWithValue(points),
        identityRepositoryProvider.overrideWithValue(identity),
        eventRegistrationRepositoryProvider.overrideWithValue(TestEventRegistrationRepository()),
        eventEngagementRepositoryProvider.overrideWithValue(actions),
        eventLinkLauncherProvider.overrideWithValue((u) async {
          links.add(u);
          return true;
        }),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await identity.dispose();
    await tester.pump();
    expect(tester.takeException(), null);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.pumpAndSettle();
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
    }
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> ready(WidgetTester tester) async {
    await container.read(eventParticipantProvider(17).notifier).refresh();
    await tap(tester, 'points-refresh-event-tasks');
  }

  for (final config in [
    (const Size(320, 844), 'en'),
    (const Size(320, 844), 'zh'),
    (const Size(844, 390), 'en'),
    (const Size(768, 1024), 'zh'),
  ]) {
    testWidgets('channel native task presentation ${config.$1}/${config.$2} at text1.5', (
      tester,
    ) async {
      await mount(tester, locale: config.$2, size: config.$1, scale: 1.5);
      try {
        expect(
          points.calls.where((c) => c.startsWith('tasks:') || c.startsWith('participant:')),
          isEmpty,
        );
        await ready(tester);
        expect(find.text('New user tasks'), findsOneWidget);
        expect(find.text('1.000000000000000001 USDC'), findsOneWidget);
        await tap(tester, 'event-wallet-connect');
        expect(find.byKey(const Key('event-engagement-confirm')), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(actions.approvals, isEmpty);
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        expect(actions.approvals, isEmpty);
        await tap(tester, 'event-check-in');
        expect(find.text('2026-11-04 (UTC)'), findsOneWidget);
        await tester.tap(find.byKey(const Key('event-engagement-confirm')));
        await tester.pumpAndSettle();
        expect(actions.approvals.single.action, EventEngagementAction.checkIn);
        expect(identity.wallets, 0);
        expect(tester.takeException(), null);
      } finally {
        await close(tester);
      }
    });
  }
  testWidgets('channel tab reads separate list and opens independently fetched detail', (
    tester,
  ) async {
    await mount(tester, home: const TradingEventsPage());
    try {
      expect(points.calls, ['events']);
      await tap(tester, 'event-type-channel');
      expect(points.calls, ['events', 'channel-events']);
      await tap(tester, 'event-open-17');
      expect(points.calls, contains('event:17'));
      expect(points.calls.where((c) => c.startsWith('tasks:')), isEmpty);
      expect(find.text('Channel task progress'), findsOneWidget);
    } finally {
      await close(tester);
    }
  });
  testWidgets('signed out task progress stays unknown and submission disabled', (tester) async {
    await mount(tester, authenticated: false);
    try {
      final wallet = tester.widget<OutlinedButton>(find.byKey(const Key('event-wallet-connect')));
      expect(wallet.onPressed, null);
      await tap(tester, 'points-refresh-event-tasks');
      expect(points.calls.where((c) => c.startsWith('tasks:')), isEmpty);
      expect(find.text('Connect a wallet to read your points.'), findsNothing);
      expect(actions.approvals, isEmpty);
    } finally {
      await close(tester);
    }
  });
  testWidgets('unknown acknowledged task blocks both buttons until query verifies', (tester) async {
    await mount(tester);
    try {
      await ready(tester);
      actions.result = EventRegistrationPhase.acknowledged;
      actions.clear = false;
      await tap(tester, 'event-wallet-connect');
      await tester.tap(find.byKey(const Key('event-engagement-confirm')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('event-wallet-connect'))).onPressed,
        null,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('event-check-in'))).onPressed,
        null,
      );
      await tap(tester, 'points-refresh-event-tasks');
      expect(actions.approvals.length, 1);
      expect(container.read(eventEngagementProvider(17)).locked, true);
      actions.clear = true;
      await tap(tester, 'points-refresh-event-tasks');
      expect(container.read(eventEngagementProvider(17)).locked, false);
    } finally {
      await close(tester);
    }
  });
  testWidgets('campaign deposit opens Orderly website rather than Aster funding', (tester) async {
    await mount(tester);
    try {
      await ready(tester);
      final f = find.text('Deposit on Vanta website');
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
      expect(links.single.toString(), 'https://app.vanta.exchange/portfolio');
      expect(actions.approvals, isEmpty);
    } finally {
      await close(tester);
    }
  });
  testWidgets('elapsed ACTIVE campaign cannot sign despite server flags', (tester) async {
    await mount(tester);
    try {
      final raw = channelEventPayload()..['endTime'] = '2026-11-03T00:00:00Z';
      points.eventValue = mapTradingEvent({'event': raw}, eventId: 17);
      await container.read(tradingEventProvider(17).notifier).refresh();
      await ready(tester);
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('event-check-in'))).onPressed,
        null,
      );
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('event-wallet-connect'))).onPressed,
        null,
      );
      expect(actions.approvals, isEmpty);
    } finally {
      await close(tester);
    }
  });
  testWidgets('wallet disconnect clears personal task values', (tester) async {
    await mount(tester);
    try {
      await ready(tester);
      expect(find.text('1.000000000000000001 USDC'), findsOneWidget);
      identity.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('1.000000000000000001 USDC'), findsNothing);
      expect(container.read(eventTaskProgressProvider(17)).snapshot, null);
    } finally {
      await close(tester);
    }
  });
}
