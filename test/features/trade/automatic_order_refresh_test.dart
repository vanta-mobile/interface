import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/network/request_scope.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/automatic_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_review_submission_provider.dart';
import 'package:vanta/features/portfolio/application/order_entry_gate_provider.dart';
import 'package:vanta/features/portfolio/application/order_review_activity_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/main_order_allocation.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity_preview.dart';
import 'package:vanta/features/portfolio/domain/main_order_review_input.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/trade/application/navigation_provider.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';

const identity = AuthIdentity(id: 'one', walletAddress: '0xabc', signingAvailable: true);

class Auth extends AuthController {
  @override
  AuthSession build() => const AuthSession();
  void set(AuthIdentity? value) => state = AuthSession(identity: value, phase: AuthPhase.signedIn);
}

class Activity extends SymbolSettingsActivityController {
  @override
  SymbolSettingsActivity build() => const SymbolSettingsActivity();
  void set(SymbolSettingsActivity value) => state = value;
}

class Live extends LiveOrderController {
  @override
  LiveOrderState build() => const LiveOrderState();
  void set(LiveOrderState value) => state = value;
}

class Allocation extends MainOrderAllocationController {
  @override
  MainOrderAllocationState build() => const MainOrderAllocationState();
  void set(MainOrderAllocationState value) => state = value;
}

class Confirmation extends MainOrderReviewSubmissionController {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class Refresh extends MainOrderRefreshController {
  final calls = <String>[];
  final scopes = <RequestScope?>[];
  bool success = true;
  Completer<void>? gate;
  @override
  MainOrderRefreshState build() => const MainOrderRefreshState();
  @override
  Future<bool> refresh(
    String symbol, {
    bool reconnectPrices = true,
    bool background = false,
  }) async {
    expect(background, isTrue);
    calls.add(symbol);
    scopes.add(RequestScope.current);
    state = const MainOrderRefreshState(stage: MainOrderRefreshStage.account);
    await gate?.future;
    if (success) {
      (ref.read(liveOrderProvider.notifier) as Live).set(
        LiveOrderState(context: liveContext(time: ref.read(liveOrderClockProvider)())),
      );
    }
    state = MainOrderRefreshState(
      failure: success ? null : const AccountReadFailure('accountNetwork'),
    );
    return success;
  }

