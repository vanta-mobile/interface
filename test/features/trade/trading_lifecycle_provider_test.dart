import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_capacity_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/trade/application/trading_lifecycle_provider.dart';

import '../../support/main_order_live_pricing.dart';
import '../../support/live_order.dart';

void main() {
  late MainOrderLiveFixture f;
  late TradingLifecycle lifecycle;
  setUp(() async {
    f = MainOrderLiveFixture();
    await f.open();
    f.container.listen(tradingLifecycleProvider, (_, _) {});
    lifecycle = f.container.read(tradingLifecycleProvider);
  });
  tearDown(() => f.close());

  for (final owner in [SymbolSetting.order, SymbolSetting.leverage]) {
    test(
      'resume defers session reconciliation until $owner finishes without clearing capacity',
      () async {
        final activity = f.container.read(symbolSettingsActivityProvider.notifier);
        final lease = activity.acquire(owner)!;
        final capacity = f.container.read(mainOrderCapacityProvider).snapshot;
        final auth = f.container.read(authProvider);
        lifecycle.onChanged(AppLifecycleState.paused);
        lifecycle.onChanged(AppLifecycleState.resumed);
        lifecycle.onChanged(AppLifecycleState.resumed);
        await f.flush();
        expect(f.identity.initializations, 1);
        expect(f.container.read(authProvider), same(auth));
        activity.finish(lease, unresolved: false);
        await f.flush();
        expect(f.identity.initializations, 2);
        expect(f.container.read(authProvider), same(auth));
        expect(f.container.read(mainOrderCapacityProvider).snapshot, same(capacity));
        expect(f.identity.wallets, 0);
      },
    );
  }

  test('lease release in background waits for foreground and coalesces pending resumes', () async {
    final activity = f.container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order)!;
    lifecycle.onChanged(AppLifecycleState.resumed);
    await f.flush();
    lifecycle.onChanged(AppLifecycleState.hidden);
    activity.finish(lease, unresolved: false);
    await f.flush();
    expect(f.identity.initializations, 1);
    expect(f.container.read(quoteUpdatesActiveProvider), false);
    lifecycle.onChanged(AppLifecycleState.resumed);
    await f.flush();
    expect(f.identity.initializations, 2);
    expect(f.container.read(quoteUpdatesActiveProvider), true);
  });

  test('inactive wallet prompt does not reconcile when an operation finishes', () async {
    final activity = f.container.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order)!;
    lifecycle.onChanged(AppLifecycleState.resumed);
    lifecycle.onChanged(AppLifecycleState.inactive);
    activity.finish(lease, unresolved: false);
    await f.flush();
    expect(f.identity.initializations, 1);
    lifecycle.onChanged(AppLifecycleState.resumed);
    await f.flush();
    expect(f.identity.initializations, 2);
  });

  test(
    'session logout during prompt remains immediate and pending resume cannot restore it',
    () async {
      f.container.read(symbolSettingsActivityProvider.notifier).acquire(SymbolSetting.order);
      lifecycle.onChanged(AppLifecycleState.resumed);
      f.identity.events.add(null);
      expect(f.container.read(authProvider).identity, isNull);
      expect(f.container.read(liveOrderProvider).context, isNull);
      await f.flush();
      expect(f.identity.initializations, 1);
    },
  );

  test('disposal cancels a queued resume reconciliation', () async {
    lifecycle.onChanged(AppLifecycleState.resumed);
    f.disposeContainer();
    await f.flush();
    expect(f.identity.initializations, 1);
  });

  test('idle background still invalidates order review', () async {
    expect(f.container.read(liveOrderProvider).stale, false);
    lifecycle.onChanged(AppLifecycleState.paused);
    expect(f.container.read(liveOrderProvider).stale, true);
    expect(f.container.read(quoteUpdatesActiveProvider), false);
  });

  test('capacity read returning from wallet retains its snapshot and prepared review', () async {
    f.allocation.manual();
    f.capacities.gate = Completer<void>();
    final preparing = f.allocation.prepare(
      liveDraft(quantity: '2', price: '100'),
      isFormCurrent: () => true,
    );
    await f.flush();
    expect(f.container.read(mainOrderCapacityProvider).loading, true);
    lifecycle.onChanged(AppLifecycleState.paused);
    lifecycle.onChanged(AppLifecycleState.resumed);
    await f.flush();
    expect(f.identity.initializations, 1);
    f.capacities.gate!.complete();
    final review = await preparing;
    await f.flush();
    expect(review, isNotNull);
    expect(f.allocation.matches(review!), true);
    expect(f.identity.initializations, 2);
    expect(f.container.read(mainOrderCapacityProvider).stale, false);
  });

  test('busy authentication defers resume refresh and never creates another wallet', () async {
    f.identity.initializeGate = Completer<void>();
    final pending = f.container.read(authProvider.notifier).bootstrap();
    lifecycle.onChanged(AppLifecycleState.resumed);
    await f.flush();
    expect(f.identity.initializations, 2);
    f.identity.initializeGate!.complete();
    await pending;
    await f.flush();
    expect(f.identity.initializations, 3);
    expect(f.identity.wallets, 0);
  });
}
