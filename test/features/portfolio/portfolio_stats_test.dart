import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/application/portfolio_stats_provider.dart';
import 'package:vanta/features/portfolio/data/portfolio_stats_mapper.dart';
import 'package:vanta/features/portfolio/data/portfolio_stats_repository.dart';
import 'package:vanta/features/portfolio/domain/portfolio_stats.dart';

import '../../support/vanta_api.dart';

Decimal d(String value) => Decimal.parse(value);

class ControlledAuth extends AuthController {
  @override
  AuthSession build() => const AuthSession(phase: AuthPhase.signedOut);
  void set(AuthIdentity? identity) => state = identity == null
      ? const AuthSession(phase: AuthPhase.signedOut)
      : AuthSession(phase: AuthPhase.signedIn, identity: identity);
}

AuthIdentity identity(String address, {bool signing = true, String id = 'user-1'}) => AuthIdentity(
  id: id,
  walletAddress: address,
  walletKind: WalletKind.embedded,
  signingAvailable: signing,
);

Map<String, Object?> summary({String? equityStart = '1000', String funding = '-1.5'}) => {
  'account_id': 1,
  'period': '7d',
  'from': '2026-11-06',
  'to': '2026-11-12',
  'equity_start_usd': equityStart,
  'equity_end_usd': '1040',
  'realized_pnl_usd': '50.000000000000000000',
  'fees_usd': '3.5',
  'funding_fee_usd': funding,
  'volume_usd': '12000.25',
  'trades': 4,
  'net_flow_usd': '0',
  'partial': false,
};

