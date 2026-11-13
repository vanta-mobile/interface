import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/quick_order_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/quick_order.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/quick_order.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestLiveOrderRepository orders;
  late TestQuickOrderRepository sizing;
  late DateTime now;
  setUp(() async {
    identity = TestIdentityRepository()..restored = signingIdentity;
    orders = TestLiveOrderRepository()..context = liveContext(bid: '79999', ask: '80001');
    sizing = TestQuickOrderRepository();
    now = liveOrderClock;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        liveOrderRepositoryProvider.overrideWithValue(orders),
        quickOrderRepositoryProvider.overrideWithValue(sizing),
        liveOrderClockProvider.overrideWithValue(() => now),
      ],
    );
    container.read(authProvider);
    container.read(quickOrderProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });
  QuickOrderController controller() => container.read(quickOrderProvider.notifier);
  test('no automatic read, empty quantity and separate percentage sizing', () async {
    expect(orders.reads, 0);
    expect(sizing.reads, 0);
    expect(container.read(quickOrderProvider).quantity, '');
    expect(container.read(quickOrderProvider).percent, null);
    expect(controller().prepare(true), null);
    await controller().load();
    expect(orders.reads, 1);
    expect(sizing.reads, 1);
    expect(controller().prepare(true), null);
    controller().selectPercent(50);
    expect(controller().quantity(true), '0.005');
    expect(controller().prepare(true)!.draft.quickEntry, true);
    controller().setQuantity('80.01');
    expect(container.read(quickOrderProvider).percent, null);
    expect(controller().prepare(false)!.draft.buy, false);
  });
  test('sizing failure preserves manual input and permits valid manual MARKET only', () async {
    controller().setQuantity('80.01');
    sizing.failure = const AccountReadFailure('accountNetwork');
    await controller().load();
    expect(container.read(quickOrderProvider).quantity, '80.01');
    expect(controller().prepare(true), isNotNull);
    controller().selectPercent(100);
    expect(controller().quantity(true), null);
    expect(controller().prepare(true), null);
    sizing.failure = null;
    await controller().load();
    expect(controller().prepare(true), isNotNull);
  });
  test(
    'known accepted result clears quantity and percentage; refused submission preserves input',
    () async {
      await controller().load();
      controller().setQuantity('80.01');
      orders.failure = const AccountReadFailure('authWalletRejected');
      await controller().submit(controller().prepare(true)!);
      expect(container.read(quickOrderProvider).quantity, '80.01');
      orders.failure = null;
      await controller().load();
      controller().selectPercent(25);
      await controller().submit(controller().prepare(true)!);
      expect(container.read(quickOrderProvider).quantity, '');
      expect(container.read(quickOrderProvider).percent, null);
      expect(orders.lastIntent!.draft.quickEntry, true);
    },
  );
  test('unknown outcome allows editing while explicit recheck keeps original intent', () async {
    await controller().load();
    controller().setQuantity('80.01');
    orders.result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    await controller().submit(controller().prepare(true)!);
    final intent = orders.lastIntent!;
    expect(container.read(quickOrderProvider).quantity, '80.01');
    controller().setQuantity('1');
    expect(container.read(quickOrderProvider).quantity, '1');
    expect(orders.submits, 1);
    orders.result = LiveOrderResult(
      orderId: '12345',
      status: 'FILLED',
      executedQuantity: Decimal.parse('0.001'),
    );
    await container.read(liveOrderProvider.notifier).recheck();
    expect(orders.submits, 1);
    expect(orders.checks, 1);
    expect(orders.lastIntent!.clientOrderId, intent.clientOrderId);
    expect(container.read(quickOrderProvider).quantity, '');
  });
  test('snapshot age and changes after confirmation block quick submission', () async {
    await controller().load();
    controller().setQuantity('80.01');
    final intent = controller().prepare(true)!;
    now = now.add(const Duration(seconds: 30));
    expect(controller().prepare(true), null);
    await controller().submit(intent);
    expect(orders.submits, 0);
    now = liveOrderClock;
    controller().setQuantity('160.02');
    await controller().submit(intent);
    expect(orders.submits, 0);
  });
  test('symbol change discards a pending sizing response and resets independent input', () async {
    sizing.gate = Completer<void>();
    controller().setQuantity('80.01');
    final future = controller().load();
    await Future<void>.delayed(Duration.zero);
    expect(sizing.reads, 1);
    container.read(symbolProvider.notifier).select('ETHUSDT');
    expect(sizing.latestCurrent!(), false);
    sizing.gate!.complete();
    await future;
    expect(container.read(quickOrderProvider).quantity, '');
    expect(container.read(quickOrderProvider).sizing, null);
    expect(controller().prepare(true), null);
  });
  test('expiry while sizing discards late read and preserves quantity', () async {
    sizing.gate = Completer<void>();
    controller().setQuantity('80.01');
    final future = controller().load();
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(seconds: 30));
    expect(sizing.latestCurrent!(), false);
    sizing.gate!.complete();
    await future;
    expect(container.read(quickOrderProvider).sizing, null);
    expect(container.read(quickOrderProvider).quantity, '80.01');
    expect(controller().prepare(true), null);
    expect(container.read(symbolSettingsActivityProvider).owner, null);
  });
  test('logout invalidates pending sizing and clears the wallet input scope', () async {
    sizing.gate = Completer<void>();
    controller().setQuantity('80.01');
    final future = controller().load();
    await Future<void>.delayed(Duration.zero);
    await container.read(authProvider.notifier).logout();
    expect(sizing.latestCurrent!(), false);
    sizing.gate!.complete();
    await future;
    expect(container.read(quickOrderProvider).quantity, '');
    expect(container.read(quickOrderProvider).sizing, null);
    expect(controller().prepare(true), null);
  });
  test('settings exclusion blocks quick confirmation and percentage read', () async {
    await controller().load();
    controller().setQuantity('80.01');
    final activity = container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage)!;
    expect(controller().prepare(true), null);
    await controller().load();
    expect(sizing.reads, 1);
    activity.finish(lease, unresolved: false);
  });
  test('balance pre-check counts only the opening part of a market entry', () {
    final flat = liveContext(bid: '79999', ask: '80001');
    expect(quickOrderExceedsBalance(flat, true, '0.011'), false);
    expect(quickOrderExceedsBalance(flat, true, '0.012'), true);
    final short = liveContext(
      bid: '79999',
      ask: '80001',
      positions: {
        'BOTH': LiveOrderPosition(
          side: 'BOTH',
          quantity: Decimal.parse('-0.5'),
          entryPrice: Decimal.parse('80000'),
        ),
      },
    );
    expect(quickOrderExceedsBalance(short, true, '0.511'), false);
    expect(quickOrderExceedsBalance(short, false, '0.012'), true);
    expect(quickOrderExceedsBalance(liveContext(available: null), true, '1'), false);
  });
  test('typed quote amount converts at the ask/bid, floored to the market step', () async {
    await controller().load();
    controller().setQuantity('160.02');
    expect(controller().quantity(true), '0.002');
    expect(controller().quantity(false), '0.002');
    controller().setQuantity('160');
    expect(controller().quantity(true), '0.001');
    expect(controller().prepare(true)!.draft.quantity, '0.001');
    controller().setQuantity('10');
    expect(controller().validation(true), 'quickOrderAmountTooSmall');
    controller().setQuantity('abc');
    expect(controller().validation(true), 'quickOrderInvalidAmount');
    orders.context = liveContext();
    await controller().load();
    controller().setQuantity('80');
    expect(controller().validation(true), 'quickOrderQuoteUnavailable');
  });

  group('background sizing', () {
    ProviderContainer grantContainer({TradingAgentStatus status = TradingAgentStatus.active}) {
      final c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          liveOrderRepositoryProvider.overrideWithValue(orders),
          quickOrderRepositoryProvider.overrideWithValue(sizing),
          liveOrderClockProvider.overrideWithValue(() => now),
          tradingAgentProvider.overrideWith(
            (ref) async => TradingAgent(
              identityId: signingIdentity.id,
              owner: accountAddress,
              address: '0x3333333333333333333333333333333333333333',
              expiresAt: DateTime.utc(2100),
              status: status,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('an active grant readies sizing for the fresh snapshot without loading', () async {
      final c = grantContainer();
      c.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(tradingAgentProvider.future);
      final quick = c.read(quickOrderProvider.notifier);
      // No snapshot yet: nothing to size, and no account read is started.
      await quick.prefetch();
      expect(sizing.reads, 0);
      expect(orders.reads, 0);
      await c.read(liveOrderProvider.notifier).load('BTCUSDT');
      sizing.gate = Completer<void>();
      final pending = quick.prefetch();
      expect(c.read(quickOrderProvider).loading, false);
      // An explicit tap during the background read waits for it.
      final tap = quick.load();
      sizing.gate!.complete();
      await pending;
      await tap;
      expect(sizing.reads, 1);
      expect(orders.reads, 1);
      quick.selectPercent(50);
      expect(quick.quantity(true), '0.005');
      await quick.prefetch();
      expect(sizing.reads, 1);
      // A renewed snapshot is sized again; a quiet failure leaves no error
      // and no loading state behind.
      orders.context = liveContext(bid: '79998', ask: '80002');
      await c.read(liveOrderProvider.notifier).load('BTCUSDT');
      sizing.failure = const AccountReadFailure('accountNetwork');
      await quick.prefetch();
      expect(sizing.reads, 2);
      expect(c.read(quickOrderProvider).failure, null);
      expect(c.read(quickOrderProvider).loading, false);
    });

    test('without an active grant nothing is read in the background', () async {
      final c = grantContainer(status: TradingAgentStatus.unknown);
      c.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(tradingAgentProvider.future);
      await c.read(liveOrderProvider.notifier).load('BTCUSDT');
      await c.read(quickOrderProvider.notifier).prefetch();
      expect(sizing.reads, 0);
    });
  });
}
