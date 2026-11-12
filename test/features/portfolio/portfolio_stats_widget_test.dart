import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart' show ErrorOpeningWallet;
import 'package:vanta/core/presentation/status_view.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/portfolio_stats_provider.dart';
import 'package:vanta/features/portfolio/domain/portfolio_overview.dart';
import 'package:vanta/features/portfolio/domain/portfolio_stats.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_pnl_screen.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_summary.dart';
import 'package:vanta/features/portfolio/data/portfolio_stats_repository.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/vanta_api.dart';
import '../../support/reown_modal.dart';
import '../../support/wallet_connection.dart';

Decimal d(String value) => Decimal.parse(value);

class _SignedIn extends AuthController {
  @override
  AuthSession build() => AuthSession(
    phase: AuthPhase.signedIn,
    identity: AuthIdentity(id: 'u', walletAddress: vantaTestAddress, signingAvailable: true),
  );
}

final week = PortfolioPerformance(
  pnl: d('45'),
  returnPercent: d('4.5'),
  volume: d('12000.25'),
  todayPnl: d('-3.2'),
  todayPercent: d('-0.31'),
  history: [d('0'), d('12'), d('45')],
  start: DateTime.utc(2026, 11, 6),
  end: DateTime.utc(2026, 11, 12),
);

Widget app(List<dynamic> overrides, Widget child) => ProviderScope(
  key: UniqueKey(),
  overrides: [authProvider.overrideWith(_SignedIn.new), ...overrides.cast()],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  testWidgets('PnL details render the API period, history and calendar', (t) async {
    final month = DateTime.utc(DateTime.now().toUtc().year, DateTime.now().toUtc().month);
    await t.pumpWidget(
      app([
        portfolioPnlPerformanceProvider(PortfolioStatsPeriod.week)
            .overrideWithValue(PortfolioStatsView(week)),
        portfolioCalendarViewProvider(month).overrideWithValue(
          PortfolioStatsView(
            PortfolioPerformance(dailyPnl: {DateTime.utc(month.year, month.month, 1): d('3.25')}),
          ),
        ),
      ], const PortfolioPnlScreen()),
    );
    await t.pumpAndSettle();
    expect(find.text(r'+$45.00'), findsOneWidget);
    expect(find.textContaining('+4.5%'), findsOneWidget);
    expect(find.text(r'$12,000.25'), findsOneWidget);
    expect(find.text('PnL data unavailable for this account'), findsNothing);
    await t.tap(find.byKey(const ValueKey('portfolio-pnl-view-true')));
    await t.pumpAndSettle();
    expect(find.text(r'+$3.25'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a statistics failure shows the server message; loading shows skeletons', (t) async {
    await t.pumpWidget(
      app([
        portfolioPnlPerformanceProvider(PortfolioStatsPeriod.week).overrideWithValue(
          PortfolioStatsView(
            PortfolioPerformance(),
            failure: const VantaApiFailure(vantaApiRequestFailed),
          ),
        ),
      ], const PortfolioPnlScreen()),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('portfolio-stats-failed')), findsNothing);
    expect(find.text('Account statistics could not be loaded. Please retry.'), findsOneWidget);
    await t.pumpWidget(
      app(
        const [],
        Scaffold(
          body: PortfolioPerformanceCard(
            stats: PortfolioStatsView(PortfolioPerformance(), loading: true),
            hidden: false,
          ),
        ),
      ),
    );
    expect(find.text('—'), findsNothing);
    await t.pumpWidget(
      app(
        const [],
        Scaffold(body: PortfolioPerformanceCard(stats: PortfolioStatsView(week), hidden: true)),
      ),
    );
    expect(find.text(r'+$45.00'), findsNothing);
    expect(find.text('••••'), findsNWidgets(3));
  });

  testWidgets('without a session the section shows the failure state, never a skeleton', (t) async {
    final signer = KeySigner()..signature = '0x00';
    final backend = Backend();
    backend.routes['GET ${PortfolioStatsRepository.summaryPath}'] = (_) =>
        json({'code': 'internal_error', 'message': 'x'}, 500);
    backend.routes['GET ${PortfolioStatsRepository.curvePath}'] = (_) =>
        json({'code': 'internal_error', 'message': 'x'}, 500);
    final repository = vantaTestRepository(
      backend,
      store: MemoryStore(),
      signer: signer,
      now: () => vantaTestNow,
    );
    await t.pumpWidget(
      app([
        vantaApiSessionRepositoryProvider.overrideWithValue(repository),
      ], const PortfolioPnlScreen()),
    );
    await t.pumpAndSettle();
    // Opening the page never signs or leaves the failure action spinning.
    expect(signer.calls, 0);
    expect(find.text('Sign'), findsOneWidget);
    expect(find.byKey(const Key('status-action-loading')), findsNothing);
    await t.tap(find.byKey(const Key('portfolio-stats-retry')));
    await t.pumpAndSettle();
    expect(signer.calls, 1);
    expect(find.byKey(const Key('status-action-loading')), findsNothing);
    expect(find.byKey(const ValueKey('portfolio-stats-signIn')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-history-loading')), findsNothing);
    expect(find.text('Wallet signature required'), findsOneWidget);

    // A pending wallet request is shown as waiting, with the action spinning.
    signer
      ..signature = null
      ..gate = Completer<void>();
    await t.tap(find.byKey(const Key('portfolio-stats-retry')));
    await t.pump();
    await t.pump();
    expect(find.byKey(const ValueKey('portfolio-stats-signing')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-history-loading')), findsNothing);
    expect(signer.calls, 2);
    final button = find.descendant(
      of: find.byKey(const Key('portfolio-stats-retry')),
      matching: find.byType(OutlinedButton),
    );
    expect(t.widget<OutlinedButton>(button).onPressed, isNull);

    // Signed, but the reads failed: the failure state keeps the retry.
    signer.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('portfolio-stats-failed')), findsOneWidget);
    expect(find.byKey(const Key('status-action-loading')), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(t.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('Sign handles an SDK launch failure, retries and finishes SIWE once', (t) async {
    final signer = KeySigner()..gate = Completer<void>();
    final modal = TestReownModal()..address = vantaTestAddress;
    modal.onRequest = (request) async {
      final encoded = (request.params as List).first as String;
      final message = utf8.decode([
        for (var i = 2; i < encoded.length; i += 2)
          int.parse(encoded.substring(i, i + 2), radix: 16),
      ]);
      return signer.signPersonalMessage(expectedAddress: vantaTestAddress, message: message);
    };
    final connection = ReownWalletConnection(modal, vantaTestAddress, '56');
    final identity = PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: MemoryWalletPreferences(),
      create: (_) => throw TestFailure('External signing must not initialize Privy'),
    );
    await identity.loginWithWallet(connection);
    final backend = Backend();
    backend.routes['GET ${PortfolioStatsRepository.summaryPath}'] = (_) =>
        json({'code': 'internal_error', 'message': 'Statistics unavailable'}, 500);
    backend.routes['GET ${PortfolioStatsRepository.curvePath}'] = (_) =>
        json({'code': 'internal_error', 'message': 'Statistics unavailable'}, 500);
    final repository = vantaTestRepository(
      backend,
      store: MemoryStore(),
      signer: identity,
      now: () => vantaTestNow,
    );
    addTearDown(() async {
      repository.close();
      await identity.dispose();
      await modal.dispose();
    });
    await t.pumpWidget(
      app([
        vantaApiSessionRepositoryProvider.overrideWithValue(repository),
      ], const PortfolioPnlScreen()),
    );
    await t.pumpAndSettle();
    expect(modal.requests, isEmpty);
    await t.tap(find.byKey(const Key('portfolio-stats-retry')));
    await t.pump();
    await t.pump();
    expect(modal.requests.single.method, 'personal_sign');
    expect(modal.topic, 'topic');
    expect(modal.chain, 'eip155:56');
    expect(signer.calls, 1);
    expect(backend.paths, ['GET /v1/auth/nonce']);
    modal.onModalError.broadcast(ErrorOpeningWallet());
    await t.pumpAndSettle();
    expect(find.byKey(const Key('status-action-loading')), findsNothing);
    expect(find.textContaining('Could not open your connected wallet.'), findsOneWidget);
    expect(find.text('Sign'), findsOneWidget);
    await t.tap(find.byKey(const Key('portfolio-stats-retry')));
    await t.pump();
    await t.pump();
    expect(modal.requests, hasLength(2));
    expect(signer.calls, 2);
    // The original request may answer late, but only the active retry can log in.
    signer.gate!.complete();
    await t.pumpAndSettle();
    expect(backend.paths.where((p) => p == 'POST /v1/auth/siwe'), hasLength(1));
    expect(find.byKey(const Key('status-action-loading')), findsNothing);
    expect(find.byKey(const ValueKey('portfolio-stats-failed')), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await connection.release();
    await t.pump();
  });

  testWidgets('an unconfigured build explains it without a retry', (t) async {
    await t.pumpWidget(
      app([vantaApiSessionRepositoryProvider.overrideWithValue(null)], const PortfolioPnlScreen()),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('portfolio-stats-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-stats-retry')), findsNothing);
  });

  testWidgets('account value omits valuation and statistics diagnostic captions', (t) async {
    await t.pumpWidget(
      app(
        const [],
        Scaffold(
          body: PortfolioAccountValue(
            overview: PortfolioOverview(
              totalUsd: d('100'),
              performance: PortfolioPerformance(),
              partialValue: true,
              staleValue: true,
            ),
            stats: PortfolioStatsView(week, failure: const VantaApiFailure(vantaApiRequestFailed)),
            visible: true,
            active: true,
            historyExpanded: false,
            onToggleVisibility: () {},
            onToggleHistory: () {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final l = AppLocalizations.of(t.element(find.byType(PortfolioAccountValue)));
    expect(find.text(l.assetValueStale), findsNothing);
    expect(find.text(l.assetValueUnavailable), findsNothing);
    expect(find.byKey(const Key('portfolio-stats-error')), findsNothing);
    expect(find.text(r'$100.00'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('card skeletons use the on-card color so they are visible', (t) async {
    await t.pumpWidget(
      app(
        const [],
        Scaffold(
          body: PortfolioPerformanceCard(
            stats: PortfolioStatsView(PortfolioPerformance(), loading: true),
            hidden: false,
          ),
        ),
      ),
    );
    final boxes = t.widgetList<SkeletonBox>(find.byType(SkeletonBox));
    expect(boxes, hasLength(2));
    expect(boxes.map((b) => b.color), everyElement(StatusColors.skeletonOnCard));
    expect(StatusColors.skeletonOnCard, isNot(PortfolioColors.card));
  });
}
