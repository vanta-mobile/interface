import 'package:decimal/decimal.dart';

enum TradingEventType {
  retail,
  channel;

  String get api => name.toUpperCase();
}

class TradingEvent {
  TradingEvent({
    this.type = TradingEventType.retail,
    this.channelName,
    this.whitelistCount,
    required this.id,
    required this.name,
    required this.subtitle,
    required this.start,
    required this.end,
    required this.status,
    required this.broker,
    required this.rules,
    required Iterable<EventTask> tasks,
    required Iterable<EventRule> activityRules,
    required Iterable<EventReward> rewards,
    this.rewardTask = '',
    this.image,
    this.registrationOpens,
    this.registrationCount,
    this.volume,
  }) : tasks = List.unmodifiable(tasks),
       activityRules = List.unmodifiable(activityRules),
       rewards = List.unmodifiable(rewards);
  final TradingEventType type;
  final String? channelName;
  final int? whitelistCount;
  final int id;
  final String name, subtitle, status, broker, rewardTask;
  final DateTime start, end;
  final DateTime? registrationOpens;
  final int? registrationCount;
  final Decimal? volume;
  final Uri? image;
  final EventDocument rules;
  final List<EventTask> tasks;
  final List<EventRule> activityRules;
  final List<EventReward> rewards;
  bool get publishesRankings =>
      const {'OPEN_FOR_REGISTRATION', 'ACTIVE', 'ENDED', 'SETTLED'}.contains(status);
  bool get engagementTasks =>
      type == TradingEventType.channel &&
      tasks.any(
        (t) => const {'newUserTasks', 'dailyCheckIn', 'milestoneRewards'}.contains(t.metric),
      );
  bool activeAt(DateTime now) => status == 'ACTIVE' && !now.isBefore(start) && now.isBefore(end);
  bool canRegister(DateTime now) =>
      const {'OPEN_FOR_REGISTRATION', 'ACTIVE'}.contains(status) && now.isBefore(end);
}

class EventTask {
  const EventTask({
    required this.metric,
    required this.threshold,
    required this.name,
    required this.title,
    required this.description,
    required this.buttonLabel,
    this.buttonUrl,
    this.image,
    this.chainId,
    this.token,
    this.newUser,
    this.trackMetric,
    this.milestones = const [],
  });
  final int? chainId;
  final String? token, trackMetric;
  final EventNewUserTerms? newUser;
  final List<EventMilestone> milestones;
  final String metric, name, title, description, buttonLabel;
  final Decimal threshold;
  final Uri? buttonUrl, image;
}

class EventRule {
  const EventRule(this.title, this.document);
  final String title;
  final EventDocument document;
}

class EventReward {
  const EventReward(this.rank, this.reward);
  final String rank, reward;
}

enum EventBlockKind { paragraph, heading, listItem, table, image, link }

class EventBlock {
  EventBlock(this.kind, {this.text = '', this.url, Iterable<List<String>> rows = const []})
    : rows = List.unmodifiable(rows.map((r) => List<String>.unmodifiable(r)));
  final EventBlockKind kind;
  final String text;
  final Uri? url;
  final List<List<String>> rows;
}

class EventDocument {
  EventDocument(Iterable<EventBlock> blocks) : blocks = List.unmodifiable(blocks);
  final List<EventBlock> blocks;
}

class EventRanking {
  const EventRanking({required this.rank, required this.address, required this.volume});
  final int rank;
  final String address;
  final Decimal volume;
}

class EventLeaderboard {
  EventLeaderboard({
    required this.eventId,
    this.type = TradingEventType.retail,
    required Iterable<EventRanking> rows,
  }) : rows = List.unmodifiable(rows);
  final int eventId;
  final TradingEventType type;
  final List<EventRanking> rows;
}

class EventParticipant {
  EventParticipant({
    required this.eventId,
    required this.address,
    required this.registered,
    this.ownVolume,
    this.blockReason,
    this.conflictingEvent,
    this.networkVolume,
    this.qualifiedInviteeCount,
    this.networkActiveTraderCount,
    this.whitelistTotalVolume,
    Map<String, Decimal> depositProgress = const {},
  }) : depositProgress = Map.unmodifiable(depositProgress);
  final int eventId;
  final String address;
  final bool registered;
  final Decimal? ownVolume, networkVolume, whitelistTotalVolume;
  final int? qualifiedInviteeCount, networkActiveTraderCount;
  final Map<String, Decimal> depositProgress;
  final String? blockReason, conflictingEvent;
}

class EventNewUserTerms {
  const EventNewUserTerms({
    required this.registrationReward,
    required this.walletReward,
    required this.depositReward,
    required this.amount,
    required this.token,
    this.chainId,
  });
  final String registrationReward, walletReward, depositReward, token;
  final Decimal amount;
  final int? chainId;
}

class EventMilestone {
  const EventMilestone({
    required this.threshold,
    required this.description,
    required this.reward,
    this.completed,
    this.remaining,
  });
  final Decimal threshold;
  final String description, reward;
  final bool? completed;
  final Decimal? remaining;
}
