import '../../../core/errors/api_error_details.dart';
import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_message_signer.dart';
import '../data/event_registration_repository.dart';
import '../domain/event_registration.dart';
import '../domain/points.dart';
import 'points_provider.dart';
import 'trading_event_provider.dart';

final eventRegistrationRepositoryProvider = Provider.autoDispose<EventRegistrationRepository>((
  ref,
) {
  final repository = VantaEventRegistrationRepository(
    client: ref.watch(backendHttpPoolProvider).lease(),
    points: ref.watch(pointsRepositoryProvider),
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
final eventRegistrationProvider = NotifierProvider.autoDispose
    .family<EventRegistrationController, EventRegistrationState, int>(
      EventRegistrationController.new,
    );

class EventRegistrationController extends Notifier<EventRegistrationState> {
  EventRegistrationController(this.id);
  final int id;
  int _generation = 0;
  @override
  EventRegistrationState build() {
    ref.watch(eventRegistrationRepositoryProvider);
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
        state = const EventRegistrationState();
      },
    );
    ref.onDispose(() => _generation++);
    return const EventRegistrationState();
  }

  EventRegistrationApproval? prepare() {
    if (state.busy ||
        state.phase == EventRegistrationPhase.unknown ||
        state.phase == EventRegistrationPhase.acknowledged) {
      return null;
    }
    final identity = ref.read(authProvider).identity;
    final event = ref.read(tradingEventProvider(id)),
        participant = ref.read(eventParticipantProvider(id));
    final value = participant.snapshot?.value, data = event.snapshot?.value;
    if (identity == null || identity.walletAddress == null || !identity.signingAvailable) {
      state = const EventRegistrationState(failureKey: 'authWalletReconnect');
      return null;
    }
    if (data == null ||
        value == null ||
        event.stale ||
        participant.stale ||
        event.loading ||
        participant.loading ||
        !event.active ||
        !participant.active ||
        value.registered ||
        value.blockReason != null ||
        !data.canRegister(ref.read(pointsClockProvider)().toUtc())) {
      state = const EventRegistrationState(failureKey: 'eventRegistrationReadFirst');
      return null;
    }
    return EventRegistrationApproval(event: data, identity: identity);
  }

  Future<void> confirm(EventRegistrationApproval approval) async {
    if (state.busy ||
        state.phase == EventRegistrationPhase.unknown ||
        state.phase == EventRegistrationPhase.acknowledged) {
      return;
    }
    final fresh = prepare();
    if (fresh == null) return;
    if (fresh.identity.id != approval.identity.id ||
        fresh.identity.walletKind != approval.identity.walletKind ||
        fresh.identity.walletAddress?.toLowerCase() !=
            approval.identity.walletAddress?.toLowerCase() ||
        fresh.terms != approval.terms) {
      state = const EventRegistrationState(failureKey: 'eventRegistrationChanged');
      return;
    }
    final generation = ++_generation;
    bool current() => ref.mounted && generation == _generation;
    state = const EventRegistrationState(phase: EventRegistrationPhase.checking);
    try {
      final result = await ref
          .read(eventRegistrationRepositoryProvider)
          .register(
            approval,
            isCurrent: current,
            onStep: (phase) {
              if (current()) state = EventRegistrationState(phase: phase);
            },
          );
      if (!current()) return;
      state = EventRegistrationState(phase: result);
      await ref.read(eventParticipantProvider(id).notifier).refresh();
    } catch (error) {
      if (!current()) return;
      final key = error is AuthFailure
          ? error.key
          : error is PointsFailure
          ? error.key
          : error is EventRegistrationFailure
          ? error.key
          : null;
      state = EventRegistrationState(
        phase: error is EventRegistrationFailure && error.mayHaveSent
            ? EventRegistrationPhase.unknown
            : EventRegistrationPhase.idle,
        errorDetails: errorDetailsOf(error),
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
              'eventRegistrationUnknown',
            }.contains(key)
            ? key
            : 'pointsUnavailable',
      );
    }
  }

  Future<void> reconcile() async {
    if (state.busy) return;
    final generation = _generation;
    await ref.read(eventParticipantProvider(id).notifier).refresh();
    if (!ref.mounted || generation != _generation) return;
    final participant = ref.read(eventParticipantProvider(id));
    if (!participant.stale && participant.snapshot != null && participant.failureKey == null) {
      state = EventRegistrationState(
        phase: participant.snapshot!.value.registered
            ? EventRegistrationPhase.verified
            : EventRegistrationPhase.idle,
      );
    }
  }
}
