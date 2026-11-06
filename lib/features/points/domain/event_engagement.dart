import '../../../core/errors/api_error_details.dart';

import 'package:decimal/decimal.dart';

import '../../auth/domain/auth_session.dart';
import 'event_registration.dart';
import 'trading_event.dart';

class EventNewUserProgress {
  const EventNewUserProgress({
    this.registrationCompleted,
    this.walletCompleted,
    this.depositCompleted,
    this.required,
    this.current,
    this.remaining,
    this.chainId,
    this.token,
  });
  final bool? registrationCompleted, walletCompleted, depositCompleted;
  final Decimal? required, current, remaining;
  final int? chainId;
  final String? token;
}

class EventDailyProgress {
  EventDailyProgress({
    required this.today,
    required Iterable<String> dates,
    this.checkedIn,
    this.target,
    this.volume,
  }) : dates = List.unmodifiable(dates);
  final String today;
  final List<String> dates;
  final bool? checkedIn;
  final Decimal? target, volume;
}

class EventMilestoneProgress {
  EventMilestoneProgress({this.current, required Iterable<EventMilestone> items})
    : items = List.unmodifiable(items);
  final Decimal? current;
  final List<EventMilestone> items;
}

class EventTaskProgress {
  const EventTaskProgress({
    required this.eventId,
    required this.address,
    this.newUser,
    this.daily,
    this.milestones,
  });
  final int eventId;
  final String address;
  final EventNewUserProgress? newUser;
  final EventDailyProgress? daily;
  final EventMilestoneProgress? milestones;
}

enum EventEngagementAction {
  walletConnect,
  checkIn;

  String get path => this == walletConnect ? 'wallet-connect' : 'check-in';
}

String eventUtcDay(DateTime now) => now.toUtc().toIso8601String().substring(0, 10);
bool engagementCompleted(EventTaskProgress progress, EventEngagementAction action, String day) =>
    action == EventEngagementAction.walletConnect
    ? progress.newUser?.walletCompleted == true
    : progress.daily?.today == day &&
          progress.daily?.checkedIn == true &&
          progress.daily!.dates.contains(day);

bool engagementEligible(
  TradingEvent event,
  EventParticipant participant,
  EventTaskProgress progress,
  EventEngagementAction action,
  DateTime now,
) {
  if (event.type != TradingEventType.channel ||
      !event.activeAt(now) ||
      participant.eventId != event.id ||
      !participant.registered ||
      participant.blockReason != null ||
      progress.eventId != event.id ||
      progress.address.toLowerCase() != participant.address.toLowerCase()) {
    return false;
  }
  if (action == EventEngagementAction.walletConnect) {
    return event.tasks.any((t) => t.metric == 'newUserTasks') &&
        progress.newUser?.registrationCompleted == true &&
        progress.newUser?.walletCompleted == false;
  }
  if (!event.tasks.any((t) => t.metric == 'dailyCheckIn')) return false;
  final daily = progress.daily;
  return daily != null &&
      daily.today == eventUtcDay(now) &&
      daily.checkedIn == false &&
      !daily.dates.contains(daily.today) &&
      daily.volume != null &&
      daily.target != null &&
      daily.volume! >= daily.target!;
}

class EventEngagementApproval {
  EventEngagementApproval({
    required this.event,
    required this.identity,
    required this.action,
    required this.day,
  }) : terms = registrationTerms(event);
  final TradingEvent event;
  final AuthIdentity identity;
  final EventEngagementAction action;
  final String day, terms;
}

class EventEngagementState {
  const EventEngagementState({
    this.phase = EventRegistrationPhase.idle,
    this.action,
    this.failureKey,
    this.errorDetails,
  });
  final EventRegistrationPhase phase;
  final EventEngagementAction? action;
  final ApiErrorDetails? errorDetails;
  final String? failureKey;
  bool get busy => const {
    EventRegistrationPhase.checking,
    EventRegistrationPhase.signing,
    EventRegistrationPhase.sending,
  }.contains(phase);
  bool get locked =>
      const {EventRegistrationPhase.unknown, EventRegistrationPhase.acknowledged}.contains(phase);
}

abstract interface class EventEngagementRepository {
  Future<EventRegistrationPhase> submit(
    EventEngagementApproval approval, {
    required bool Function() isCurrent,
    required void Function(EventRegistrationPhase) onStep,
  });
  Future<bool> reconcile({required int eventId, required String address});
}
