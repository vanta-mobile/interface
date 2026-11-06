import '../../../core/errors/api_error_details.dart';

import 'dart:convert';

import '../../auth/domain/auth_session.dart';
import 'trading_event.dart';

String registrationTerms(TradingEvent e) => jsonEncode([
  e.id,
  e.type.api,
  e.channelName,
  e.whitelistCount,
  e.name,
  e.broker,
  e.start.toIso8601String(),
  e.end.toIso8601String(),
  e.rules.blocks.map((b) => [b.kind.name, b.text, b.url?.toString(), b.rows]).toList(),
  e.activityRules
      .map(
        (r) => [
          r.title,
          r.document.blocks.map((b) => [b.kind.name, b.text, b.url?.toString(), b.rows]).toList(),
        ],
      )
      .toList(),
  e.tasks
      .map(
        (t) => [
          t.metric,
          t.threshold.toString(),
          t.name,
          t.title,
          t.description,
          t.buttonUrl?.toString(),
          t.chainId,
          t.token,
          t.trackMetric,
          if (t.newUser case final n?)
            [
              n.registrationReward,
              n.walletReward,
              n.depositReward,
              n.amount.toString(),
              n.token,
              n.chainId,
            ],
          t.milestones.map((m) => [m.threshold.toString(), m.description, m.reward]).toList(),
        ],
      )
      .toList(),
  e.rewards.map((r) => [r.rank, r.reward]).toList(),
]);

class EventRegistrationApproval {
  EventRegistrationApproval({required this.event, required this.identity})
    : terms = registrationTerms(event);
  final TradingEvent event;
  final AuthIdentity identity;
  final String terms;
}

enum EventRegistrationPhase { idle, checking, signing, sending, verified, acknowledged, unknown }

class EventRegistrationState {
  const EventRegistrationState({
    this.phase = EventRegistrationPhase.idle,
    this.failureKey,
    this.errorDetails,
  });
  final EventRegistrationPhase phase;
  final ApiErrorDetails? errorDetails;
  final String? failureKey;
  bool get busy => const {
    EventRegistrationPhase.checking,
    EventRegistrationPhase.signing,
    EventRegistrationPhase.sending,
  }.contains(phase);
}

class EventRegistrationFailure implements Exception, DetailedApiFailure {
  const EventRegistrationFailure(this.key, {this.mayHaveSent = false, this.details});
  @override
  final ApiErrorDetails? details;
  final String key;
  final bool mayHaveSent;
}

abstract interface class EventRegistrationRepository {
  Future<EventRegistrationPhase> register(
    EventRegistrationApproval approval, {
    required bool Function() isCurrent,
    required void Function(EventRegistrationPhase) onStep,
  });
}
