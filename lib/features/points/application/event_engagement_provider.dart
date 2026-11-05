import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_message_signer.dart';
import '../data/event_engagement_journal.dart';
import '../data/event_engagement_repository.dart';
import '../domain/event_engagement.dart';
import '../domain/event_registration.dart';
import '../domain/points.dart';
import 'points_provider.dart';
import 'trading_event_provider.dart';

final eventEngagementJournalProvider = Provider<EventEngagementJournal>(
  (ref) => LocalEventEngagementJournal(),
);
final eventEngagementRepositoryProvider = Provider<EventEngagementRepository>((ref) {
  final repository = VantaEventEngagementRepository(
    points: ref.watch(pointsRepositoryProvider),
    journal: ref.watch(eventEngagementJournalProvider),
    now: ref.watch(pointsClockProvider),
    signer: () {
      final identity = ref.read(identityRepositoryProvider);
      if (identity is! WalletMessageSigner) throw const AuthFailure('authWalletUnavailable');
      return identity as WalletMessageSigner;
    },
  );
  ref.onDispose(repository.close);
  return repository;
});
final eventEngagementProvider = NotifierProvider.autoDispose
    .family<EventEngagementController, EventEngagementState, int>(EventEngagementController.new);

class EventEngagementController extends Notifier<EventEngagementState> {
  EventEngagementController(this.id);
  final int id;
  int _generation = 0;
  @override
  EventEngagementState build() {
    ref.watch(eventEngagementRepositoryProvider);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress?.toLowerCase(),
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (_, _) {
        _generation++;
        state = const EventEngagementState();
      },
    );
    ref.onDispose(() => _generation++);
    return const EventEngagementState();
  }

  EventEngagementApproval? prepare(EventEngagementAction action) {
    if (state.busy || state.locked) return null;
    final identity = ref.read(authProvider).identity;
    final e = ref.read(tradingEventProvider(id)),
        p = ref.read(eventParticipantProvider(id)),
        t = ref.read(eventTaskProgressProvider(id));
    final now = ref.read(pointsClockProvider)().toUtc();
    if (identity == null || identity.walletAddress == null || !identity.signingAvailable) {
      state = const EventEngagementState(failureKey: 'authWalletReconnect');
      return null;
    }
    if (e.snapshot == null ||
        p.snapshot == null ||
        t.snapshot == null ||
        e.stale ||
        p.stale ||
        t.stale ||
        e.loading ||
        p.loading ||
        t.loading ||
        !e.active ||
        !p.active ||
        !t.active ||
        p.snapshot!.value.address.toLowerCase() != identity.walletAddress!.toLowerCase() ||
        !engagementEligible(e.snapshot!.value, p.snapshot!.value, t.snapshot!.value, action, now)) {
      state = const EventEngagementState(failureKey: 'eventEngagementReadFirst');
      return null;
    }
    return EventEngagementApproval(
      event: e.snapshot!.value,
      identity: identity,
      action: action,
      day: eventUtcDay(now),
    );
  }

  Future<void> confirm(EventEngagementApproval approval) async {
    final fresh = prepare(approval.action);
    if (fresh == null) return;
    if (fresh.identity.id != approval.identity.id ||
        fresh.identity.walletKind != approval.identity.walletKind ||
        fresh.identity.walletAddress?.toLowerCase() !=
            approval.identity.walletAddress?.toLowerCase() ||
        fresh.terms != approval.terms ||
        fresh.day != approval.day) {
      state = const EventEngagementState(failureKey: 'eventRegistrationChanged');
      return;
    }
    final generation = ++_generation;
    bool current() => ref.mounted && generation == _generation;
    state = EventEngagementState(phase: EventRegistrationPhase.checking, action: approval.action);
    try {
      final result = await ref
          .read(eventEngagementRepositoryProvider)
          .submit(
            approval,
            isCurrent: current,
            onStep: (phase) {
              if (current()) state = EventEngagementState(phase: phase, action: approval.action);
            },
          );
      if (!current()) return;
      state = EventEngagementState(phase: result, action: approval.action);
      await ref.read(eventTaskProgressProvider(id).notifier).refresh();
    } catch (error) {
      if (!current()) return;
      final key = error is AuthFailure
          ? error.key
          : error is PointsFailure
          ? error.key
          : error is EventRegistrationFailure
          ? error.key
          : 'pointsUnavailable';
      state = EventEngagementState(
        phase: error is EventRegistrationFailure && error.mayHaveSent
            ? EventRegistrationPhase.unknown
            : EventRegistrationPhase.idle,
        action: approval.action,
        failureKey:
            const {
              'authWalletReconnect',
              'authWalletChanged',
              'authWalletRejected',
              'authWalletUnavailable',
              'authWalletSignature',
              'pointsNetwork',
              'pointsDataInvalid',
              'pointsRateLimited',
              'eventRegistrationChanged',
              'eventEngagementUnknown',
              'eventEngagementIneligible',
              'eventEngagementStorage',
              'eventEngagementBusy',
            }.contains(key)
            ? key
            : 'pointsUnavailable',
      );
    }
  }

  Future<void> reconcile() async {
    if (state.busy) return;
    final identity = ref.read(authProvider).identity,
        address = ref.read(authProvider).identity?.walletAddress;
    if (identity == null || address == null) {
      await ref.read(eventTaskProgressProvider(id).notifier).refresh();
      return;
    }
    final generation = ++_generation, previous = state;
    state = EventEngagementState(phase: EventRegistrationPhase.checking, action: previous.action);
    try {
      final clear = await ref
          .read(eventEngagementRepositoryProvider)
          .reconcile(eventId: id, address: address);
      if (!ref.mounted || generation != _generation) return;
      await ref.read(eventTaskProgressProvider(id).notifier).refresh();
      if (!ref.mounted || generation != _generation) return;
      state = EventEngagementState(
        phase: clear ? EventRegistrationPhase.idle : EventRegistrationPhase.unknown,
        action: previous.action,
        failureKey: clear ? null : 'eventEngagementUnknown',
      );
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = EventEngagementState(
          phase: previous.locked ? previous.phase : EventRegistrationPhase.idle,
          action: previous.action,
          failureKey: 'eventEngagementReconcileFailed',
        );
      }
    }
  }
}