  @override
  void stop() => state = const MainOrderRefreshState();
}

void main() {
  void scenario(void Function(FakeAsync, ProviderContainer, Refresh, void Function(bool)) check) {
    fakeAsync((clock) {
      TradingAgent? agent;
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(Auth.new),
          symbolSettingsActivityProvider.overrideWith(Activity.new),
          liveOrderProvider.overrideWith(Live.new),
          mainOrderAllocationProvider.overrideWith(Allocation.new),
          mainOrderReviewSubmissionProvider.overrideWith(Confirmation.new),
          orderEntryGateProvider.overrideWithValue(OrderEntryGate.ready),
          liveOrderClockProvider.overrideWithValue(() => liveOrderClock.add(clock.elapsed)),
          tradingAgentClockProvider.overrideWithValue(() => liveOrderClock.add(clock.elapsed)),
          tradingAgentProvider.overrideWith((ref) async => agent),
          mainOrderRefreshProvider.overrideWith(Refresh.new),
        ],
      );
      void grant(bool enabled) {
        agent = enabled
            ? TradingAgent(
                identityId: identity.id,
                owner: identity.walletAddress!,
                address: 'agent',
                expiresAt: liveOrderClock.add(const Duration(days: 1)),
                status: TradingAgentStatus.active,
              )
            : null;
        container.invalidate(tradingAgentProvider);
        clock.elapse(Duration.zero);
        clock.flushMicrotasks();
      }

      container.listen(automaticOrderRefreshProvider, (_, _) {});
      clock.flushMicrotasks();
      final refresh = container.read(mainOrderRefreshProvider.notifier) as Refresh;
      try {
        check(clock, container, refresh, grant);
      } finally {
        container.dispose();
        clock.flushMicrotasks();
      }
      expect(clock.periodicTimerCount, 0);
    });
  }

  test('waits for grant, then renews repeatedly before expiry without user action', () {
    scenario((clock, c, refresh, grant) {
      expect(refresh.calls, isEmpty);
      (c.read(authProvider.notifier) as Auth).set(identity);
      clock.flushMicrotasks();
      expect(refresh.calls, isEmpty);
      grant(true);
      expect(refresh.calls, ['BTCUSDT']);
      clock.elapse(const Duration(seconds: 14));
      expect(refresh.calls.length, 1);
      clock.elapse(const Duration(seconds: 1));
      expect(refresh.calls.length, 2);
      clock.elapse(const Duration(seconds: 60));
      expect(refresh.calls.length, 6);
      expect(c.read(liveOrderProvider).stale, false);
      expect(c.read(liveOrderProvider).context!.receivedAt, liveOrderClock.add(clock.elapsed));
    });
  });

  test('failures retry with bounded backoff, no event-driven request loop', () {
    scenario((clock, c, refresh, grant) {
      refresh.success = false;
      (c.read(authProvider.notifier) as Auth).set(identity);
      grant(true);
      expect(refresh.calls.length, 1);
      for (var i = 0; i < 10; i++) {
        grant(true);
      }
      expect(refresh.calls.length, 1);
      clock.elapse(const Duration(seconds: 3));
      expect(refresh.calls.length, 1);
      clock.elapse(const Duration(seconds: 1));
      expect(refresh.calls.length, 2);
      clock.elapse(const Duration(seconds: 7));
      expect(refresh.calls.length, 2);
      refresh.success = true;
      clock.elapse(const Duration(seconds: 1));
      expect(refresh.calls.length, 3);
      expect(c.read(mainOrderRefreshProvider).failure, isNull);
    });
  });

  test('pauses in background and other pages, resumes with new read, logout stops', () {
    scenario((clock, c, refresh, grant) {
      (c.read(authProvider.notifier) as Auth).set(identity);
      grant(true);
      c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      clock.elapse(const Duration(minutes: 1));
      expect(refresh.calls.length, 1);
      c.read(quoteUpdatesActiveProvider.notifier).setActive(true);
      clock.flushMicrotasks();
      expect(refresh.calls.length, 2);
      c.read(appDestinationProvider.notifier).select(AppDestination.portfolio);
      clock.elapse(const Duration(minutes: 1));
      expect(refresh.calls.length, 2);
      c.read(appDestinationProvider.notifier).select(AppDestination.futures);
      clock.flushMicrotasks();
      expect(refresh.calls.length, 3);
      (c.read(authProvider.notifier) as Auth).set(null);
      clock.elapse(const Duration(minutes: 1));
      expect(refresh.calls.length, 3);
    });
  });

  test('active operations block polling; settled unknown orders allow read refresh', () {
    scenario((clock, c, refresh, grant) {
      (c.read(authProvider.notifier) as Auth).set(identity);
      grant(true);
      final review = c.read(orderReviewActivityProvider.notifier);
      review.begin();
      clock.elapse(const Duration(seconds: 20));
      expect(refresh.calls.length, 1);
      review.end();
      clock.flushMicrotasks();
      expect(refresh.calls.length, 2);
      final activity = c.read(symbolSettingsActivityProvider.notifier) as Activity;
      for (final state in [
        const SymbolSettingsActivity(owner: SymbolSetting.order, busy: true),
        const SymbolSettingsActivity(recoveryBlocked: true),
        const SymbolSettingsActivity(unresolved: true),
      ]) {
        activity.set(state);
        clock.elapse(const Duration(seconds: 20));
        expect(refresh.calls.length, 2);
      }
      activity.set(const SymbolSettingsActivity());
      (c.read(liveOrderProvider.notifier) as Live).set(
        LiveOrderState(
          intent: LiveOrderIntent(
            context: liveContext(),
            draft: liveDraft(),
            clientOrderId: 'unknown',
            revision: 1,
          ),
          result: const LiveOrderResult(),
        ),
      );
      clock.flushMicrotasks();
      // Refreshing reads after an unknown order never replays its placement.
      expect(refresh.calls.length, 3);
    });
  });

  test('live main confirmation keeps renewing, then pauses once signing starts', () {
    scenario((clock, c, refresh, grant) {
      (c.read(authProvider.notifier) as Auth).set(identity);
      grant(true);
      final review = c.read(orderReviewActivityProvider.notifier);
      review.begin();
      (c.read(mainOrderAllocationProvider.notifier) as Allocation).set(
        MainOrderAllocationState(
          review: MainOrderAllocationReview(
            intent: liveIntent(),
            capacity: assembledCapacity(),
            side: const MainOrderSidePreview(),
            revision: 1,
            input: MainOrderReviewInput(
              draft: liveDraft(),
              size: const LiveOrderSize(unit: OrderSizeUnit.base, text: '0.001'),
            ),
          ),
        ),
      );
      clock.elapse(const Duration(seconds: 40));
      expect(refresh.calls.length, 3);
      (c.read(liveOrderProvider.notifier) as Live).set(
        LiveOrderState(context: liveContext(), intent: liveIntent(), step: LiveOrderStep.signing),
      );
      clock.elapse(const Duration(seconds: 40));
      expect(refresh.calls.length, 3);
      review.end();
    });
  });

  test('confirm click pauses new polling until its pending attempt settles', () {
    scenario((clock, c, refresh, grant) {
      (c.read(authProvider.notifier) as Auth).set(identity);
      grant(true);
      expect(refresh.calls.length, 1);
      final confirmation = c.read(mainOrderReviewSubmissionProvider.notifier) as Confirmation;
      confirmation.set(true);
      clock.elapse(const Duration(seconds: 40));
      expect(refresh.calls.length, 1);
      confirmation.set(false);
      clock.flushMicrotasks();
      expect(refresh.calls.length, 2);
    });
  });

  test('in-flight refresh never overlaps polling and a new symbol reads separately', () {
    scenario((clock, c, refresh, grant) {
      refresh.gate = Completer<void>();
      (c.read(authProvider.notifier) as Auth).set(identity);
      grant(true);
      clock.elapse(const Duration(minutes: 1));
      expect(refresh.calls.length, 1);
      refresh.gate!.complete();
      clock.flushMicrotasks();
      refresh.success = false;
      c.read(symbolProvider.notifier).select('ETHUSDT');
      clock.flushMicrotasks();
      expect(refresh.calls, ['BTCUSDT', 'ETHUSDT']);
    });
  });

  test('new market read owns its scope when selection originates in a completed request', () {
    scenario((clock, c, refresh, grant) {
      (c.read(authProvider.notifier) as Auth).set(identity);
      grant(true);
      refresh.gate = Completer<void>();
      var selecting = true;
      RequestScope.run(() => selecting, () async {
        c.read(symbolProvider.notifier).select('ETHUSDT');
        selecting = false;
      });
      clock.flushMicrotasks();
      expect(refresh.calls, ['BTCUSDT', 'ETHUSDT']);
      expect(refresh.scopes.last!.active, isTrue);
      c.read(quoteUpdatesActiveProvider.notifier).setActive(false);
      clock.flushMicrotasks();
      expect(refresh.scopes.last!.active, isFalse);
      refresh.gate!.complete();
      clock.flushMicrotasks();
    });
  });
}
