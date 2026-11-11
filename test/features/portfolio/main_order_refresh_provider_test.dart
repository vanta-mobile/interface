import 'package:vanta/features/market/application/market_providers.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/market/domain/order_reference_prices.dart';
import 'package:vanta/features/portfolio/application/account_change_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_pricing_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/account_changes.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_live_pricing.dart';
import '../../support/main_order_revaluation.dart';

void main() {
  late MainOrderLiveFixture f;
  late TestAccountChangeRepository changes;
  setUp(() {
    changes = TestAccountChangeRepository();
    f = MainOrderLiveFixture(changes: changes);
    changes.now = f.now;
  });
  tearDown(() async {
    await f.close();
    await changes.dispose();
  });
  MainOrderRefreshController controller() => f.container.read(mainOrderRefreshProvider.notifier);
  MainOrderRefreshState state() => f.container.read(mainOrderRefreshProvider);

  test('observation never signs; explicit refresh reads context and full capacity once', () async {
    state();
    await f.flush();
    expect(f.orders.reads, 0);
    expect(f.capacities.reads, 0);
    expect(changes.authorizations, 0);
    final result = await controller().refresh('BTCUSDT');
    expect(result, true);
    expect(f.orders.reads, 1);
    expect(f.capacities.reads, 1);
    expect(changes.authorizations, 0);
    expect(changes.channels, isEmpty);
    expect(state().loading, false);
    expect(state().failure, isNull);
    expect(f.container.read(mainOrderCapacityProvider.notifier).current, isNotNull);
    expect(f.orders.submits, 0);
  });
  test(
    'automatic renewal preserves public subscriptions and accepts current fresh quotes',
    () async {
      await f.open();
      f.now = f.now.add(const Duration(seconds: 3));
      f.orders.context = capacityContext(time: f.now);
      // These receipts remain fresh; automatic reads do not force a reconnect.
      final reconnect = f.container.read(quoteReconnectProvider);
      expect(await controller().refresh('BTCUSDT', reconnectPrices: false), true);
      expect(f.container.read(quoteReconnectProvider), reconnect);
      expect(f.container.read(liveOrderProvider).context!.receivedAt, f.now);
      expect(f.container.read(mainOrderCapacityProvider.notifier).current, isNotNull);
      expect(f.orders.reads, 2);
      expect(f.orders.submits, 0);
    },
  );
  test('deposit prerequisite suppresses subsequent account and capacity reads', () async {
    state();
    await f.flush();
    f.orders.readFailure = const AccountReadFailure('accountDepositRequired', code: -5050);
    expect(await controller().refresh('BTCUSDT'), false);
    expect(f.orders.reads, 1);
    expect(f.capacities.reads, 0);
    expect(state().failure?.requiresDeposit, true);
    expect(await controller().refresh('BTCUSDT'), false);
    f.container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(await controller().refresh('ETHUSDT'), false);
    expect(f.orders.reads, 1);
    expect(f.capacities.reads, 0);
  });
  test('public quote recovery clears a pricing failure without another account read', () async {
    await f.open();
    f.quotes['BTCUSDT']!.emit(
      OrderReferencePrices(
        symbol: 'BTCUSDT',
        checkedAt: f.now,
        connection: OrderPriceConnection.online,
        tradeFailed: true,
        tradeFailure: const AccountReadFailure(
          'liveCapacityPriceUnavailable',
          reasonKey: 'livePriceLastStale',
        ),
      ),
    );
    await f.flush();
    expect(await controller().refresh('BTCUSDT', reconnectPrices: false), isFalse);
    expect(state().failure?.reasonKey, 'livePriceLastStale');
    final accountReads = f.orders.reads, capacityReads = f.capacities.reads;
    // A partial recovery must not claim the full pricing scope is ready.
    f.quotes['BTCUSDT']!.emit(
      OrderReferencePrices(
        symbol: 'BTCUSDT',
        checkedAt: f.now,
        connection: OrderPriceConnection.online,
        trade: revaluationReference(time: f.now).trade,
        tradeFresh: true,
      ),
    );
    await f.flush();
    expect(state().failure, isNotNull);
    f.prices();
    await f.flush();
    expect(state().failure, isNull);
    expect(state().loading, isFalse);
    expect(f.orders.reads, accountReads);
    expect(f.capacities.reads, capacityReads);
    expect(f.orders.submits, 0);
  });

  test('public quote recovery does not clear an account read failure', () async {
    await f.open();
    const failure = AccountReadFailure(
      'accountReadFailed',
      details: ApiErrorDetails(message: 'Account service unavailable', status: 503),
    );
    f.orders.readFailure = failure;
    expect(await controller().refresh('BTCUSDT', reconnectPrices: false), isFalse);
    f.prices();
    await f.flush();
    expect(state().failure, same(failure));
  });

  test('refresh error observation does not keep unused public feeds alive', () async {
    // Observe pricing directly, without the allocation controller that owns
    // a separate subscription for the lifetime of a review/signature.
    f.listener = f.container.listen(mainOrderPricingProvider, (_, _) {});
    await f.flush();
    await f.container.read(liveOrderProvider.notifier).load('BTCUSDT');
    await f.flush();
    state();
    expect(f.marks.listeners, 1);
    expect(f.quotes['BTCUSDT']!.listeners, 1);
    f.listener!.close();
    await f.container.pump();
    await f.flush();
    expect(f.marks.listeners, 0);
    expect(f.quotes['BTCUSDT']!.listeners, 0);
    expect(state().loading, isFalse);
  });
  test('stale/expired account is completely re-read using a new original lease', () async {
    await f.open();
    final previous = f.orders.context;
    f.now = f.now.add(const Duration(seconds: 30));
    f.container.read(liveOrderProvider.notifier).markStale();
    f.orders.context = capacityContext(time: f.now);
    f.prices();
    await f.flush();
    final refreshed = await controller().refresh('BTCUSDT');
    expect(refreshed, true, reason: state().failure?.key);
    expect(f.container.read(liveOrderProvider).context!.receivedAt, f.now);
    expect(f.container.read(liveOrderProvider).context, isNot(same(previous)));
    expect(f.orders.reads, 2);
    expect(f.capacities.reads, 2);
  });
  test('existing disconnected monitor reconnects before any private snapshot read', () async {
    await f.open();
    await f.container.read(accountChangeProvider.notifier).authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
    await changes.channels.last.close();
    await f.flush();
    final reads = f.orders.reads;
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.monitoring);
    expect(f.orders.reads, reads);
    expect(changes.channels.length, 2);
    changes.channels.last.add(const AccountChangeEvent.connected());
    expect(await result, true);
    expect(f.orders.reads, reads + 1);
    expect(changes.authorizations, 1);
    expect(f.container.read(mainOrderCapacityProvider.notifier).current, isNotNull);
  });
  test('pending monitor authorization never overlaps new wallet read prompts', () async {
    await f.open();
    changes.gate = Completer<void>();
    final monitoring = f.container.read(accountChangeProvider.notifier).authorize();
    expect(await controller().refresh('BTCUSDT'), false);
    expect(state().failure!.key, 'liveOrderSettingsBusy');
    expect(f.orders.reads, 1);
    expect(f.capacities.reads, 1);
    changes.gate!.complete();
    await monitoring;
  });
  test('failed reconnect never proceeds with private snapshots or reauthorizes', () async {
    await f.open();
    await f.container.read(accountChangeProvider.notifier).authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
    await changes.channels.last.close();
    await f.flush();
    final reads = f.orders.reads;
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    changes.channels.last.addError(const AccountReadFailure('accountNetwork'));
    expect(await result, false);
    expect(f.orders.reads, reads);
    expect(state().failure!.key, 'accountNetwork');
    expect(changes.authorizations, 1);
  });
  test('old fresh quotes cannot complete a refresh until new receipts arrive', () async {
    await f.open();
    f.now = f.now.add(const Duration(seconds: 3));
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.pricing);
    f.marks.emit(revaluationMarks({'BTCUSDT': '100'}, time: f.now));
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.pricing);
    f.prices();
    expect(await result, true);
    expect(f.orders.reads, 2);
    expect(f.capacities.reads, 2);
  });
  test('duplicate refresh shares no new reads or signatures', () async {
    await f.open();
    f.orders.readGate = Completer<void>();
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    expect(await controller().refresh('BTCUSDT'), false);
    expect(f.orders.reads, 2);
    f.orders.readGate!.complete();
    expect(await result, true);
    expect(f.capacities.reads, 2);
  });
  for (final stage in [
    MainOrderRefreshStage.account,
    MainOrderRefreshStage.capacity,
    MainOrderRefreshStage.pricing,
  ]) {
    test('cancel $stage returns promptly, releases lease and ignores late reads', () async {
      await f.open();
      if (stage == MainOrderRefreshStage.account) f.orders.readGate = Completer<void>();
      if (stage == MainOrderRefreshStage.capacity) f.capacities.gate = Completer<void>();
      if (stage == MainOrderRefreshStage.pricing) f.now = f.now.add(const Duration(seconds: 3));
      final result = controller().refresh('BTCUSDT');
      await f.flush();
      expect(state().stage, stage);
      controller().stop();
      expect(await result.timeout(const Duration(seconds: 1)), false);
      expect(state().loading, false);
      expect(f.container.read(symbolSettingsActivityProvider).owner, isNull);
      f.orders.readGate?.complete();
      f.capacities.gate?.complete();
      f.prices();
      await f.flush();
      expect(state().loading, false);
      expect(state().failure, isNull);
      expect(f.orders.submits, 0);
    });
  }
  test('new symbol cancels the captured refresh and prevents a late capacity read', () async {
    await f.open();
    f.orders.readGate = Completer<void>();
    final result = controller().refresh('BTCUSDT');
    await f.flush();
    f.container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(await result, false);
    f.orders.readFailure = const AccountReadFailure(
      'accountNetwork',
      details: ApiErrorDetails(cause: ApiErrorCause.cancelled),
    );
    f.orders.readGate!.complete();
    await f.flush();
    expect(f.capacities.reads, 1);
    expect(state().loading, false);
    expect(state().failure, isNull);
    expect(f.container.read(liveOrderProvider).failure, isNull);
  });
  test('new symbol clears an old completed read error before its replacement starts', () async {
    await f.open();
    f.orders.readFailure = const AccountReadFailure(
      'accountNetwork',
      details: ApiErrorDetails(cause: ApiErrorCause.cancelled),
    );
    expect(await controller().refresh('BTCUSDT'), false);
    expect(state().failure?.details?.cause, ApiErrorCause.cancelled);
    f.container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(state().failure, isNull);
    expect(f.container.read(liveOrderProvider).failure, isNull);
    expect(f.orders.submits, 0);
  });
  for (final stage in [MainOrderRefreshStage.account, MainOrderRefreshStage.capacity]) {
    test(
      'rapid market switches ignore a late cancelled $stage after replacement succeeds',
      () async {
        await f.open();
        final held = Completer<void>();
        if (stage == MainOrderRefreshStage.account) f.orders.readGate = held;
        if (stage == MainOrderRefreshStage.capacity) f.capacities.gate = held;
        final previous = controller().refresh('BTCUSDT', reconnectPrices: false);
        await f.flush();
        expect(state().stage, stage);
        for (final symbol in ['ETHUSDT', 'SOLUSDT', 'BTCUSDT']) {
          f.container.read(symbolProvider.notifier).select(symbol);
          expect(state().failure, isNull);
        }
        expect(await previous, isFalse);
        f.orders.readGate = null;
        f.capacities.gate = null;
        f.now = f.now.add(const Duration(seconds: 3));
        f.orders.context = capacityContext(time: f.now);
        f.prices();
        expect(await controller().refresh('BTCUSDT', reconnectPrices: false), isTrue);
        const cancelled = AccountReadFailure(
          'accountNetwork',
          details: ApiErrorDetails(cause: ApiErrorCause.cancelled),
        );
        if (stage == MainOrderRefreshStage.account) f.orders.readFailure = cancelled;
        if (stage == MainOrderRefreshStage.capacity) f.capacities.failure = cancelled;
        held.complete();
        await f.flush();
        expect(state().failure, isNull);
        expect(f.container.read(liveOrderProvider).failure, isNull);
        expect(f.container.read(mainOrderCapacityProvider).failure, isNull);
        expect(
          f.container.read(mainOrderCapacityProvider.notifier).current?.context,
          f.orders.context,
        );
        expect(f.container.read(symbolSettingsActivityProvider).owner, isNull);
        expect(f.orders.submits, 0);
      },
    );
  }
  test('account event during refresh invalidates new facts instead of claiming success', () async {
    await f.open();
    f.capacities.gate = Completer<void>();
    final pending = controller().refresh('BTCUSDT');
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.capacity);
    f.container.read(liveOrderProvider.notifier).markStale();
    f.capacities.gate!.complete();
    expect(await pending, false);
    expect(f.container.read(mainOrderCapacityProvider.notifier).current, isNull);
    expect(f.orders.submits, 0);
  });
  test('cancellation during monitor reconnect returns without opening any new read', () async {
    await f.open();
    await f.container.read(accountChangeProvider.notifier).authorize();
    changes.channels.last.add(const AccountChangeEvent.connected());
    await changes.channels.last.close();
    await f.flush();
    final reads = f.orders.reads;
    final pending = controller().refresh('BTCUSDT');
    await f.flush();
    expect(state().stage, MainOrderRefreshStage.monitoring);
    controller().stop();
    expect(await pending, false);
    changes.channels.last.add(const AccountChangeEvent.connected());
    await f.flush();
    expect(f.orders.reads, reads);
    expect(state().loading, false);
    expect(state().failure, isNull);
  });
  test('signed capacity failure is retained and no quote wait or order begins', () async {
    await f.open();
    f.capacities.failure = const AccountReadFailure('authWalletRejected');
    expect(await controller().refresh('BTCUSDT'), false);
    expect(state().failure!.key, 'authWalletRejected');
    expect(f.container.read(mainOrderCapacityProvider).stale, true);
    expect(f.orders.submits, 0);
  });
}