void main() {
  group('contract mapping', () {
    test('summary PnL is realized − fees + funding with an exact percentage', () {
      final value = mapPortfolioSummary(summary());
      expect(value.pnl, d('45'));
      expect(value.volume, d('12000.25'));
      expect(value.returnPercent, d('4.5'));
      expect(value.from, DateTime.utc(2026, 11, 6));
      expect(mapPortfolioSummary(summary(equityStart: null)).returnPercent, isNull);
      expect(mapPortfolioSummary(summary(equityStart: '0')).returnPercent, isNull);
    });

    test('malformed amounts reject the payload instead of becoming zero', () {
      for (final bad in [1.5, '1e3', '', null, ' 1']) {
        expect(
          () => mapPortfolioSummary({...summary(), 'fees_usd': bad}),
          throwsFormatException,
          reason: '$bad',
        );
      }
      expect(() => mapPortfolioSummary({...summary(), 'partial': 'no'}), throwsFormatException);
    });

    test('PnL curve is ordered and cumulative; value curve keeps closes', () {
      final pnl = mapPnlCurve({
        'metric': 'pnl',
        'points': [
          {
            'bucket': '2026-11-11T00:00:00Z',
            'realized_pnl_usd': '-2',
            'fees_usd': '1',
            'funding_fee_usd': '0',
          },
          {
            'bucket': '2026-11-10T00:00:00Z',
            'realized_pnl_usd': '10',
            'fees_usd': '0.5',
            'funding_fee_usd': '0.5',
          },
        ],
      });
      expect(pnl.points.map((p) => p.bucket.day), [10, 11]);
      expect(pnl.points.map((p) => p.value), [d('10'), d('7')]);
      expect(() => mapValueCurve({'metric': 'pnl', 'points': <Object?>[]}), throwsFormatException);
      final value = mapValueCurve({
        'metric': 'value',
        'points': [
          {'bucket': '2026-11-10T00:00:00Z', 'equity_close_usd': '100.10'},
        ],
      });
      expect(value.points.single.value, d('100.1'));
    });

    test('calendar contains only reported UTC days', () {
      final month = mapCalendar({
        'items': [
          {
            'day': '2026-11-03',
            'realized_pnl_usd': '4',
            'fees_usd': '1',
            'funding_fee_usd': '0.25',
          },
        ],
      }, month: DateTime.utc(2026, 11));
      expect(month.days, {DateTime.utc(2026, 11, 3): d('3.25')});
      expect(
        () => mapCalendar({'items': 'x'}, month: DateTime.utc(2026, 11)),
        throwsFormatException,
      );
    });
  });

  group('session and statistics providers', () {
    late Backend backend;
    late MemoryStore store;
    late KeySigner signer;
    late ProviderContainer container;
    late ControlledAuth auth;
    final other = '0x${'ab' * 20}';

    setUp(() {
      backend = Backend();
      store = MemoryStore();
      signer = KeySigner();
      backend.routes['GET ${PortfolioStatsRepository.summaryPath}'] = (_) => json(summary());
      backend.routes['GET ${PortfolioStatsRepository.calendarPath}'] = (_) =>
          json({'items': <Object?>[]});
      final repository = vantaTestRepository(
        backend,
        store: store,
        signer: signer,
        now: () => vantaTestNow,
      );
      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => auth = ControlledAuth()),
          vantaApiSessionRepositoryProvider.overrideWithValue(repository),
          vantaApiClockProvider.overrideWithValue(() => vantaTestNow),
        ],
      );
      container.listen(vantaApiSessionProvider, (_, _) {});
      container.read(authProvider);
    });
    tearDown(() => container.dispose());

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await pumpEventQueue();
      }
    }

    test('navigation and refresh never sign; the explicit action loads statistics', () async {
      final views = container.listen(
        portfolioPerformanceProvider(PortfolioStatsPeriod.week),
        (_, _) {},
      );
      auth.set(identity(vantaTestAddress));
      await settle();
      expect(signer.calls, 0);
      expect(views.read().block, PortfolioStatsBlock.signIn);
      await refreshPortfolioStatsForTest(container);
      expect(signer.calls, 0);
      await container.read(vantaApiSessionProvider.notifier).ensure();
      expect(container.read(vantaApiSessionProvider).ready, isTrue);
      expect(signer.calls, 1);
      await settle();
      expect(views.read().performance.pnl, d('45'));
      expect(views.read().performance.volume, d('12000.25'));
      expect(backend.paths.where((p) => p.contains('summary')), hasLength(2));
      expect(
        backend.requests.where((r) => r.url.path.contains('summary')).map((r) => r.url.query),
        unorderedEquals(['period=24h', 'period=7d']),
      );
    });

    test('explicit actions join restoration and share one signature', () async {
      signer.gate = Completer<void>();
      auth.set(identity(vantaTestAddress));
      final first = container.read(vantaApiSessionProvider.notifier).ensure();
      final second = container.read(vantaApiSessionProvider.notifier).ensure();
      await settle();
      expect(signer.calls, 1);
      signer.gate!.complete();
      await Future.wait([first, second]);
      expect(signer.calls, 1);
      expect(container.read(vantaApiSessionProvider).ready, isTrue);
    });

    test('a stored session is restored without asking the wallet', () async {
      store.value = VantaApiCredentials(
        address: vantaTestAddress.toLowerCase(),
        accessToken: 'stored',
        refreshToken: 'stored-refresh',
        accessExpiresAt: vantaTestNow.add(const Duration(hours: 1)),
      );
      auth.set(identity(vantaTestAddress, signing: false));
      await settle();
      expect(container.read(vantaApiSessionProvider).ready, isTrue);
      expect(signer.calls, 0);
    });

    test('a rejected signature is retained and only repeated by the explicit action', () async {
      signer.signature = '0x00';
      auth.set(identity(vantaTestAddress));
      await settle();
      await container.read(vantaApiSessionProvider.notifier).ensure();
      final session = container.read(vantaApiSessionProvider);
      expect(session.status, VantaApiSessionStatus.signedOut);
      expect(session.failure, isA<AuthFailure>());
      expect(
        container.read(portfolioPerformanceProvider(PortfolioStatsPeriod.week)).failure,
        isA<AuthFailure>(),
      );
      auth.set(identity(vantaTestAddress, signing: false));
      await settle();
      expect(container.read(vantaApiSessionProvider).failure, isA<AuthFailure>());
      auth.set(identity(vantaTestAddress));
      await settle();
      await refreshPortfolioStatsForTest(container);
      expect(signer.calls, 1);
      signer.signature = null;
      await container.read(vantaApiSessionProvider.notifier).ensure();
      expect(signer.calls, 2);
      expect(container.read(vantaApiSessionProvider).ready, isTrue);
    });

    test('statistics of the previous wallet disappear on a wallet change', () async {
      final views = container.listen(
        portfolioPerformanceProvider(PortfolioStatsPeriod.week),
        (_, _) {},
      );
      auth.set(identity(vantaTestAddress));
      await settle();
      await container.read(vantaApiSessionProvider.notifier).ensure();
      await settle();
      expect(views.read().performance.pnl, d('45'));
      signer.gate = Completer<void>();
      auth.set(identity(other, id: 'user-2'));
      await settle();
      expect(container.read(vantaApiSessionProvider).status, VantaApiSessionStatus.signedOut);
      expect(views.read().performance.pnl, isNull);
      final signing = container.read(vantaApiSessionProvider.notifier).ensure();
      await settle();
      expect(container.read(vantaApiSessionProvider).status, VantaApiSessionStatus.signing);
      expect(views.read().performance.pnl, isNull);
      // Waiting for the wallet is not loading: the failure state explains it.
      expect(views.read().loading, isFalse);
      expect(views.read().block, PortfolioStatsBlock.signing);
      signer.gate!.complete();
      await signing;
      await settle();
    });

    test('logout revokes the server session and forgets local tokens', () async {
      backend.routes['POST /v1/auth/logout'] = (_) => json({'ok': true});
      auth.set(identity(vantaTestAddress));
      await settle();
      await container.read(vantaApiSessionProvider.notifier).ensure();
      expect(store.value, isNotNull);
      auth.set(null);
      await settle();
      expect(store.value, isNull);
      expect(backend.paths.last, 'POST /v1/auth/logout');
      expect(container.read(vantaApiSessionProvider).status, VantaApiSessionStatus.signedOut);
    });

    test('pull-to-refresh awaits every visible statistics read, including failures', () async {
      auth.set(identity(vantaTestAddress));
      container.listen(portfolioPerformanceProvider(PortfolioStatsPeriod.week), (_, _) {});
      await settle();
      await container.read(vantaApiSessionProvider.notifier).ensure();
      await settle();
      final gate = Completer<void>();
      backend.routes['GET ${PortfolioStatsRepository.summaryPath}'] = (_) async {
        await gate.future;
        return json({'code': 'internal_error', 'message': 'Database unavailable'}, 500);
      };
      var settled = false;
      final refresh = refreshPortfolioStatsForTest(container).then((_) => settled = true);
      await settle();
      expect(settled, isFalse);
      gate.complete();
      await refresh;
      final view = container.read(portfolioPerformanceProvider(PortfolioStatsPeriod.week));
      expect(view.failure, isNotNull);
      // Retained data stays visible after a failed refresh.
      expect(view.performance.pnl, d('45'));
    });

    test('calendar for the current month ends today; past months end on their last day', () async {
      auth.set(identity(vantaTestAddress));
      await settle();
      await container.read(vantaApiSessionProvider.notifier).ensure();
      await container.read(portfolioCalendarProvider(DateTime.utc(2026, 11)).future);
      await container.read(portfolioCalendarProvider(DateTime.utc(2026, 10)).future);
      final queries = backend.requests
          .where((r) => r.url.path == PortfolioStatsRepository.calendarPath)
          .map((r) => r.url.queryParameters)
          .toList();
      expect(queries, [
        {'from': '2026-11-01', 'to': '2026-11-12'},
        {'from': '2026-10-01', 'to': '2026-10-31'},
      ]);
    });
  });
}

final _refresh = Provider<Future<void> Function()>(
  (ref) =>
      () => refreshPortfolioStats(ref),
);
Future<void> refreshPortfolioStatsForTest(ProviderContainer container) =>
    container.read(_refresh)();
