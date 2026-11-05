import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/points/application/event_engagement_provider.dart';
import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/application/trading_event_provider.dart';
import 'package:vanta/features/points/domain/event_engagement.dart';
import 'package:vanta/features/points/domain/event_registration.dart';
import 'package:vanta/features/points/domain/points.dart';

import '../../support/channel_events.dart';
import '../../support/identity_repository.dart';
import '../../support/points.dart';

const _identity = AuthIdentity(
  id: 'channel',
  walletAddress: pointsTestAddress,
  walletKind: WalletKind.external,
  signingAvailable: true,
);
void main() {
  late DateTime now;
  late TestPointsRepository points;
  late TestEventEngagementRepository actions;
  late TestIdentityRepository identity;
  late ProviderContainer container;
  final listeners = <ProviderSubscription<dynamic>>[];
  EventEngagementController controller() => container.read(eventEngagementProvider(17).notifier);
  Future<void> ready() async {
    await container.read(eventParticipantProvider(17).notifier).refresh();
    await container.read(eventTaskProgressProvider(17).notifier).refresh();
  }

  void scenario(String title, Future<void> Function(WidgetTester) work) {
    testWidgets(title, (tester) async {
      now = DateTime.utc(2026, 11, 4, 12);
      points = TestPointsRepository(now: () => now)
        ..eventValue = channelEventFixture()
        ..eventRows = [channelEventFixture()]
        ..registered = true
        ..taskProgress = taskProgressFixture();
      actions = TestEventEngagementRepository();
      identity = TestIdentityRepository()..restored = _identity;
      container = ProviderContainer(
        overrides: [
          pointsClockProvider.overrideWithValue(() => now),
          pointsRepositoryProvider.overrideWithValue(points),
          identityRepositoryProvider.overrideWithValue(identity),
          eventEngagementRepositoryProvider.overrideWithValue(actions),
        ],
      );
      for (final provider in [
        tradingEventProvider(17),
        eventParticipantProvider(17),
        eventTaskProgressProvider(17),
        eventEngagementProvider(17),
        channelEventsProvider,
        channelEventLeaderboardProvider(17),
      ]) {
        listeners.add(container.listen(provider, (_, _) {}));
      }
      try {
        await tester.pump();
        await work(tester);
      } finally {
        for (final listener in listeners) {
          listener.close();
        }
        listeners.clear();
        container.dispose();
        await identity.dispose();
        await tester.pump();
      }
    });
  }

  scenario('channel entry reads public list/detail/ranking only; private task query is explicit', (
    tester,
  ) async {
    expect(points.calls, unorderedEquals(['event:17', 'channel-events', 'event-board:17']));
    expect(controller().prepare(EventEngagementAction.checkIn), null);
    await ready();
    expect(controller().prepare(EventEngagementAction.checkIn), isNotNull);
    expect(actions.approvals, isEmpty);
    expect(identity.wallets, 0);
  });
  scenario('task response rejects wrong event/address and preserves no fabricated progress', (
    tester,
  ) async {
    points.wrongEvent = 18;
    points.taskProgress = null;
    await ready();
    expect(container.read(eventTaskProgressProvider(17)).failureKey, 'pointsDataInvalid');
    expect(controller().prepare(EventEngagementAction.walletConnect), null);
  });
  scenario('confirm invokes one action and duplicate tap is ignored', (tester) async {
    await ready();
    actions.gate = Completer<void>();
    final approval = controller().prepare(EventEngagementAction.checkIn)!;
    final pending = controller().confirm(approval);
    await tester.pump();
    await controller().confirm(approval);
    expect(actions.approvals.length, 1);
    actions.gate!.complete();
    await pending;
    expect(container.read(eventEngagementProvider(17)).phase, EventRegistrationPhase.verified);
  });
  scenario('day change after review requires new approval', (tester) async {
    await ready();
    final approval = controller().prepare(EventEngagementAction.checkIn)!;
    now = DateTime.utc(2026, 11, 5);
    points.taskProgress = taskProgressFixture(today: '2026-11-05');
    await ready();
    await controller().confirm(approval);
    expect(actions.approvals, isEmpty);
    expect(container.read(eventEngagementProvider(17)).failureKey, 'eventRegistrationChanged');
  });
  scenario('five minute expiry blocks signing until explicit refresh', (tester) async {
    await ready();
    await tester.pump(const Duration(minutes: 5));
    expect(container.read(eventTaskProgressProvider(17)).stale, true);
    expect(controller().prepare(EventEngagementAction.checkIn), null);
    expect(actions.approvals, isEmpty);
  });
  scenario('background ignores late task result and resume does not automatically send address', (
    tester,
  ) async {
    await ready();
    final old = container.read(eventTaskProgressProvider(17)).snapshot;
    points.gates['tasks:17:$pointsTestAddress'] = Completer<void>();
    final pending = container.read(eventTaskProgressProvider(17).notifier).refresh();
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    points.gates.remove('tasks:17:$pointsTestAddress')!.complete();
    await pending;
    expect(container.read(eventTaskProgressProvider(17)).snapshot, same(old));
    final before = points.calls.length;
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pump();
    expect(points.calls.skip(before).where((c) => c.startsWith('tasks:')), isEmpty);
    expect(container.read(eventTaskProgressProvider(17)).stale, true);
  });
  scenario('switch wallet clears progress and ignores previous signer response', (tester) async {
    await ready();
    actions.gate = Completer<void>();
    final pending = controller().confirm(controller().prepare(EventEngagementAction.checkIn)!);
    identity.events.add(
      const AuthIdentity(
        id: 'other',
        walletAddress: '0x2222222222222222222222222222222222222222',
        walletKind: WalletKind.external,
        signingAvailable: true,
      ),
    );
    await tester.pump();
    expect(container.read(eventTaskProgressProvider(17)).snapshot, null);
    actions.gate!.complete();
    await pending;
    expect(container.read(eventEngagementProvider(17)).phase, EventRegistrationPhase.idle);
  });
  scenario('unknown locks both actions; explicit reconciliation false retains lock', (
    tester,
  ) async {
    await ready();
    actions.failure = const EventRegistrationFailure('eventEngagementUnknown', mayHaveSent: true);
    await controller().confirm(controller().prepare(EventEngagementAction.checkIn)!);
    expect(controller().prepare(EventEngagementAction.walletConnect), null);
    actions.failure = null;
    actions.clear = false;
    await controller().reconcile();
    expect(container.read(eventEngagementProvider(17)).locked, true);
    expect(actions.approvals.length, 1);
    actions.clear = true;
    await controller().reconcile();
    expect(container.read(eventEngagementProvider(17)).locked, false);
  });
  scenario('reconciliation failure retains unknown and hides raw errors', (tester) async {
    await ready();
    actions.result = EventRegistrationPhase.unknown;
    await controller().confirm(controller().prepare(EventEngagementAction.checkIn)!);
    actions.failure = Exception('sensitive raw payload');
    await controller().reconcile();
    final state = container.read(eventEngagementProvider(17));
    expect(state.phase, EventRegistrationPhase.unknown);
    expect(state.failureKey, 'eventEngagementReconcileFailed');
  });
  scenario('reader failure retains prior progress as stale until manual recovery', (tester) async {
    await ready();
    final old = container.read(eventTaskProgressProvider(17)).snapshot;
    points.failures['tasks:17:$pointsTestAddress'] = const PointsFailure('pointsNetwork');
    await controller().reconcile();
    expect(container.read(eventTaskProgressProvider(17)).snapshot, same(old));
    expect(container.read(eventTaskProgressProvider(17)).stale, true);
    expect(controller().prepare(EventEngagementAction.checkIn), null);
    points.failures.clear();
    await controller().reconcile();
    expect(controller().prepare(EventEngagementAction.checkIn), isNotNull);
  });
  scenario('stop reading discards late response without signing', (tester) async {
    points.gates['tasks:17:$pointsTestAddress'] = Completer<void>();
    final pending = container.read(eventTaskProgressProvider(17).notifier).refresh();
    container.read(eventTaskProgressProvider(17).notifier).stop();
    points.gates.remove('tasks:17:$pointsTestAddress')!.complete();
    await pending;
    expect(container.read(eventTaskProgressProvider(17)).snapshot, null);
    expect(actions.approvals, isEmpty);
  });
}
