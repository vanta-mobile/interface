import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/points/application/event_media_provider.dart';
import 'package:vanta/features/points/application/event_registration_provider.dart';
import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/data/event_media_service.dart';
import 'package:vanta/features/points/data/trading_event_mapper.dart';
import 'package:vanta/features/points/domain/event_registration.dart';
import 'package:vanta/features/points/domain/points.dart';
import 'package:vanta/features/points/presentation/points_page.dart';
import 'package:vanta/features/points/presentation/trading_event_page.dart';
import 'package:vanta/features/points/presentation/trading_events_page.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/points.dart';
import '../../support/trading_events.dart';

class _Media extends EventMediaService {
  _Media() : super(client: MockClient((_) async => http.Response('', 500)));
  int reads = 0;
  bool fail = true;
  @override
  Future<Uint8List> read(Uri uri) async {
    reads++;
    if (fail) throw const PointsFailure('pointsNetwork');
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
    );
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Widget child = const TradingEventPage(id: 11),
    TestPointsRepository? points,
    TestEventRegistrationRepository? actions,
    TestIdentityRepository? identity,
    String language = 'en',
    double width = 390,
    double height = 844,
    double scale = 1,
    Future<bool> Function(Uri)? launch,
    _Media? media,
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
        pointsRepositoryProvider.overrideWithValue(points ?? TestPointsRepository(now: () => now)),
        eventRegistrationRepositoryProvider.overrideWithValue(
          actions ?? TestEventRegistrationRepository(),
        ),
        identityRepositoryProvider.overrideWithValue(auth),
        eventLinkLauncherProvider.overrideWithValue(launch ?? (_) async => true),
        if (media != null) eventMediaServiceProvider.overrideWithValue(media),
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
          home: child,
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

