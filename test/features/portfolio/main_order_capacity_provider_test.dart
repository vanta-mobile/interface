import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';

class ControlledAuth extends AuthController {
  @override
  AuthSession build() => const AuthSession(phase: AuthPhase.signedIn, identity: signingIdentity);
  void change(AuthSession value) => state = value;
}

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestLiveOrderRepository orders;
  late TestCapacityRepository repository;
  late DateTime now;
  setUp(() async {
    now = liveOrderClock;
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestLiveOrderRepository()..context = capacityContext();
    repository = TestCapacityRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        mainOrderCapacityRepositoryProvider.overrideWithValue(repository),
        liveOrderClockProvider.overrideWithValue(() => now),
        authProvider.overrideWith(ControlledAuth.new),
      ],
    );
    container.read(mainOrderCapacityProvider);
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  MainOrderCapacityController controller() => container.read(mainOrderCapacityProvider.notifier);
  MainOrderCapacityState state() => container.read(mainOrderCapacityProvider);
  ControlledAuth auth() => container.read(authProvider.notifier) as ControlledAuth;
  SymbolSettingsActivityController activity() =>
      container.read(symbolSettingsActivityProvider.notifier);

  test('watching does not fetch or prompt; explicit load returns same-context facts', () async {
    expect(repository.reads, 0);
    expect(controller().current, null);
    await controller().load('BTCUSDT');
    expect(repository.reads, 1);
    expect(controller().current!.context, orders.context);
    expect(controller().current!.availableMargin.toString(), '100');
    expect(state().failure, null);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  test('loading holds shared order lease and refuses duplicate reads', () async {
    repository.gate = Completer<void>();
    final future = controller().load('BTCUSDT');
    expect(state().loading, true);
    expect(state().stale, true);
    expect(controller().current, null);
    expect(container.read(symbolSettingsActivityProvider).owner, SymbolSetting.order);
    expect(activity().acquire(SymbolSetting.leverage), null);
    await controller().load('BTCUSDT');
    expect(repository.reads, 1);
    repository.gate!.complete();
    await future;
    expect(controller().current, isNotNull);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  for (final error in [
    const AccountReadFailure('authWalletRejected'),
    StateError('private payload'),
  ]) {
    test(
      'failed refresh preserves previous facts as stale and exposes only safe failure $error',
      () async {
        await controller().load('BTCUSDT');
        final previous = state().snapshot;
        repository.failure = error;
        await controller().load('BTCUSDT');
        expect(state().snapshot, same(previous));
        expect(state().stale, true);
        expect(controller().current, null);
        expect(
          state().failure!.key,
          error is AccountReadFailure ? 'authWalletRejected' : 'accountReadFailed',
        );
        expect(container.read(symbolSettingsActivityProvider).owner, null);
        repository.failure = null;
        await controller().load('BTCUSDT');
        expect(controller().current, isNotNull);
      },
    );
  }
  for (final elapsed in [const Duration(seconds: 30), const Duration(microseconds: -1)]) {
    test('expired or future base context refuses read $elapsed', () async {
      now = now.add(elapsed);
      await controller().load('BTCUSDT');
      expect(repository.reads, 0);
      expect(state().failure!.key, 'liveOrderContextExpired');
      expect(controller().current, null);
    });
    test('clock change invalidates saved snapshot without new request $elapsed', () async {
      await controller().load('BTCUSDT');
      now = now.add(elapsed);
      expect(controller().current, null);
      expect(repository.reads, 1);
    });
    test('clock change during read rejects late success $elapsed', () async {
      repository.gate = Completer<void>();
      final future = controller().load('BTCUSDT');
      now = now.add(elapsed);
      expect(repository.latestCurrent!(), false);
      repository.gate!.complete();
      await future;
      expect(state().snapshot, null);
      expect(state().failure!.key, 'liveOrderContextExpired');
      expect(container.read(symbolSettingsActivityProvider).owner, null);
    });
  }
  test('last microsecond before deadline is current', () async {
    await controller().load('BTCUSDT');
    now = now.add(const Duration(microseconds: 29999999));
    expect(controller().current, isNotNull);
  });
  test(
    'wallet app switch keeps active read within original deadline; idle background invalidates',
    () async {
      repository.gate = Completer<void>();
      final future = controller().load('BTCUSDT');
      container.read(liveOrderProvider.notifier).onLifecycleChanged();
      expect(repository.latestCurrent!(), true);
      repository.gate!.complete();
      await future;
      expect(controller().current, isNotNull);
      container.read(liveOrderProvider.notifier).onLifecycleChanged();
      expect(controller().current, null);
      expect(state().stale, true);
    },
  );
  test('stale live context blocks load and invalidates pending read', () async {
    repository.gate = Completer<void>();
    final future = controller().load('BTCUSDT');
    container.read(liveOrderProvider.notifier).markStale();
    expect(repository.latestCurrent!(), false);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
    repository.gate!.complete();
    await future;
    expect(state().snapshot, null);
    expect(controller().current, null);
    await controller().load('BTCUSDT');
    expect(repository.reads, 1);
  });
  test('new base context clears saved capacity and old read cannot overwrite it', () async {
    repository.gate = Completer<void>();
    final future = controller().load('BTCUSDT');
    controller().stop();
    orders.context = capacityContext();
    await container.read(liveOrderProvider.notifier).load('BTCUSDT');
    expect(repository.latestCurrent!(), false);
    repository.gate!.complete();
    await future;
    expect(state().snapshot, null);
  });
  test('symbol change prevents stale read and old-symbol reload', () async {
    repository.gate = Completer<void>();
    final future = controller().load('BTCUSDT');
    container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(repository.latestCurrent!(), false);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
    repository.gate!.complete();
    await future;
    expect(state().snapshot, null);
    await controller().load('BTCUSDT');
    expect(repository.reads, 1);
  });
  test('mismatched requested symbol does not read', () async {
    await controller().load('ETHUSDT');
    expect(repository.reads, 0);
  });
  for (final changed in [
    const AuthSession(phase: AuthPhase.signedOut),
    const AuthSession(phase: AuthPhase.signedIn, identity: signingIdentity, busy: true),
    const AuthSession(
      phase: AuthPhase.signedIn,
      identity: AuthIdentity(
        id: 'different',
        walletAddress: accountAddress,
        signingAvailable: true,
        walletKind: WalletKind.external,
      ),
    ),
    const AuthSession(
      phase: AuthPhase.signedIn,
      identity: AuthIdentity(
        id: 'aster-test',
        walletAddress: accountAddress,
        signingAvailable: true,
        walletKind: WalletKind.embedded,
      ),
    ),
    const AuthSession(
      phase: AuthPhase.signedIn,
      identity: AuthIdentity(
        id: 'aster-test',
        walletAddress: accountAddress,
        walletKind: WalletKind.external,
      ),
    ),
    const AuthSession(
      phase: AuthPhase.signedIn,
      identity: AuthIdentity(
        id: 'aster-test',
        walletAddress: '0x3333333333333333333333333333333333333333',
        signingAvailable: true,
        walletKind: WalletKind.external,
      ),
    ),
  ].indexed) {
    test('identity or authentication change discards late response ${changed.$1}', () async {
      repository.gate = Completer<void>();
      final future = controller().load('BTCUSDT');
      auth().change(changed.$2);
      expect(repository.latestCurrent!(), false);
      repository.gate!.complete();
      await future;
      expect(state().snapshot, null);
      expect(controller().current, null);
    });
  }
  test('stop invalidates read; late finally cannot release a newer setting lease', () async {
    repository.gate = Completer<void>();
    final future = controller().load('BTCUSDT');
    controller().stop();
    expect(repository.latestCurrent!(), false);
    expect(state().loading, false);
    final newLease = activity().acquire(SymbolSetting.leverage)!;
    repository.gate!.complete();
    await future;
    expect(state().snapshot, null);
    expect(container.read(symbolSettingsActivityProvider).owner, SymbolSetting.leverage);
    expect(container.read(symbolSettingsActivityProvider).busy, true);
    activity().finish(newLease, unresolved: false);
  });
  test('stopped read cannot overwrite a newer successful capacity', () async {
    final gate = repository.gate = Completer<void>();
    final future = controller().load('BTCUSDT');
    controller().stop();
    repository.gate = null;
    await controller().load('BTCUSDT');
    final current = controller().current;
    expect(current, isNotNull);
    gate.complete();
    await future;
    expect(controller().current, same(current));
    expect(repository.reads, 2);
  });
  test('another setting or unresolved operation blocks reading and current capacity', () async {
    await controller().load('BTCUSDT');
    final lease = activity().acquire(SymbolSetting.leverage)!;
    expect(controller().current, null);
    await controller().load('BTCUSDT');
    expect(repository.reads, 1);
    expect(state().failure!.key, 'liveOrderSettingsBusy');
    activity().finish(lease, unresolved: true);
    await controller().load('BTCUSDT');
    expect(repository.reads, 1);
  });
  test('a diagnostic record during a read does not invalidate capacity', () async {
    repository.gate = Completer<void>();
    final future = controller().load('BTCUSDT');
    await container
        .read(orderRecoveryJournalProvider)
        .prepare(OrderRecoveryRecord(query: OrderQuery.capture(liveIntent()), createdAt: now));
    expect(repository.latestCurrent!(), true);
    repository.gate!.complete();
    await future;
    expect(controller().current, isNotNull);
    expect(state().snapshot, isNotNull);
  });
  test('disposed provider rejects late results without throwing', () async {
    repository.gate = Completer<void>();
    final future = controller().load('BTCUSDT');
    container.dispose();
    expect(repository.latestCurrent!(), false);
    repository.gate!.complete();
    await expectLater(future, completes);
    // Avoid disposing the same container twice in tearDown.
    container = ProviderContainer();
  });
  for (final change in ['context', 'address', 'future', 'old', 'accountFuture', 'accountOld']) {
    test('mismatched snapshot metadata is rejected: $change', () async {
      repository.transform = (context) {
        final source = assembledCapacity(context: context);
        final account = source.account;
        return MainOrderCapacitySnapshot(
          context: change == 'context' ? capacityContext() : context,
          account: CapacityAccount(
            address: change == 'address'
                ? '0x3333333333333333333333333333333333333333'
                : account.address,
            receivedAt: change == 'accountFuture'
                ? now.add(const Duration(seconds: 1))
                : change == 'accountOld'
                ? now.subtract(const Duration(seconds: 1))
                : account.receivedAt,
            canTrade: account.canTrade,
            assets: account.assets,
            positions: account.positions,
          ),
          assetMode: source.assetMode,
          availableMargin: source.availableMargin,
          exposure: source.exposure,
          notionalCap: source.notionalCap,
          contractCap: source.contractCap,
          receivedAt: change == 'future'
              ? now.add(const Duration(seconds: 1))
              : change == 'old'
              ? now.subtract(const Duration(seconds: 1))
              : source.receivedAt,
        );
      };
      await controller().load('BTCUSDT');
      expect(state().snapshot, null);
      expect(state().failure!.key, 'accountDataInvalid');
    });
  }
}
