import 'package:decimal/decimal.dart';

import '../domain/event_engagement.dart';
import '../domain/points.dart';
import '../domain/trading_event.dart';
import 'points_mapper.dart';

bool? _flag(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value != null && value is! bool) throw const FormatException();
  return value as bool?;
}

String _day(Object? raw) {
  final value = pointsText(raw, max: 10);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) throw const FormatException();
  pointsTime('${value}T00:00:00Z');
  return value;
}

EventNewUserTerms mapEventNewUserTerms(Object? raw) {
  final row = pointsObject(raw), deposit = pointsObject(row['deposit']);
  return EventNewUserTerms(
    registrationReward: pointsText(
      pointsObject(row['completeRegistration'])['reward'] ?? '',
      empty: true,
    ),
    walletReward: pointsText(pointsObject(row['connectWallet'])['reward'] ?? '', empty: true),
    depositReward: pointsText(deposit['reward'] ?? '', empty: true),
    amount: pointsAmount(deposit['amount']),
    token: pointsText(deposit['token'], max: 64),
    chainId: deposit['chainId'] == null ? null : pointsPositiveInt(deposit['chainId']),
  );
}

List<EventMilestone> mapEventMilestones(Object? raw, {bool progress = false}) {
  if (raw == null) return const [];
  if (raw is! List || raw.length > 100) throw const FormatException();
  final result = <EventMilestone>[];
  Decimal? previous;
  for (final item in raw) {
    final row = pointsObject(item), threshold = pointsAmount(row['threshold']);
    if (previous != null && threshold <= previous) throw const FormatException();
    previous = threshold;
    result.add(
      EventMilestone(
        threshold: threshold,
        description: pointsText(row['description'] ?? '', empty: true, max: 8192),
        reward: pointsText(row['reward'] ?? '', empty: true),
        completed: progress ? _flag(row, 'completed') : null,
        remaining: progress ? pointsOptionalAmount(row, 'remaining') : null,
      ),
    );
  }
  return List.unmodifiable(result);
}

Map<String, Decimal> mapEventDepositProgress(Object? raw) {
  final row = pointsObject(raw);
  if (row.length > 100) throw const FormatException();
  return Map.unmodifiable(
    row.map((key, value) {
      if (!RegExp(r'^[1-9]\d{0,18}:[A-Za-z0-9_.-]{1,64}$').hasMatch(key)) {
        throw const FormatException();
      }
      return MapEntry(key, pointsAmount(value));
    }),
  );
}

EventTaskProgress mapEventTaskProgress(
  Object? raw, {
  required int eventId,
  required String address,
}) {
  if (!isPointsEvmAddress(address)) throw const FormatException();
  final row = pointsObject(raw);
  // Source binds this response by path. Validate echoed scope whenever supplied.
  if ((row['eventId'] != null && pointsPositiveInt(row['eventId']) != eventId) ||
      (row['address'] != null &&
          pointsAddressKey(pointsAddress(row['address'])) != address.toLowerCase())) {
    throw const FormatException();
  }
  EventNewUserProgress? newUser;
  EventDailyProgress? daily;
  EventMilestoneProgress? milestones;
  if (row['newUser'] != null) {
    final n = pointsObject(row['newUser']);
    final r = n['completeRegistration'] == null
        ? <String, dynamic>{}
        : pointsObject(n['completeRegistration']);
    final w = n['connectWallet'] == null ? <String, dynamic>{} : pointsObject(n['connectWallet']);
    final d = n['deposit'] == null ? <String, dynamic>{} : pointsObject(n['deposit']);
    newUser = EventNewUserProgress(
      registrationCompleted: _flag(r, 'completed'),
      walletCompleted: _flag(w, 'completed'),
      depositCompleted: _flag(d, 'completed'),
      required: pointsOptionalAmount(d, 'required'),
      current: pointsOptionalAmount(d, 'current'),
      remaining: pointsOptionalAmount(d, 'remaining'),
      chainId: d['chainId'] == null ? null : pointsPositiveInt(d['chainId']),
      token: d['token'] == null ? null : pointsText(d['token'], max: 64),
    );
  }
  if (row['dailyCheckIn'] != null) {
    final d = pointsObject(row['dailyCheckIn']), dates = d['checkedInDates'];
    if (dates is! List || dates.length > 3660) throw const FormatException();
    final days = dates.map(_day).toList();
    if (days.toSet().length != days.length) throw const FormatException();
    final today = _day(d['today']), flag = _flag(d, 'checkedInToday');
    if ((flag == true && !days.contains(today)) ||
        (flag == false && days.contains(today)) ||
        days.any((date) => date.compareTo(today) > 0)) {
      throw const FormatException();
    }
    daily = EventDailyProgress(
      today: today,
      dates: days,
      checkedIn: flag,
      target: pointsOptionalAmount(d, 'volumeTarget'),
      volume: pointsOptionalAmount(d, 'todayVolume'),
    );
  }
  if (row['milestones'] != null) {
    final m = pointsObject(row['milestones']);
    milestones = EventMilestoneProgress(
      current: pointsOptionalAmount(m, 'current'),
      items: mapEventMilestones(m['items'], progress: true),
    );
  }
  return EventTaskProgress(
    eventId: eventId,
    address: address.toLowerCase(),
    newUser: newUser,
    daily: daily,
    milestones: milestones,
  );
}
