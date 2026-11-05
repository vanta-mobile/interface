import 'dart:async';

import 'package:vanta/features/points/data/trading_event_mapper.dart';
import 'package:vanta/features/points/domain/event_registration.dart';
import 'package:vanta/features/points/domain/trading_event.dart';
import 'package:vanta/features/points/domain/points.dart';

Map<String, dynamic> eventPayload({int id = 11, String status = 'ACTIVE'}) => {
  'id': id,
  'eventType': 'RETAIL',
  'name': 'Vanta Trading Carnival $id',
  'subtitle': 'Published event',
  'status': status,
  'startTime': '2026-11-01T00:00:00Z',
  'endTime': '2026-11-10T00:00:00Z',
  'orderlyBrokerId': 'vanta_exchange',
  'rulesHtml': '<h2>Campaign Rules</h2><p>Register before trading.</p><table><tr><th>Rank</th><th>Reward</th></tr><tr><td>#1</td><td>25,000 USDC</td></tr></table>',
  'headerImageUrl': '',
  'tasks': [
    {
      'metric': 'ownVolume',
      'threshold': '1000.000000000000000001',
      'name': 'Trading task',
      'taskTitle': 'Trade to share rewards',
      'description': 'Published task conditions',
      'buttonLabel': 'Trade Now',
      'buttonUrl': 'https://app.vanta.exchange/perp/PERP_BTC_USDC',
      'logoUrl': '',
    },
  ],
  'activityRules': [
    {'title': 'Eligibility', 'content': '<p>Only registered participants qualify.</p>'},
  ],
  'coreRewardPool': {
    'taskLabel': 'Task1',
    'rows': [
      {'rank': '#1', 'reward': '25,000 USDC'},
    ],
  },
  'whitelistTotalVolume': '243134683.03089294',
  'registrationCount': 132,
  'openForRegistrationAt': '2026-10-29T00:00:00Z',
};
TradingEvent tradingEventFixture({int id = 11, String status = 'ACTIVE'}) =>
    mapTradingEvent({'event': eventPayload(id: id, status: status)}, eventId: id);

class TestEventRegistrationRepository implements EventRegistrationRepository {
  int calls = 0;
  Completer<void>? gate;
  Object? failure;
  EventRegistrationPhase result = EventRegistrationPhase.verified;
  final approvals = <EventRegistrationApproval>[];
  @override
  Future<EventRegistrationPhase> register(
    EventRegistrationApproval approval, {
    required bool Function() isCurrent,
    required void Function(EventRegistrationPhase) onStep,
  }) async {
    calls++;
    approvals.add(approval);
    onStep(EventRegistrationPhase.signing);
    await gate?.future;
    if (failure case final e?) throw e;
    if (!isCurrent()) throw const PointsFailure('pointsUnavailable');
    return result;
  }
}
