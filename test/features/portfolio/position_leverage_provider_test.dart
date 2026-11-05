import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/position_leverage_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/position_leverage.dart';
import '../../support/position_risk.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestPositionLeverageRepository repository;
  late DateTime now;
  setUp(() async {
    now = leverageClock;
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestPositionLeverageRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        positionLeverageRepositoryProvider.overrideWithValue(repository),
        positionLeverageClockProvider.overrideWithValue(() => now),
        positionRiskRepositoryProvider.overrideWithValue(TestPositionRiskRepository()),
      ],
    );
    container.read(authProvider);
    container.read(positionLeverageProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  PositionLeverageController getController() => container.read(positionLeverageProvider.notifier);
  LeverageIntent getIntent() => getController().prepare('BTCUSDT', '20')!;

  test(
    'no automatic private reads; explicit load binds symbol, wallet and documented limits',
    () async {
      expect(repository.reads, 0);
      expect(repository.changes, 0);
      await getController().load('BTCUSDT');
      expect(container.read(positionLeverageProvider).context?.current, 10);
      expect(getIntent().context.address, accountAddress);
      expect(getController().prepare('ETHUSDT', '20'), null);
      expect(getController().prepare('BTCUSDT', '101'), null);
    },
  );
  test('stale or 30-second-old configuration cannot produce an intent', () async {
    await getController().load('BTCUSDT');
    final intent = getIntent();
    now = now.add(const Duration(seconds: 30));
    expect(getController().prepare('BTCUSDT', '20'), null);
    await getController().change(intent);
    expect(repository.changes, 0);
  });
  test('account invalidation prevents a previously reviewed change', () async {
    await getController().load('BTCUSDT');
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
      await getController().load('BTCUSDT');
      final intent = getIntent();
      repository.changeGate = Completer<void>();
      final pending = getController().change(intent);
      await getController().change(intent);
      expect(repository.changes, 1);
      repository.changeGate!.complete();
      await pending;
      expect(container.read(positionLeverageProvider).result?.observed, 20);
      expect(container.read(positionRiskProvider).stale, true);
      expect(getController().prepare('BTCUSDT', '30'), null);
      expect(repository.reads, 1);
    },
  );
  test('unknown result blocks new submits and symbol loads; recheck does not resubmit', () async {
    await getController().load('BTCUSDT');
    repository.result = const LeverageResult(failure: AccountReadFailure('accountNetwork'));
    await getController().change(getIntent());
    expect(container.read(positionLeverageProvider).needsRecheck, true);
    await getController().load('ETHUSDT');
    expect(repository.reads, 1);
    expect(getController().prepare('BTCUSDT', '30'), null);
    repository.result = LeverageResult(observed: 20, checkedAt: now);
    await getController().recheck();
    expect(repository.checks, 1);
    expect(repository.changes, 1);
    expect(container.read(positionLeverageProvider).needsRecheck, false);
  });
  test(
    'pre-submit signature refusal is recoverable; post-submit exception remains unknown',
    () async {
      await getController().load('BTCUSDT');
      repository.submit = false;
      repository.changeFailure = const AccountReadFailure('authWalletRejected');
      await getController().change(getIntent());
      expect(container.read(positionLeverageProvider).needsRecheck, false);
      expect(container.read(positionLeverageProvider).failure?.key, 'authWalletRejected');
      await getController().load('BTCUSDT');
      repository.submit = true;
      await getController().change(getIntent());
      expect(container.read(positionLeverageProvider).needsRecheck, true);
    },
  );
  test('wallet logout during submit invalidates callback and discards late result', () async {
    await getController().load('BTCUSDT');
    repository.changeGate = Completer<void>();
    final pending = getController().change(getIntent());
    await container.read(authProvider.notifier).logout();
    expect(repository.latestCurrent!(), false);
    repository.changeGate!.complete();
    await pending;
    expect(container.read(positionLeverageProvider).context, null);
    expect(container.read(positionLeverageProvider).result, null);
    expect(identity.wallets, 0);
  });
  test('symbol reload invalidates a previous confirmation', () async {
    await getController().load('BTCUSDT');
    final intent = getIntent();
    await getController().load('ETHUSDT');
    await getController().change(intent);
    expect(repository.changes, 0);
    expect(container.read(positionLeverageProvider).context?.symbol, 'ETHUSDT');
  });
  test('mismatched context fails without preparing a change; failed refresh preserves old context as stale', () async {
    await getController().load('BTCUSDT');
    final context = container.read(positionLeverageProvider).context;
    repository.context = leverageContext(symbol: 'ETHUSDT');
    await getController().load('BTCUSDT');
    final state = container.read(positionLeverageProvider);
    expect(state.context, same(context));
    expect(state.stale, true);
    expect(state.failure?.key, 'accountDataInvalid');
    expect(getController().prepare('BTCUSDT', '20'), null);
  });
  test('invalidation while reading leaves the returned settings stale', () async {
    repository.readGate = Completer<void>();
    final pending = getController().load('BTCUSDT');
    getController().markStale();
    repository.readGate!.complete();
    await pending;
    expect(container.read(positionLeverageProvider).stale, true);
  });
}