  TestIdentityRepository signedIn() => TestIdentityRepository()
    ..restored = const AuthIdentity(
      id: 'events',
      walletAddress: pointsTestAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    );
  for (final spec in [
    (320.0, 844.0, 'en'),
    (320.0, 844.0, 'zh'),
    (844.0, 390.0, 'en'),
    (768.0, 1024.0, 'zh'),
  ]) {
    testWidgets('event detail rules/rewards/30-row pagination at $spec text1.5', (tester) async {
      final points = TestPointsRepository(now: () => now);
      final container = await mount(
        tester,
        points: points,
        identity: signedIn(),
        width: spec.$1,
        height: spec.$2,
        language: spec.$3,
        scale: 1.5,
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(TradingEventPage)));
      expect(find.text(l10n.eventsScope), findsOneWidget);
      expect(find.text('243,134,683.03089294'), findsOneWidget);
      expect(find.text('Register before trading.'), findsOneWidget);
      expect(find.text('25,000 USDC'), findsNWidgets(2));
      expect(points.calls, ['event:11', 'event-board:11']);
      await tap(tester, 'points-refresh-event-participant');
      await tap(tester, 'event-register');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(l10n.eventCancel));
      await tester.pumpAndSettle();
      await tap(tester, 'event-rank-next');
      expect(find.text(l10n.pointsPageNumber(2, 3)), findsOneWidget);
      expect(find.text(l10n.pointsRankNumber('11')), findsOneWidget);
      expect(tester.takeException(), null);
      await close(tester, container);
    });
  }
  testWidgets('points entry navigates to real event list and independently fetched detail', (
    tester,
  ) async {
    final points = TestPointsRepository(now: () => now);
    final container = await mount(
      tester,
      child: const Scaffold(body: PointsPage()),
      points: points,
    );
    await tap(tester, 'points-open-events');
    expect(find.byKey(const Key('trading-events-page')), findsOneWidget);
    await tap(tester, 'event-open-11');
    expect(find.byKey(const Key('trading-event-11')), findsOneWidget);
    expect(points.calls, containsAll(['events', 'event:11', 'event-board:11']));
    expect(points.calls.any((c) => c.startsWith('participant:')), false);
    expect(tester.takeException(), null);
    await close(tester, container);
  });
  testWidgets(
    'participant read and registration confirmation are explicit; cancellation never submits',
    (tester) async {
      final points = TestPointsRepository(now: () => now);
      final actions = TestEventRegistrationRepository();
      final identity = signedIn();
      final container = await mount(tester, points: points, actions: actions, identity: identity);
      final l10n = AppLocalizations.of(tester.element(find.byType(TradingEventPage)));
      expect(points.calls.any((c) => c.startsWith('participant:')), false);
      await tap(tester, 'points-refresh-event-participant');
      expect(find.text(l10n.eventNotRegistered), findsOneWidget);
      await tap(tester, 'event-register');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(actions.calls, 0);
      await tester.tap(find.text(l10n.eventCancel));
      await tester.pumpAndSettle();
      expect(actions.calls, 0);
      await tap(tester, 'event-register');
      points.registered = true;
      await tester.tap(find.byKey(const Key('event-register-confirm')));
      await tester.pumpAndSettle();
      expect(actions.calls, 1);
      expect(find.byKey(const Key('event-register')), findsNothing);
      expect(find.text('1,500.000000000000000001'), findsNWidgets(2));
      expect(identity.wallets, 0);
      expect(tester.takeException(), null);
      await close(tester, container);
    },
  );
  testWidgets('wallet replacement during review cannot confirm for the original wallet', (
    tester,
  ) async {
    final identity = signedIn(),
        points = TestPointsRepository(now: () => now),
        actions = TestEventRegistrationRepository();
    final container = await mount(tester, points: points, actions: actions, identity: identity);
    await tap(tester, 'points-refresh-event-participant');
    await tap(tester, 'event-register');
    identity.events.add(
      const AuthIdentity(
        id: 'events',
        walletAddress: '0x2222222222222222222222222222222222222222',
        walletKind: WalletKind.external,
        signingAvailable: true,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('event-register-confirm')));
    await tester.pumpAndSettle();
    expect(actions.calls, 0);
    expect(find.text('1,500.000000000000000001'), findsNothing);
    expect(tester.takeException(), null);
    await close(tester, container);
  });
  testWidgets('unknown registration locks retry until explicit reconciliation', (tester) async {
    final points = TestPointsRepository(now: () => now),
        actions = TestEventRegistrationRepository()
          ..failure = const EventRegistrationFailure('eventRegistrationUnknown', mayHaveSent: true);
    final container = await mount(tester, points: points, actions: actions, identity: signedIn());
    await tap(tester, 'points-refresh-event-participant');
    await tap(tester, 'event-register');
    await tester.tap(find.byKey(const Key('event-register-confirm')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('event-register'))).onPressed, null);
    points.registered = true;
    await tap(tester, 'points-refresh-event-participant');
    expect(actions.calls, 1);
    expect(find.byKey(const Key('event-register')), findsNothing);
    expect(tester.takeException(), null);
    await close(tester, container);
  });
  testWidgets('task link opens its exact Orderly website URL with no Aster navigation', (
    tester,
  ) async {
    final opened = <Uri>[];
    final points = TestPointsRepository(now: () => now)..registered = true;
    final container = await mount(
      tester,
      points: points,
      identity: signedIn(),
      launch: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tap(tester, 'points-refresh-event-participant');
    await show(tester, find.text('Trade Now'));
    await tester.tap(find.text('Trade Now'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://app.vanta.exchange/perp/PERP_BTC_USDC');
    expect(find.byType(TradingEventPage), findsOneWidget);
    await close(tester, container);
  });
  testWidgets('ended campaign never exposes registration or trading task submission', (
    tester,
  ) async {
    final points = TestPointsRepository(now: () => now)
      ..eventValue = tradingEventFixture(status: 'ENDED');
    final actions = TestEventRegistrationRepository();
    final container = await mount(tester, points: points, actions: actions, identity: signedIn());
    await tap(tester, 'points-refresh-event-participant');
    expect(find.byKey(const Key('event-register')), findsNothing);
    expect(find.text('Trade Now'), findsNothing);
    expect(actions.calls, 0);
    await close(tester, container);
  });
  testWidgets('list handles safe failures, retry and explicit empty response', (tester) async {
    final points = TestPointsRepository(now: () => now)
      ..failures['events'] = const PointsFailure('pointsNetwork');
    final container = await mount(tester, points: points, child: const TradingEventsPage());
    final l10n = AppLocalizations.of(tester.element(find.byType(TradingEventsPage)));
    expect(find.text(l10n.pointsNetwork), findsOneWidget);
    points.failures.clear();
    points.eventRows = [];
    await tap(tester, 'points-refresh-events');
    expect(find.text(l10n.eventsEmpty), findsOneWidget);
    expect(find.byKey(const Key('event-open-11')), findsNothing);
    await close(tester, container);
  });
  testWidgets('failed banner remains recoverable independently of event data', (tester) async {
    final media = _Media();
    addTearDown(media.close);
    final points = TestPointsRepository(now: () => now)
      ..eventValue = mapTradingEvent({
        'event': eventPayload()..['headerImageUrl'] = 'https://nltkngcwiuydkpmqrili.supabase.co/storage/v1/object/public/trading-event-content/events/a.png',
      }, eventId: 11);
    final container = await mount(tester, points: points, media: media);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    media.fail = false;
    await show(tester, find.byIcon(Icons.broken_image_outlined));
    await tester.tap(
      find.widgetWithText(
        TextButton,
        AppLocalizations.of(tester.element(find.byType(TradingEventPage))).pointsRefresh,
      ),
    );
    await tester.pumpAndSettle();
    expect(media.reads, 2);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Vanta Trading Carnival 11'), findsOneWidget);
    expect(tester.takeException(), null);
    await close(tester, container);
  });
}
