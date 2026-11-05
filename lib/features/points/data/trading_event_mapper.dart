import '../../../core/exact_json.dart';
import '../domain/points.dart';
import '../domain/trading_event.dart';
import 'event_document_mapper.dart';
import 'event_engagement_mapper.dart';
import 'points_mapper.dart';

int _count(Object? raw) {
  final value = raw is FundingJsonNumber
      ? raw.integer
      : raw is int
      ? raw
      : null;
  if (value == null || value < 0 || value > 9223372036854775807) throw const FormatException();
  return value;
}

List<dynamic> _list(Object? raw, int max) {
  if (raw is! List || raw.length > max) throw const FormatException();
  return raw;
}

TradingEvent _event(Object? raw) {
  final row = pointsObject(raw);
  final type = TradingEventType.values.where((t) => t.api == row['eventType']).firstOrNull;
  if (type == null) throw const FormatException();
  final start = pointsTime(row['startTime']), end = pointsTime(row['endTime']);
  if (!end.isAfter(start)) throw const FormatException();
  final tasks = <EventTask>[];
  for (final task in _list(row['tasks'], 100)) {
    final t = pointsObject(task);
    final buttonUrl = eventLink(t['buttonUrl']);
    if (t['buttonUrl'] != null && t['buttonUrl'] != '' && buttonUrl == null) {
      throw const FormatException();
    }
    tasks.add(
      EventTask(
        metric: pointsText(t['metric'], max: 128),
        chainId: t['chainId'] == null ? null : pointsPositiveInt(t['chainId']),
        token: t['token'] == null ? null : pointsText(t['token'], max: 64),
        newUser: t['newUser'] == null ? null : mapEventNewUserTerms(t['newUser']),
        trackMetric: t['trackMetric'] == null ? null : pointsText(t['trackMetric'], max: 128),
        milestones: mapEventMilestones(t['milestones']),
        threshold: pointsAmount(t['threshold']),
        name: pointsText(t['name'] ?? '', empty: true),
        title: pointsText(t['taskTitle'] ?? '', empty: true),
        description: pointsText(t['description'] ?? '', max: 8192, empty: true),
        buttonLabel: pointsText(t['buttonLabel'] ?? '', empty: true),
        buttonUrl: buttonUrl,
        image: eventLink(t['logoUrl'], image: true),
      ),
    );
  }
  final rules = <EventRule>[];
  for (final raw in _list(row['activityRules'] ?? const [], 100)) {
    final rule = pointsObject(raw);
    rules.add(EventRule(pointsText(rule['title'], empty: true), mapEventDocument(rule['content'])));
  }
  final reward = row['coreRewardPool'] == null
      ? <String, dynamic>{}
      : pointsObject(row['coreRewardPool']);
  final rewards = <EventReward>[];
  for (final raw in _list(reward['rows'] ?? const [], 200)) {
    final r = pointsObject(raw);
    rewards.add(EventReward(pointsText(r['rank']), pointsText(r['reward'])));
  }
  return TradingEvent(
    type: type,
    channelName: row['channelName'] == null ? null : pointsText(row['channelName'], empty: true),
    whitelistCount: row['whitelistCount'] == null ? null : _count(row['whitelistCount']),
    id: pointsPositiveInt(row['id']),
    name: pointsText(row['name']),
    subtitle: pointsText(row['subtitle'] ?? '', max: 8192, empty: true),
    start: start,
    end: end,
    status: pointsText(row['status'], max: 64),
    broker: pointsText(row['orderlyBrokerId'], max: 128),
    rules: mapEventDocument(row['rulesHtml']),
    tasks: tasks,
    activityRules: rules,
    rewards: rewards,
    rewardTask: pointsText(reward['taskLabel'] ?? '', empty: true),
    image: eventLink(row['headerImageUrl'], image: true),
    registrationOpens: row['openForRegistrationAt'] == null
        ? null
        : pointsTime(row['openForRegistrationAt']),
    registrationCount: row['registrationCount'] == null ? null : _count(row['registrationCount']),
    volume: pointsOptionalAmount(row, 'whitelistTotalVolume'),
  );
}

List<TradingEvent> mapTradingEvents(
  Object? payload, {
  TradingEventType type = TradingEventType.retail,
}) {
  final rows = _list(pointsObject(payload)['items'], 1000),
      ids = <int>{},
      events = <TradingEvent>[];
  for (final raw in rows) {
    final event = _event(raw);
    if (event.type != type || !ids.add(event.id)) throw const FormatException();
    events.add(event);
  }
  return List.unmodifiable(events);
}

TradingEvent mapTradingEvent(Object? payload, {required int eventId}) {
  final event = _event(pointsObject(payload)['event']);
  if (event.id != eventId) throw const FormatException();
  return event;
}

EventLeaderboard mapEventLeaderboard(
  Object? payload, {
  required int eventId,
  TradingEventType type = TradingEventType.retail,
}) {
  final row = pointsObject(payload), addresses = <String>{};
  if (pointsPositiveInt(row['eventId']) != eventId || row['eventType'] != type.api) {
    throw const FormatException();
  }
  final rows = <EventRanking>[];
  for (final raw in _list(row['rows'], 1000)) {
    final r = pointsObject(raw), address = pointsAddress(r['address']);
    if (!addresses.add(pointsAddressKey(address))) throw const FormatException();
    rows.add(
      EventRanking(
        rank: pointsPositiveInt(r['rank']),
        address: address,
        volume: pointsAmount(r['volume']),
      ),
    );
  }
  return EventLeaderboard(
    eventId: eventId,
    type: type,
    rows: rows.take(type == TradingEventType.channel ? 10 : 30),
  );
}

EventParticipant mapEventParticipant(
  Object? payload, {
  required int eventId,
  required String address,
}) {
  if (!isPointsEvmAddress(address)) throw const FormatException();
  final row = pointsObject(payload);
  if ((row['eventId'] != null && pointsPositiveInt(row['eventId']) != eventId) ||
      (row['address'] != null &&
          pointsAddressKey(pointsAddress(row['address'])) != pointsAddressKey(address)) ||
      row['registered'] is! bool) {
    throw const FormatException();
  }
  final registered = row['registered'] as bool;
  final stats = row['stats'] == null ? null : pointsObject(row['stats']);
  final block = !registered && row['registrationBlock'] != null
      ? pointsObject(row['registrationBlock'])
      : null;
  return EventParticipant(
    eventId: eventId,
    address: address.toLowerCase(),
    registered: registered,
    ownVolume: registered && stats != null ? pointsOptionalAmount(stats, 'ownVolume') : null,
    networkVolume: registered && stats != null
        ? pointsOptionalAmount(stats, 'networkVolume')
        : null,
    whitelistTotalVolume: registered && stats != null
        ? pointsOptionalAmount(stats, 'whitelistTotalVolume')
        : null,
    qualifiedInviteeCount: registered && stats?['qualifiedInviteeCount'] != null
        ? _count(stats!['qualifiedInviteeCount'])
        : null,
    networkActiveTraderCount: registered && stats?['networkActiveTraderCount'] != null
        ? _count(stats!['networkActiveTraderCount'])
        : null,
    depositProgress: registered && stats?['depositProgress'] != null
        ? mapEventDepositProgress(stats!['depositProgress'])
        : const {},
    blockReason: block == null ? null : pointsText(block['reason'], max: 128),
    conflictingEvent: block?['conflictingEventName'] == null
        ? null
        : pointsText(block!['conflictingEventName']),
  );
}
