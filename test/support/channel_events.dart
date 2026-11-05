import 'dart:async';

import 'package:vanta/features/points/data/event_engagement_journal.dart';
import 'package:vanta/features/points/data/event_engagement_mapper.dart';
import 'package:vanta/features/points/data/trading_event_mapper.dart';
import 'package:vanta/features/points/domain/event_engagement.dart';
import 'package:vanta/features/points/domain/event_registration.dart';
import 'package:vanta/features/points/domain/trading_event.dart';

import 'points.dart';
import 'trading_events.dart';

Map<String, dynamic> channelEventPayload({int id = 17, String status = 'ACTIVE'}) =>
    eventPayload(id: id, status: status)..addAll({
      'eventType': 'CHANNEL',
      'channelName': 'Community',
      'whitelistCount': 0,
      'tasks': <Object?>[
        {
          'metric': 'newUserTasks',
          'threshold': '0',
          'name': 'New user rewards',
          'taskTitle': 'New user tasks',
          'description': 'Register, connect and deposit on Vanta',
          'buttonUrl': 'https://app.vanta.exchange/portfolio',
          'newUser': {
            'completeRegistration': {'reward': '1 USDC'},
            'connectWallet': {'reward': '1 USDC'},
            'deposit': {'amount': '100.000000000000000001', 'token': 'USDC', 'reward': '1 USDC'},
          },
        },
        {
          'metric': 'dailyCheckIn',
          'threshold': '1000.000000000000000001',
          'name': 'Daily reward',
          'taskTitle': 'Daily check-in',
          'description': 'Reach daily volume on Vanta',
        },
        {
          'metric': 'milestoneRewards',
          'threshold': '0',
          'name': 'Milestone rewards',
          'trackMetric': 'ownVolume',
          'milestones': <Object?>[
            {'threshold': '100000', 'reward': '10 USDC', 'description': 'First tier'},
            {'threshold': '200000', 'reward': '20 USDC', 'description': 'Second tier'},
          ],
        },
      ],
    });
TradingEvent channelEventFixture({int id = 17, String status = 'ACTIVE'}) =>
    mapTradingEvent({'event': channelEventPayload(id: id, status: status)}, eventId: id);
Map<String, dynamic> taskProgressPayload({
  String today = '2026-11-04',
  bool wallet = false,
  bool checked = false,
}) => {
  'eventId': 17,
  'address': pointsTestAddress,
  'newUser': {
    'completeRegistration': {'completed': true},
    'connectWallet': {'completed': wallet},
    'deposit': {
      'completed': false,
      'required': '100.000000000000000001',
      'current': '1.000000000000000001',
      'remaining': '99',
      'chainId': 42161,
      'token': 'USDC',
    },
  },
  'dailyCheckIn': <String, dynamic>{
    'today': today,
    'checkedInToday': checked,
    'checkedInDates': checked ? [today] : <Object?>[],
    'volumeTarget': '1000.000000000000000001',
    'todayVolume': '1000.000000000000000002',
  },
  'milestones': {
    'current': '100000.000000000000000001',
    'items': <Object?>[
      {'threshold': '100000', 'reward': '10 USDC', 'completed': true, 'remaining': '0'},
      {
        'threshold': '200000',
        'reward': '20 USDC',
        'completed': false,
        'remaining': '99999.999999999999999999',
      },
    ],
  },
};
EventTaskProgress taskProgressFixture({
  bool wallet = false,
  bool checked = false,
  String today = '2026-11-04',
}) => mapEventTaskProgress(
  taskProgressPayload(wallet: wallet, checked: checked, today: today),
  eventId: 17,
  address: pointsTestAddress,
);

class MemoryEventEngagementJournal implements EventEngagementJournal {
  final entries = <PendingEventEngagement>[];
  bool failRead = false, failAdd = false, failRemove = false;
  Completer<void>? addGate;
  @override
  Future<List<PendingEventEngagement>> read() async {
    if (failRead) throw const FormatException();
    return List.of(entries);
  }

  @override
  Future<void> add(PendingEventEngagement e) async {
    await addGate?.future;
    if (failAdd || entries.any((p) => p.eventId == e.eventId && p.address == e.address)) {
      throw const FormatException();
    }
    entries.add(e);
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove) throw const FormatException();
    entries.removeWhere((e) => e.key == key);
  }
}

class TestEventEngagementRepository implements EventEngagementRepository {
  final approvals = <EventEngagementApproval>[];
  Completer<void>? gate;
  Object? failure;
  bool clear = true;
  int queries = 0;
  EventRegistrationPhase result = EventRegistrationPhase.verified;
  @override
  Future<EventRegistrationPhase> submit(
    EventEngagementApproval approval, {
    required bool Function() isCurrent,
    required void Function(EventRegistrationPhase) onStep,
  }) async {
    approvals.add(approval);
    onStep(EventRegistrationPhase.signing);
    await gate?.future;
    if (failure case final e?) throw e;
    return result;
  }

  @override
  Future<bool> reconcile({required int eventId, required String address}) async {
    queries++;
    if (failure case final e?) throw e;
    return clear;
  }
}
