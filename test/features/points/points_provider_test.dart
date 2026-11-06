import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/domain/points.dart';

import '../../support/identity_repository.dart';
import '../../support/points.dart';

void main() {
  late DateTime now;
  late TestPointsRepository repository;
  late TestIdentityRepository identity;
  late ProviderContainer container;
  final listeners = <ProviderSubscription<dynamic>>[];
  void watchPublic() {
    listeners.add(container.listen(currentPointsCampaignProvider, (_, _) {}));
    listeners.add(container.listen(pointsCampaignsProvider, (_, _) {}));
    listeners.add(container.listen(pointsLeaderboardProvider(null), (_, _) {}));
  }

  void watchWallet() {
    listeners.add(container.listen(walletPointsProvider, (_, _) {}));
    listeners.add(container.listen(walletPointsHistoryProvider, (_, _) {}));
  }

  Future<void> readWallet() async {
    await Future.wait([
      container.read(walletPointsProvider.notifier).refresh(),
      container.read(walletPointsHistoryProvider.notifier).refresh(),
    ]);
  }

  Future<void> advance(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
    await tester.pump();
  }

  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      now = DateTime.utc(2026, 11, 4, 12);
      repository = TestPointsRepository(now: () => now);
      identity = TestIdentityRepository()..restored = pointsIdentity;
      container = ProviderContainer(
        overrides: [
          pointsClockProvider.overrideWithValue(() => now),
          pointsRepositoryProvider.overrideWithValue(repository),
          identityRepositoryProvider.overrideWithValue(identity),
        ],
      );
      try {
        await body(tester);
      } finally {
        for (final listener in listeners) {
          listener.close();
        }
        listeners.clear();
        container.dispose();
        await identity.dispose();
      }
    });
  }

  scenario('only displayed public readers auto load; personal data is explicit and unsigned', (
    tester,
  ) async {
    await tester.pump();
    expect(repository.calls, isEmpty);
    watchPublic();
    watchWallet();
    await tester.pump();
    expect(repository.calls, ['current', 'cycles', 'board:total']);
    expect(container.read(walletPointsProvider).snapshot, null);
    expect(container.read(walletPointsHistoryProvider).snapshot, null);
    await readWallet();
    expect(repository.calls.skip(3), ['wallet:$pointsTestAddress', 'history:$pointsTestAddress']);
    expect(
      container.read(walletPointsProvider).snapshot!.value.total.toString(),
      '123.000000000000000001',
    );
    expect(identity.wallets, 0);
    expect(identity.externalLogins, 0);
  });
  scenario('public readers share requests; in-flight refreshes deduplicate', (tester) async {
    repository.gates['current'] = Completer();
    listeners.add(container.listen(currentPointsCampaignProvider, (_, _) {}));
    listeners.add(container.listen(currentPointsCampaignProvider, (_, _) {}));
    await tester.pump();
    var completed = false;
    final refresh = container.read(currentPointsCampaignProvider.notifier).refresh()
      ..then((_) => completed = true);
    await tester.pump();
    expect(completed, false);
    expect(repository.calls, ['current']);
    repository.gates.remove('current')!.complete();
    await refresh;
    await tester.pump();
    expect(completed, true);
    expect(container.read(currentPointsCampaignProvider).snapshot!.value!.number, 17);
  });
  scenario('failures remain independent and preserve prior data; explicit retry recovers', (
    tester,
  ) async {
    watchPublic();
    await tester.pump();
    final old = container.read(currentPointsCampaignProvider).snapshot;
    repository.failures['current'] = const PointsFailure('pointsNetwork');
    await container.read(currentPointsCampaignProvider.notifier).refresh();
    expect(container.read(currentPointsCampaignProvider).snapshot, same(old));
    expect(container.read(currentPointsCampaignProvider).stale, true);
    expect(container.read(currentPointsCampaignProvider).failureKey, 'pointsNetwork');
    expect(container.read(pointsCampaignsProvider).stale, false);
    expect(container.read(pointsLeaderboardProvider(null)).failureKey, null);
    repository.failures.clear();
    await container.read(currentPointsCampaignProvider.notifier).refresh();
    expect(container.read(currentPointsCampaignProvider).failureKey, null);
    expect(container.read(currentPointsCampaignProvider).stale, false);
  });
  scenario('expiry occurs after five minutes even while a refresh is pending; no polling', (
    tester,
  ) async {
    watchPublic();
    await tester.pump();
    await advance(tester, const Duration(minutes: 4));
    repository.gates['current'] = Completer();
    final pending = container.read(currentPointsCampaignProvider.notifier).refresh();
    await advance(tester, const Duration(minutes: 1));
    final state = container.read(currentPointsCampaignProvider);
    expect(state.loading, true);
    expect(state.stale, true);
    expect(container.read(pointsCampaignsProvider).stale, true);
    expect(repository.calls, ['current', 'cycles', 'board:total', 'current']);
    repository.gates.remove('current')!.complete();
    await pending;
    expect(container.read(currentPointsCampaignProvider).stale, false);
  });
  scenario('stop rejects late response; manual retry remains available', (tester) async {
    watchPublic();
    await tester.pump();
    final old = container.read(currentPointsCampaignProvider).snapshot;
    repository.gates['current'] = Completer();
    final controller = container.read(currentPointsCampaignProvider.notifier);
    final pending = controller.refresh();
    controller.stop();
    expect(container.read(currentPointsCampaignProvider).loading, false);
    expect(container.read(currentPointsCampaignProvider).stale, true);
    repository.gates.remove('current')!.complete();
    await pending;
    expect(container.read(currentPointsCampaignProvider).snapshot, same(old));
    await controller.refresh();
    expect(container.read(currentPointsCampaignProvider).snapshot, isNot(same(old)));
  });
  scenario('background discards late personal reads; foreground only reloads public data', (
    tester,
  ) async {
    watchPublic();
    watchWallet();
    await tester.pump();
    await readWallet();
    final old = container.read(walletPointsProvider).snapshot;
    repository.gates['wallet:$pointsTestAddress'] = Completer();
    final pending = container.read(walletPointsProvider.notifier).refresh();
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    expect(container.read(walletPointsProvider).active, false);
    repository.gates.remove('wallet:$pointsTestAddress')!.complete();
    await pending;
    expect(container.read(walletPointsProvider).snapshot, same(old));
    final before = repository.calls.length;
    await readWallet();
    await advance(tester, const Duration(minutes: 10));
    expect(repository.calls.length, before);
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pump();
    expect(repository.calls.skip(before), ['current', 'cycles', 'board:total']);
    expect(container.read(walletPointsProvider).stale, true);
  });
  scenario('initial background subscription stays idle until foreground', (tester) async {
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    watchPublic();
    watchWallet();
    await tester.pump();
    expect(repository.calls, isEmpty);
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pump();
    expect(repository.calls, ['current', 'cycles', 'board:total']);
  });
  for (final next in <AuthIdentity?>[
    null,
    const AuthIdentity(
      id: 'other-id',
      walletAddress: pointsTestAddress,
      walletKind: WalletKind.external,
    ),
    const AuthIdentity(
      id: 'points-test',
      walletAddress: '0x2222222222222222222222222222222222222222',
      walletKind: WalletKind.external,
    ),
    const AuthIdentity(
      id: 'points-test',
      walletAddress: pointsTestAddress,
      walletKind: WalletKind.embedded,
    ),
  ]) {
    scenario(
      'identity/address/kind/logout clears personal scope and ignores old result: ${next?.id}/${next?.walletKind}/${next?.walletAddress}',
      (tester) async {
        watchWallet();
        await tester.pump();
        await readWallet();
        repository.gates['wallet:$pointsTestAddress'] = Completer();
        repository.gates['history:$pointsTestAddress'] = Completer();
        final pending = readWallet();
        identity.events.add(next);
        await tester.pump();
        expect(container.read(walletPointsProvider).snapshot, null);
        expect(container.read(walletPointsHistoryProvider).snapshot, null);
        repository.gates.remove('wallet:$pointsTestAddress')!.complete();
        repository.gates.remove('history:$pointsTestAddress')!.complete();
        await pending;
        expect(container.read(walletPointsProvider).snapshot, null);
        expect(container.read(walletPointsHistoryProvider).snapshot, null);
        expect(repository.calls.length, 4);
        expect(identity.wallets, 0);
      },
    );
  }
  scenario(
    'restored EOA read needs no signing capability; signature availability does not clear it',
    (tester) async {
      watchWallet();
      await tester.pump();
      await readWallet();
      final old = container.read(walletPointsProvider).snapshot;
      identity.events.add(
        const AuthIdentity(
          id: 'points-test',
          walletAddress: pointsTestAddress,
          walletKind: WalletKind.external,
          signingAvailable: true,
        ),
      );
      await tester.pump();
      expect(container.read(walletPointsProvider).snapshot, same(old));
      expect(repository.calls.length, 2);
    },
  );
  scenario('signed-out and invalid EVM wallets do not disclose an address or create a wallet', (
    tester,
  ) async {
    identity.restored = null;
    watchWallet();
    await tester.pump();
    await readWallet();
    expect(repository.calls, isEmpty);
    expect(container.read(walletPointsProvider).failureKey, 'pointsWalletRequired');
    identity.restored = const AuthIdentity(
      id: 'solana',
      walletAddress: 'A1111111111111111111111111111111111111111111',
      walletKind: WalletKind.external,
    );
    await container.read(authProvider.notifier).bootstrap();
    await readWallet();
    expect(repository.calls, isEmpty);
    expect(identity.wallets, 0);
  });
  scenario('wrong response address and campaign are rejected rather than crossing scope', (
    tester,
  ) async {
    repository.wrongAddress = true;
    repository.wrongCampaign = 2;
    watchWallet();
    listeners.add(container.listen(pointsLeaderboardProvider(1), (_, _) {}));
    await tester.pump();
    await readWallet();
    expect(container.read(walletPointsProvider).failureKey, 'pointsDataInvalid');
    expect(container.read(walletPointsHistoryProvider).failureKey, 'pointsDataInvalid');
    expect(container.read(pointsLeaderboardProvider(1)).failureKey, 'pointsDataInvalid');
    expect(container.read(walletPointsProvider).snapshot, null);
  });
  scenario('future read times and unexpected exceptions fail without leaking raw errors', (
    tester,
  ) async {
    repository.receivedAt = now.add(const Duration(seconds: 31));
    repository.failures['cycles'] = StateError('sensitive transport data');
    watchPublic();
    await tester.pump();
    expect(container.read(currentPointsCampaignProvider).failureKey, 'pointsDataInvalid');
    expect(container.read(pointsCampaignsProvider).failureKey, 'pointsUnavailable');
    expect(container.read(currentPointsCampaignProvider).snapshot, null);
  });
  scenario('repository lifetime follows active consumers; dispose rejects pending completion', (
    tester,
  ) async {
    container.dispose();
    var closed = 0;
    container = ProviderContainer(
      overrides: [
        pointsRepositoryProvider.overrideWith((ref) {
          ref.onDispose(() => closed++);
          return repository;
        }),
        pointsClockProvider.overrideWithValue(() => now),
      ],
    );
    repository.gates['current'] = Completer();
    final listener = container.listen(currentPointsCampaignProvider, (_, _) {});
    await tester.pump();
    await tester.pump();
    expect(closed, 0);
    listener.close();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(closed, 1);
    repository.gates.remove('current')!.complete();
    await tester.pump();
    expect(tester.takeException(), null);
  });
}
