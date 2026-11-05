import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/market/application/market_providers.dart';
import 'package:vanta/features/points/application/event_registration_provider.dart';
import 'package:vanta/features/points/application/points_provider.dart';
import 'package:vanta/features/points/application/trading_event_provider.dart';
import 'package:vanta/features/points/data/trading_event_mapper.dart';
import 'package:vanta/features/points/domain/event_registration.dart';
import 'package:vanta/features/points/domain/points.dart';

import '../../support/identity_repository.dart';
import '../../support/points.dart';
import '../../support/trading_events.dart';

const eventIdentity = AuthIdentity(
  id: 'events',
  walletAddress: pointsTestAddress,
  walletKind: WalletKind.external,
  signingAvailable: true,
);
void main() {
  late DateTime now;
  late TestPointsRepository repository;
  late TestEventRegistrationRepository actions;
  late TestIdentityRepository identity;
  late ProviderContainer container;
  final listeners = <ProviderSubscription<dynamic>>[];
  void watch() {
    listeners.add(container.listen(tradingEventsProvider, (_, _) {}));
    listeners.add(container.listen(tradingEventProvider(11), (_, _) {}));
    listeners.add(container.listen(eventLeaderboardProvider(11), (_, _) {}));
    listeners.add(container.listen(eventParticipantProvider(11), (_, _) {}));
    listeners.add(container.listen(eventRegistrationProvider(11), (_, _) {}));
  }

  EventRegistrationController action() => container.read(eventRegistrationProvider(11).notifier);
  Future<void> readParticipant() => container.read(eventParticipantProvider(11).notifier).refresh();
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      now = DateTime.utc(2026, 11, 4, 12);
      repository = TestPointsRepository(now: () => now);
      identity = TestIdentityRepository()..restored = eventIdentity;
      actions = TestEventRegistrationRepository();
      container = ProviderContainer(
        overrides: [
          pointsClockProvider.overrideWithValue(() => now),
          pointsRepositoryProvider.overrideWithValue(repository),
          identityRepositoryProvider.overrideWithValue(identity),
          eventRegistrationRepositoryProvider.overrideWithValue(actions),
        ],
      );
      try {
        await body(tester);
      } finally {
        for (final l in listeners) {
          l.close();
        }
        listeners.clear();
        container.dispose();
        await identity.dispose();
      }
    });
  }

  scenario(
    'event entry automatically reads public data only; participant is explicit and unsigned',
    (tester) async {
      watch();
      await tester.pump();
      expect(repository.calls, ['events', 'event:11', 'event-board:11']);
      expect(container.read(eventParticipantProvider(11)).snapshot, null);
      await readParticipant();
      expect(repository.calls.last, 'participant:11:$pointsTestAddress');
      expect(container.read(eventParticipantProvider(11)).snapshot!.value.registered, false);
      expect(actions.calls, 0);
      expect(identity.wallets, 0);
    },
  );
  scenario('wrong event/address results cannot cross controller scope', (tester) async {
    repository.wrongEvent = 12;
    repository.wrongAddress = true;
    watch();
    await tester.pump();
    await readParticipant();
    expect(container.read(tradingEventProvider(11)).failureKey, 'pointsDataInvalid');
    expect(container.read(eventLeaderboardProvider(11)).failureKey, 'pointsDataInvalid');
    expect(container.read(eventParticipantProvider(11)).failureKey, 'pointsDataInvalid');
    expect(action().prepare(), null);
    expect(actions.calls, 0);
  });
  scenario('independent partial failures retain old detail without discarding rankings', (
    tester,
  ) async {
    watch();
    await tester.pump();
    final old = container.read(tradingEventProvider(11)).snapshot;
    repository.failures['event:11'] = const PointsFailure('pointsNetwork');
    await container.read(tradingEventProvider(11).notifier).refresh();
    expect(container.read(tradingEventProvider(11)).snapshot, same(old));
    expect(container.read(tradingEventProvider(11)).stale, true);
    expect(container.read(eventLeaderboardProvider(11)).stale, false);
  });
  scenario('background cancels pending personal result; resume does not disclose address again', (
    tester,
  ) async {
    watch();
    await tester.pump();
    await readParticipant();
    final old = container.read(eventParticipantProvider(11)).snapshot;
    repository.gates['participant:11:$pointsTestAddress'] = Completer();
    final pending = readParticipant();
    container.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    repository.gates.remove('participant:11:$pointsTestAddress')!.complete();
    await pending;
    expect(container.read(eventParticipantProvider(11)).snapshot, same(old));
    final count = repository.calls.length;
    container.read(quoteUpdatesActiveProvider.notifier).setActive(true);
    await tester.pump();
    expect(repository.calls.skip(count), ['events', 'event:11', 'event-board:11']);
    expect(container.read(eventParticipantProvider(11)).stale, true);
  });
  scenario('registration requires explicit fresh personal read; prepare alone does not sign', (
    tester,
  ) async {
    watch();
    await tester.pump();
    expect(action().prepare(), null);
    expect(actions.calls, 0);
    await readParticipant();
    final approval = action().prepare();
    expect(approval, isNotNull);
    expect(actions.calls, 0);
    repository.registered = true;
    await action().confirm(approval!);
    expect(actions.calls, 1);
    expect(container.read(eventRegistrationProvider(11)).phase, EventRegistrationPhase.verified);
    expect(container.read(eventParticipantProvider(11)).snapshot!.value.registered, true);
    expect(identity.wallets, 0);
  });
  scenario('in-flight registration deduplicates repeated confirmations', (tester) async {
    watch();
    await tester.pump();
    await readParticipant();
    final approval = action().prepare()!;
    actions.gate = Completer();
    final pending = action().confirm(approval);
    await action().confirm(approval);
    expect(actions.calls, 1);
    actions.gate!.complete();
    await pending;
  });
  for (final phase in [EventRegistrationPhase.unknown, EventRegistrationPhase.acknowledged]) {
    scenario('$phase cannot resubmit until explicit status reconciliation', (tester) async {
      watch();
      await tester.pump();
      await readParticipant();
      final approval = action().prepare()!;
      if (phase == EventRegistrationPhase.unknown) {
        actions.failure = const EventRegistrationFailure(
          'eventRegistrationUnknown',
          mayHaveSent: true,
        );
      }
      actions.result = phase;
      await action().confirm(approval);
      expect(container.read(eventRegistrationProvider(11)).phase, phase);
      expect(action().prepare(), null);
      await action().confirm(approval);
      expect(actions.calls, 1);
      repository.registered = true;
      await action().reconcile();
      expect(container.read(eventRegistrationProvider(11)).phase, EventRegistrationPhase.verified);
    });
  }
  for (final next in <AuthIdentity?>[
    null,
    const AuthIdentity(
      id: 'other',
      walletAddress: pointsTestAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
    const AuthIdentity(
      id: 'events',
      walletAddress: '0x2222222222222222222222222222222222222222',
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
    const AuthIdentity(id: 'events', walletAddress: pointsTestAddress, signingAvailable: true),
  ]) {
    scenario(
      'wallet scope change clears participant and ignores late registration: ${next?.id}/${next?.walletKind}',
      (tester) async {
        watch();
        await tester.pump();
        await readParticipant();
        final approval = action().prepare()!;
        actions.gate = Completer();
        final pending = action().confirm(approval);
        identity.events.add(next);
        await tester.pump();
        actions.gate!.complete();
        await pending;
        expect(container.read(eventParticipantProvider(11)).snapshot, null);
        expect(container.read(eventRegistrationProvider(11)).phase, EventRegistrationPhase.idle);
        await action().confirm(approval);
        expect(actions.calls, 1);
        expect(identity.wallets, 0);
      },
    );
  }
  scenario('changed rules during confirmation require a new review', (tester) async {
    watch();
    await tester.pump();
    await readParticipant();
    final approval = action().prepare()!;
    repository.eventValue = mapTradingEvent({
      'event': eventPayload()..['rulesHtml'] = '<p>Changed rules</p>',
    }, eventId: 11);
    await container.read(tradingEventProvider(11).notifier).refresh();
    await action().confirm(approval);
    expect(actions.calls, 0);
    expect(container.read(eventRegistrationProvider(11)).failureKey, 'eventRegistrationChanged');
  });
  scenario('five-minute stale or missing signing capability prevents registration', (tester) async {
    watch();
    await tester.pump();
    await readParticipant();
    final approval = action().prepare()!;
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 5));
    await action().confirm(approval);
    expect(actions.calls, 0);
    await readParticipant();
    await container.read(tradingEventProvider(11).notifier).refresh();
    identity.events.add(
      const AuthIdentity(
        id: 'events',
        walletAddress: pointsTestAddress,
        walletKind: WalletKind.external,
      ),
    );
    await tester.pump();
    await readParticipant();
    expect(action().prepare(), null);
    expect(actions.calls, 0);
    expect(identity.wallets, 0);
  });
  scenario('unexpected failures never expose raw error content', (tester) async {
    watch();
    await tester.pump();
    await readParticipant();
    actions.failure = StateError('private sensitive body');
    await action().confirm(action().prepare()!);
    expect(container.read(eventRegistrationProvider(11)).failureKey, 'pointsUnavailable');
  });
  scenario('page disposal rejects pending registration completion and releases countdown timer', (
    tester,
  ) async {
    watch();
    listeners.add(container.listen(eventTimeProvider, (_, _) {}));
    await tester.pump();
    await readParticipant();
    final controller = action(), approval = controller.prepare()!;
    actions.gate = Completer();
    final pending = controller.confirm(approval);
    for (final l in listeners) {
      l.close();
    }
    listeners.clear();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(container.exists(eventRegistrationProvider(11)), false);
    expect(container.exists(eventTimeProvider), false);
    actions.gate!.complete();
    await pending;
    expect(tester.takeException(), null);
  });
}
