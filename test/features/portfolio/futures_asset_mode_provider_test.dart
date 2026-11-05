import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/futures_asset_mode_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/futures_asset_mode.dart';
import '../../support/position_risk.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestFuturesAssetModeRepository repository;
  late DateTime now;
  setUp(() async {
    now = assetModeClock;
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestFuturesAssetModeRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        futuresAssetModeRepositoryProvider.overrideWithValue(repository),
        futuresAssetModeClockProvider.overrideWithValue(() => now),
        positionRiskRepositoryProvider.overrideWithValue(TestPositionRiskRepository()),
      ],
    );
    container.read(authProvider);
    container.read(futuresAssetModeProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  FuturesAssetModeController getController() => container.read(futuresAssetModeProvider.notifier);
  AssetModeIntent getIntent() => getController().prepare(FuturesAssetMode.multi)!;

  test('no automatic private reads; explicit load binds wallet and account-wide mode', () async {
    expect(repository.reads, 0);
    expect(repository.changes, 0);
    await getController().load();
    expect(container.read(futuresAssetModeProvider).context?.current, FuturesAssetMode.single);
    expect(getIntent().context.address, accountAddress);
    expect(getController().prepare(FuturesAssetMode.single), null);
  });
  test('stale or 30-second-old configuration cannot produce an intent', () async {
    await getController().load();
    final intent = getIntent();
    now = now.add(const Duration(seconds: 30));
    expect(getController().prepare(FuturesAssetMode.multi), null);
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
      expect(container.read(futuresAssetModeProvider).result?.observed, FuturesAssetMode.multi);
      expect(container.read(positionRiskProvider).stale, true);
      expect(getController().prepare(FuturesAssetMode.multi), null);
      expect(repository.reads, 1);
    },
  );
  test(
    'unknown result blocks new submits and configuration loads; recheck does not resubmit',
    () async {
      await getController().load();
      repository.result = const AssetModeResult(failure: AccountReadFailure('accountNetwork'));
      await getController().change(getIntent());
      expect(container.read(futuresAssetModeProvider).needsRecheck, true);
      await getController().load();
      expect(repository.reads, 1);
      expect(getController().prepare(FuturesAssetMode.multi), null);
      repository.result = AssetModeResult(observed: FuturesAssetMode.multi, checkedAt: now);
      await getController().recheck();
      expect(repository.checks, 1);
      expect(repository.changes, 1);
      expect(container.read(futuresAssetModeProvider).needsRecheck, false);
    },
  );
  test(
    'pre-submit signature refusal is recoverable; post-submit exception remains unknown',
    () async {
      await getController().load();
      repository.submit = false;
      repository.changeFailure = const AccountReadFailure('authWalletRejected');
      await getController().change(getIntent());
      expect(container.read(futuresAssetModeProvider).needsRecheck, false);
      expect(container.read(futuresAssetModeProvider).failure?.key, 'authWalletRejected');
      await getController().load();
      repository.submit = true;
      await getController().change(getIntent());
      expect(container.read(futuresAssetModeProvider).needsRecheck, true);
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
    expect(container.read(futuresAssetModeProvider).context, null);
    expect(container.read(futuresAssetModeProvider).result, null);
    expect(identity.wallets, 0);
  });
  test('account settings reload invalidates a previous confirmation', () async {
    await getController().load();
    final intent = getIntent();
    await getController().load();
    await getController().change(intent);
    expect(repository.changes, 0);
    expect(container.read(futuresAssetModeProvider).context?.address, accountAddress);
  });
  test('mismatched context fails without preparing a change; failed refresh preserves old context as stale', () async {
    await getController().load();
    final context = container.read(futuresAssetModeProvider).context;
    repository.context = assetModeContext(address: '0x3333333333333333333333333333333333333333');
    await getController().load();
    final state = container.read(futuresAssetModeProvider);
    expect(state.context, same(context));
    expect(state.stale, true);
    expect(state.failure?.key, 'accountDataInvalid');
    expect(getController().prepare(FuturesAssetMode.multi), null);
  });
  test('invalidation while reading leaves the returned settings stale', () async {
    repository.readGate = Completer<void>();
    final pending = getController().load();
    getController().markStale();
    repository.readGate!.complete();
    await pending;
    expect(container.read(futuresAssetModeProvider).stale, true);
  });

  test('isolated positions in any symbol block multi-assets review until a new explicit read clears it', () async {
    for (final context in [
      assetModeContext(isolatedSymbols: ['BTCUSDT']),
      assetModeContext(isolatedSymbols: ['ETHUSDT']),
    ]) {
      repository.context = context;
      await getController().load();
      expect(getController().prepare(FuturesAssetMode.multi), null);
    }
    repository.context = assetModeContext();
    await getController().load();
    expect(getIntent().target, FuturesAssetMode.multi);
  });

  test('time spent reading the remaining snapshots consumes the configuration lease', () async {
    repository.readGate = Completer<void>();
    final pending = getController().load();
    now = now.add(const Duration(seconds: 31));
    repository.readGate!.complete();
    await pending;
    expect(container.read(futuresAssetModeProvider).stale, true);
    expect(getController().prepare(FuturesAssetMode.multi), null);
  });
  test(
    'isolated exposure blocks enabling multi, but single target uses exchange eligibility',
    () async {
      repository.context = assetModeContext(
        current: FuturesAssetMode.multi,
        isolatedSymbols: ['ETHUSDT'],
      );
      await getController().load();
      expect(getController().prepare(FuturesAssetMode.single), isNotNull);
      expect(getController().prepare(FuturesAssetMode.multi), null);
    },
  );
}
