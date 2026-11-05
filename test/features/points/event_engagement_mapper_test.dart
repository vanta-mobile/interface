import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/exact_json.dart';
import 'package:vanta/features/points/data/event_engagement_mapper.dart';
import 'package:vanta/features/points/data/trading_event_mapper.dart';
import 'package:vanta/features/points/domain/event_engagement.dart';
import 'package:vanta/features/points/domain/event_registration.dart';
import 'package:vanta/features/points/domain/trading_event.dart';

import '../../support/channel_events.dart';
import '../../support/points.dart';

void main() {
  test('channel terms preserve exact deposit, tiers and distinct venue/type', () {
    final event = channelEventFixture();
    expect(event.type, TradingEventType.channel);
    expect(event.engagementTasks, true);
    expect(event.tasks.first.newUser!.amount.toString(), '100.000000000000000001');
    expect(event.tasks.last.milestones.map((e) => e.threshold.toString()), ['100000', '200000']);
    expect(() => event.tasks.last.milestones.clear(), throwsUnsupportedError);
    expect(event.channelName, 'Community');
    expect(event.whitelistCount, 0);
  });
  test('channel list binds type instead of accepting retail into channel source', () {
    final raw = {
      'items': [channelEventPayload()],
    };
    expect(() => mapTradingEvents(raw), throwsFormatException);
    expect(mapTradingEvents(raw, type: TradingEventType.channel).single.id, 17);
  });
  test('source state ACTIVE does not override elapsed period or future start', () {
    final event = channelEventFixture();
    expect(event.activeAt(event.end), false);
    expect(event.activeAt(event.start.subtract(const Duration(seconds: 1))), false);
    expect(event.activeAt(event.start), true);
  });
  test('every engagement and venue rule is included in confirmation fingerprint', () {
    final original = registrationTerms(channelEventFixture());
    for (final change in <void Function(Map<String, dynamic>)>[
      (r) => r['channelName'] = 'Changed',
      (r) => r['whitelistCount'] = 1,
      (r) => ((r['tasks'] as List).first['newUser']['deposit'] as Map)['amount'] = '101',
      (r) => ((r['tasks'] as List).last['milestones'] as List).first['reward'] = 'Changed',
      (r) => (r['tasks'] as List).last['trackMetric'] = 'totalVolume',
    ]) {
      final raw = channelEventPayload();
      change(raw);
      expect(registrationTerms(mapTradingEvent({'event': raw}, eventId: 17)), isNot(original));
    }
  });
  test('task progress is scoped immutable and exact; absent fields remain unknown', () {
    final p = taskProgressFixture();
    expect(p.address, pointsTestAddress);
    expect(p.newUser!.current.toString(), '1.000000000000000001');
    expect(p.daily!.volume.toString(), '1000.000000000000000002');
    expect(p.milestones!.items.last.remaining.toString(), '99999.999999999999999999');
    expect(() => p.daily!.dates.add('2026-11-05'), throwsUnsupportedError);
    expect(() => p.milestones!.items.clear(), throwsUnsupportedError);
    final empty = mapEventTaskProgress(
      <String, dynamic>{},
      eventId: 17,
      address: pointsTestAddress,
    );
    expect(empty.newUser, null);
    expect(empty.daily, null);
    expect(empty.milestones, null);
  });
  test('personal echoed event or address mismatch rejected', () {
    for (final pair in [
      ('eventId', 18),
      ('address', '0x2222222222222222222222222222222222222222'),
    ]) {
      final raw = taskProgressPayload()..[pair.$1] = pair.$2;
      expect(
        () => mapEventTaskProgress(raw, eventId: 17, address: pointsTestAddress),
        throwsFormatException,
      );
    }
  });
  for (final pair in <(String, Object?)>[
    ('checkedInToday', 'false'),
    ('today', '2026-02-30'),
    ('today', '2026-11-04T00:00:00Z'),
    ('checkedInDates', ['2026-11-03', '2026-11-03']),
    ('checkedInDates', ['2026-11-05']),
    ('checkedInDates', null),
    ('todayVolume', -1),
    ('volumeTarget', 'NaN'),
  ]) {
    test('invalid daily field ${pair.$1}/${pair.$2} cannot enable action', () {
      final raw = taskProgressPayload();
      (raw['dailyCheckIn'] as Map)[pair.$1] = pair.$2;
      expect(
        () => mapEventTaskProgress(raw, eventId: 17, address: pointsTestAddress),
        throwsFormatException,
      );
    });
  }
  test('checked flag and dates must agree', () {
    for (final flag in [false, true]) {
      final raw = taskProgressPayload(checked: flag);
      (raw['dailyCheckIn'] as Map)['checkedInDates'] = flag ? <Object?>[] : ['2026-11-04'];
      expect(
        () => mapEventTaskProgress(raw, eventId: 17, address: pointsTestAddress),
        throwsFormatException,
      );
    }
  });
  test(
    'milestones reject duplicate or unsorted thresholds; optional missing completion stays unknown',
    () {
      final raw = [
        {'threshold': '1', 'reward': 'A'},
        {'threshold': '1', 'reward': 'B'},
      ];
      expect(() => mapEventMilestones(raw), throwsFormatException);
      expect(
        mapEventMilestones([
          {'threshold': '1'},
        ], progress: true).single.completed,
        null,
      );
    },
  );
  test('unknown flags and amounts never turn into false or zero', () {
    final p = mapEventTaskProgress(
      <String, dynamic>{
        'newUser': <String, dynamic>{'connectWallet': <String, dynamic>{}},
        'dailyCheckIn': <String, dynamic>{'today': '2026-11-04', 'checkedInDates': <Object?>[]},
      },
      eventId: 17,
      address: pointsTestAddress,
    );
    expect(p.newUser!.walletCompleted, null);
    expect(p.daily!.volume, null);
    expect(p.daily!.checkedIn, null);
  });
  test(
    'daily eligibility requires server day and exact target; wallet requires server registration',
    () {
      final e = channelEventFixture(),
          p = EventParticipant(eventId: 17, address: pointsTestAddress, registered: true),
          t = taskProgressFixture(),
          now = DateTime.utc(2026, 11, 4);
      expect(engagementEligible(e, p, t, EventEngagementAction.checkIn, now), true);
      expect(engagementEligible(e, p, t, EventEngagementAction.walletConnect, now), true);
      expect(
        engagementEligible(
          e,
          p,
          t,
          EventEngagementAction.checkIn,
          now.add(const Duration(days: 1)),
        ),
        false,
      );
      expect(
        engagementEligible(
          e,
          EventParticipant(eventId: 17, address: pointsTestAddress, registered: false),
          t,
          EventEngagementAction.walletConnect,
          now,
        ),
        false,
      );
      expect(
        engagementEligible(
          e,
          p,
          taskProgressFixture(checked: true),
          EventEngagementAction.checkIn,
          now,
        ),
        false,
      );
    },
  );
  test('channel ranking binds type and caps10 only after validating rows', () {
    final rows = List.generate(
      11,
      (i) => {
        'rank': i + 1,
        'address': '0x${(i + 1).toRadixString(16).padLeft(40, '0')}',
        'volume': '123.000000000000000001',
      },
    );
    final raw = {'eventId': 17, 'eventType': 'CHANNEL', 'rows': rows};
    expect(mapEventLeaderboard(raw, eventId: 17, type: TradingEventType.channel).rows.length, 10);
    expect(() => mapEventLeaderboard(raw, eventId: 17), throwsFormatException);
    rows.last['address'] = rows.first['address']!;
    expect(
      () => mapEventLeaderboard(raw, eventId: 17, type: TradingEventType.channel),
      throwsFormatException,
    );
  });
  test('deposit progress preserves decimal and rejects malformed chain/token keys', () {
    final p = mapEventDepositProgress({'42161:USDC': '1.000000000000000001'});
    expect(p.values.single.toString(), '1.000000000000000001');
    expect(() => p.clear(), throwsUnsupportedError);
    expect(() => mapEventDepositProgress({'42161:USDC:evil': '1'}), throwsFormatException);
  });
  test('numeric source token mapping remains exact', () {
    final raw = jsonEncode(taskProgressPayload())
        .replaceFirst('"1000.000000000000000002"', '1000.000000000000000002');
    expect(
      mapEventTaskProgress(
        decodeFundingJson(raw),
        eventId: 17,
        address: pointsTestAddress,
      ).daily!.volume.toString(),
      '1000.000000000000000002',
    );
  });
}
