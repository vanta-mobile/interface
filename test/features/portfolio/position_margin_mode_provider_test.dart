import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/position_margin_mode_provider.dart';
import 'package:vanta/features/portfolio/application/position_risk_provider.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/position_margin_mode.dart';
import '../../support/position_risk.dart';
import '../../support/identity_repository.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestPositionMarginModeRepository repository;
  late DateTime now;
  setUp(() async {
    now = marginModeClock;
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestPositionMarginModeRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        positionMarginModeRepositoryProvider.overrideWithValue(repository),
        positionMarginModeClockProvider.overrideWithValue(() => now),
        positionRiskRepositoryProvider.overrideWithValue(TestPositionRiskRepository()),
      ],
    );
    container.read(authProvider);
    container.read(positionMarginModeProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  PositionMarginModeController getController() =>
      container.read(positionMarginModeProvider.notifier);
  MarginModeIntent getIntent() => getController().prepare('BTCUSDT', PositionMarginMode.isolated)!;

  test('no automatic private reads; explicit load binds symbol, wallet and margin modes', () async {
    expect(repository.reads, 0);
    expect(repository.changes, 0);
    await getController().load('BTCUSDT');
    expect(container.read(positionMarginModeProvider).context?.current, PositionMarginMode.cross);
    expect(getIntent().context.address, accountAddress);
    expect(getController().prepare('ETHUSDT', PositionMarginMode.isolated), null);
    expect(getController().prepare('BTCUSDT', PositionMarginMode.cross), null);
  });
  test('stale or 30-second-old configuration cannot produce an intent', () async {
    await getController().load('BTCUSDT');
    final intent = getIntent();
    now = now.add(const Duration(seconds: 30));
    expect(getController().prepare('BTCUSDT', PositionMarginMode.isolated), null);
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
      expect(
        container.read(positionMarginModeProvider).result?.observed,
        PositionMarginMode.isolated,
      );
      expect(container.read(positionRiskProvider).stale, true);
      expect(getController().prepare('BTCUSDT', PositionMarginMode.isolated), null);
      expect(repository.reads, 1);
    },
  );
  test('unknown result blocks new submits and symbol loads; recheck does not resubmit', () async {
    await getController().load('BTCUSDT');
    repository.result = const MarginModeResult(failure: AccountReadFailure('accountNetwork'));
    await getController().change(getIntent());
    expect(container.read(positionMarginModeProvider).needsRecheck, true);
    await getController().load('ETHUSDT');
    expect(repository.reads, 1);
    expect(getController().prepare('BTCUSDT', PositionMarginMode.isolated), null);
    repository.result = MarginModeResult(observed: PositionMarginMode.isolated, checkedAt: now);
    await getController().recheck();
    expect(repository.checks, 1);
    expect(repository.changes, 1);
    expect(container.read(positionMarginModeProvider).needsRecheck, false);
  });
  test(
    'pre-submit signature refusal is recoverable; post-submit exception remains unknown',
    () async {
      await getController().load('BTCUSDT');
      repository.submit = false;
      repository.changeFailure = const AccountReadFailure('authWalletRejected');
      await getController().change(getIntent());
      expect(container.read(positionMarginModeProvider).needsRecheck, false);
      expect(container.read(positionMarginModeProvider).failure?.key, 'authWalletRejected');
      await getController().load('BTCUSDT');
      repository.submit = true;
      await getController().change(getIntent());
      expect(container.read(positionMarginModeProvider).needsRecheck, true);
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
    expect(container.read(positionMarginModeProvider).context, null);
    expect(container.read(positionMarginModeProvider).result, null);
    expect(identity.wallets, 0);
  });
  test('symbol reload invalidates a previous confirmation', () async {
    await getController().load('BTCUSDT');
    final intent = getIntent();
    await getController().load('ETHUSDT');
    await getController().change(intent);
    expect(repository.changes, 0);
    expect(container.read(positionMarginModeProvider).context?.symbol, 'ETHUSDT');
  });
  test('mismatched context fails without preparing a change; failed refresh preserves old context as stale', () async {
    await getController().load('BTCUSDT');
    final context = container.read(positionMarginModeProvider).context;
    repository.context = marginModeContext(symbol: 'ETHUSDT');
    await getController().load('BTCUSDT');
    final state = container.read(positionMarginModeProvider);
    expect(state.context, same(context));
    expect(state.stale, true);
    expect(state.failure?.key, 'accountDataInvalid');
    expect(getController().prepare('BTCUSDT', PositionMarginMode.isolated), null);
  });
  test('invalidation while reading leaves the returned settings stale', () async {
    repository.readGate = Completer<void>();
    final pending = getController().load('BTCUSDT');
    getController().markStale();
    repository.readGate!.complete();
    await pending;
    expect(container.read(positionMarginModeProvider).stale, true);
  });

  test(
    'a held position or open orders blocks review until a new explicit read clears it',
    () async {
      for (final context in [marginModeContext(hasPosition: true), marginModeContext(orders: 1)]) {
        repository.context = context;
        await getController().load('BTCUSDT');
        expect(getController().prepare('BTCUSDT', PositionMarginMode.isolated), null);
      }
      repository.context = marginModeContext();
      await getController().load('BTCUSDT');
      expect(getIntent().target, PositionMarginMode.isolated);
    },
  );

  test('time spent reading the second snapshot consumes the configuration lease', () async {
    repository.readGate = Completer<void>();
    final pending = getController().load('BTCUSDT');
    now = now.add(const Duration(seconds: 31));
    repository.readGate!.complete();
    await pending;
    expect(container.read(positionMarginModeProvider).stale, true);
    expect(getController().prepare('BTCUSDT', PositionMarginMode.isolated), null);
  });
}
