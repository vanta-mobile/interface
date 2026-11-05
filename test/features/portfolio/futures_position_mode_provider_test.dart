import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/futures_position_mode_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/futures_position_mode.dart';
import '../../support/position_risk.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestFuturesPositionModeRepository repository;
  late DateTime now;
  setUp(() async {
    now = positionModeClock;
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestFuturesPositionModeRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        futuresPositionModeRepositoryProvider.overrideWithValue(repository),
        futuresPositionModeClockProvider.overrideWithValue(() => now),
        positionRiskRepositoryProvider.overrideWithValue(TestPositionRiskRepository()),
      ],
    );
    container.read(authProvider);
    container.read(futuresPositionModeProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  FuturesPositionModeController getController() =>
      container.read(futuresPositionModeProvider.notifier);
  PositionModeIntent getIntent() => getController().prepare(FuturesPositionMode.hedge)!;

  test('no automatic private reads; explicit load binds wallet and account-wide mode', () async {
    expect(repository.reads, 0);
    expect(repository.changes, 0);
    await getController().load();
    expect(
      container.read(futuresPositionModeProvider).context?.current,
      FuturesPositionMode.oneWay,
    );
    expect(getIntent().context.address, accountAddress);
    expect(getController().prepare(FuturesPositionMode.oneWay), null);
  });
  test('stale or 30-second-old configuration cannot produce an intent', () async {
    await getController().load();
    final intent = getIntent();
    now = now.add(const Duration(seconds: 30));
    expect(getController().prepare(FuturesPositionMode.hedge), null);
    await getController().change(intent);
    expect(repository.changes, 0);
  });
  test('account invalidation prevents a previously reviewed change', () async {
    await getController().load();
    final intent = getIntent();
    getController().markStale();
    await getController().change(intent);
    expect(repository.changes, 0);
  });
  test(
    'single confirmed submission; completion invalidates risk and requires another explicit load',
    () async {
      await container.read(positionRiskProvider.notifier).refresh();
      expect(container.read(positionRiskProvider).stale, false);
      await getController().load();
      final intent = getIntent();
      repository.changeGate = Completer<void>();
      final pending = getController().change(intent);
      await getController().change(intent);
      expect(repository.changes, 1);
      repository.changeGate!.complete();
      await pending;
      expect(
        container.read(futuresPositionModeProvider).result?.observed,
        FuturesPositionMode.hedge,
      );
      expect(container.read(positionRiskProvider).stale, true);
      expect(getController().prepare(FuturesPositionMode.hedge), null);
      expect(repository.reads, 1);
    },
  );
  test(
    'unknown result blocks new submits and configuration loads; recheck does not resubmit',
    () async {
      await getController().load();
      repository.result = const PositionModeResult(failure: AccountReadFailure('accountNetwork'));
      await getController().change(getIntent());
      expect(container.read(futuresPositionModeProvider).needsRecheck, true);
      await getController().load();
      expect(repository.reads, 1);
      expect(getController().prepare(FuturesPositionMode.hedge), null);
      repository.result = PositionModeResult(observed: FuturesPositionMode.hedge, checkedAt: now);
      await getController().recheck();
      expect(repository.checks, 1);
      expect(repository.changes, 1);
      expect(container.read(futuresPositionModeProvider).needsRecheck, false);
    },
  );
  test(
    'pre-submit signature refusal is recoverable; post-submit exception remains unknown',
    () async {
      await getController().load();
      repository.submit = false;
      repository.changeFailure = const AccountReadFailure('authWalletRejected');
      await getController().change(getIntent());
      expect(container.read(futuresPositionModeProvider).needsRecheck, false);
      expect(container.read(futuresPositionModeProvider).failure?.key, 'authWalletRejected');
      await getController().load();
      repository.submit = true;
      await getController().change(getIntent());
      expect(container.read(futuresPositionModeProvider).needsRecheck, true);
    },
  );
  test('wallet logout during submit invalidates callback and discards late result', () async {
    await getController().load();
    repository.changeGate = Completer<void>();
    final pending = getController().change(getIntent());
    await container.read(authProvider.notifier).logout();
    expect(repository.latestCurrent!(), false);
    repository.changeGate!.complete();
    await pending;
    expect(container.read(futuresPositionModeProvider).context, null);
    expect(container.read(futuresPositionModeProvider).result, null);
    expect(identity.wallets, 0);
  });
  test('account settings reload invalidates a previous confirmation', () async {
    await getController().load();
    final intent = getIntent();
    await getController().load();
    await getController().change(intent);
    expect(repository.changes, 0);
    expect(container.read(futuresPositionModeProvider).context?.address, accountAddress);
  });
  test('mismatched context fails without preparing a change; failed refresh preserves old context as stale', () async {
    await getController().load();
    final context = container.read(futuresPositionModeProvider).context;
    repository.context = positionModeContext(address: '0x3333333333333333333333333333333333333333');
    await getController().load();
    final state = container.read(futuresPositionModeProvider);
    expect(state.context, same(context));
    expect(state.stale, true);
    expect(state.failure?.key, 'accountDataInvalid');
    expect(getController().prepare(FuturesPositionMode.hedge), null);
  });
  test('invalidation while reading leaves the returned settings stale', () async {
    repository.readGate = Completer<void>();
    final pending = getController().load();
    getController().markStale();
    repository.readGate!.complete();
    await pending;
    expect(container.read(futuresPositionModeProvider).stale, true);
  });

  test(
    'a held position or open orders blocks review until a new explicit read clears it',
    () async {
      for (final context in [
        positionModeContext(hasPosition: true),
        positionModeContext(orders: 1),
      ]) {
        repository.context = context;
        await getController().load();
        expect(getController().prepare(FuturesPositionMode.hedge), null);
      }
      repository.context = positionModeContext();
      await getController().load();
      expect(getIntent().target, FuturesPositionMode.hedge);
    },
  );

  test('time spent reading the remaining snapshots consumes the configuration lease', () async {
    repository.readGate = Completer<void>();
    final pending = getController().load();
    now = now.add(const Duration(seconds: 31));
    repository.readGate!.complete();
    await pending;
    expect(container.read(futuresPositionModeProvider).stale, true);
    expect(getController().prepare(FuturesPositionMode.hedge), null);
  });
}
