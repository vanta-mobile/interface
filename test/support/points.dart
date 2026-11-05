import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/points/domain/points.dart';
import 'package:vanta/features/points/domain/trading_event.dart';

import 'trading_events.dart';

import 'package:vanta/features/points/domain/event_engagement.dart';

const pointsIdentity = AuthIdentity(
  id: 'points-test',
  walletAddress: pointsTestAddress,
  walletKind: WalletKind.external,
);

const pointsTestAddress = '0x1111111111111111111111111111111111111111';
PointsCampaign pointsCampaignFixture(int number, {bool current = false}) => PointsCampaign(
  number: number,
  name: 'Vanta campaign $number',
  pool: Decimal.fromInt(1000000),
  start: DateTime.utc(2026, 10, 29),
  end: DateTime.utc(2026, 11, 5),
  status: current ? 'ACTIVE' : 'SETTLED',
  current: current,
  broker: 'vanta_exchange',
);
List<PointsRanking> pointsRankingsFixture({int count = 25, int? campaign}) => List.generate(
  count,
  (i) => PointsRanking(
    address: i == 0 ? pointsTestAddress : '0x${(i + 1).toRadixString(16).padLeft(40, '0')}',
    rank: i + 1,
    points: Decimal.parse('1000.000000000000000001'),
    settled: campaign == null ? Decimal.fromInt(900) : null,
    current: campaign == null ? Decimal.fromInt(80) : null,
    special: campaign == null ? Decimal.fromInt(20) : null,
  ),
);

class TestPointsRepository implements PointsRepository {
  TestPointsRepository({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  DateTime? receivedAt;
  final calls = <String>[];
  final failures = <String, Object>{};
  final gates = <String, Completer<void>>{};
  bool noCurrent = false, wrongAddress = false;
  int rowCount = 25;
  int? wrongCampaign;
  List<PointsCampaign>? campaignRows;
  List<WalletCampaignPoints>? historyRows;
  List<TradingEvent>? eventRows, channelEventRows;
  TradingEvent? eventValue;
  bool registered = false;
  String? blockReason;
  int? wrongEvent;
  int eventRankingRows = 30;
  Future<void> _read(String key) async {
    calls.add(key);
    if (gates[key] case final gate?) await gate.future;
    if (failures[key] case final error?) throw error;
  }

  PointsSnapshot<T> _snapshot<T>(T value) =>
      PointsSnapshot(value: value, receivedAt: receivedAt ?? now());
  @override
  Future<PointsSnapshot<PointsCampaign?>> currentCampaign() async {
    await _read('current');
    return _snapshot(noCurrent ? null : pointsCampaignFixture(17, current: true));
  }

  @override
  Future<PointsSnapshot<List<PointsCampaign>>> campaigns() async {
    await _read('cycles');
    return _snapshot(
      campaignRows ?? [pointsCampaignFixture(1), pointsCampaignFixture(17, current: true)],
    );
  }

  @override
  Future<PointsSnapshot<PointsLeaderboard>> leaderboard(int? campaign) async {
    await _read('board:${campaign ?? 'total'}');
    return _snapshot(
      PointsLeaderboard(
        campaign: wrongCampaign ?? campaign,
        rows: pointsRankingsFixture(count: rowCount, campaign: campaign),
      ),
    );
  }

  @override
  Future<PointsSnapshot<WalletPoints>> wallet(String address) async {
    await _read('wallet:$address');
    return _snapshot(
      WalletPoints(
        address: wrongAddress ? '0x2222222222222222222222222222222222222222' : address,
        total: Decimal.parse('123.000000000000000001'),
        current: Decimal.parse('3.000000000000000001'),
        settled: Decimal.fromInt(100),
        special: Decimal.fromInt(20),
      ),
    );
  }

  @override
  Future<PointsSnapshot<WalletPointsHistory>> walletHistory(String address) async {
    await _read('history:$address');
    return _snapshot(
      WalletPointsHistory(
        address: wrongAddress ? '0x2222222222222222222222222222222222222222' : address,
        rows:
            historyRows ??
            [
              WalletCampaignPoints(
                campaign: 1,
                points: Decimal.fromInt(100),
                name: 'Vanta campaign 1',
              ),
            ],
      ),
    );
  }

  @override
  Future<PointsSnapshot<List<TradingEvent>>> events({
    TradingEventType type = TradingEventType.retail,
  }) async {
    await _read(type == TradingEventType.retail ? 'events' : 'channel-events');
    return _snapshot(
      (type == TradingEventType.channel ? (channelEventRows ?? eventRows) : eventRows) ??
          [tradingEventFixture(), tradingEventFixture(id: 9, status: 'ENDED')],
    );
  }

  @override
  Future<PointsSnapshot<TradingEvent>> event(int id) async {
    await _read('event:$id');
    return _snapshot(eventValue ?? tradingEventFixture(id: wrongEvent ?? id));
  }

  @override
  Future<PointsSnapshot<EventLeaderboard>> eventLeaderboard(
    int id, {
    TradingEventType type = TradingEventType.retail,
  }) async {
    await _read('event-board:$id');
    return _snapshot(
      EventLeaderboard(
        eventId: wrongEvent ?? id,
        type: type,
        rows: List.generate(
          eventRankingRows,
          (i) => EventRanking(
            rank: i + 1,
            address: '0x${(i + 1).toRadixString(16).padLeft(40, '0')}',
            volume: Decimal.parse('12345.000000000000000001'),
          ),
        ),
      ),
    );
  }

  EventTaskProgress? taskProgress;
  @override
  Future<PointsSnapshot<EventTaskProgress>> eventTaskProgress(int id, String address) async {
    await _read('tasks:$id:$address');
    return _snapshot(
      taskProgress ??
          EventTaskProgress(
            eventId: wrongEvent ?? id,
            address: wrongAddress ? '0x2222222222222222222222222222222222222222' : address,
          ),
    );
  }

  @override
  Future<PointsSnapshot<EventParticipant>> eventParticipant(int id, String address) async {
    await _read('participant:$id:$address');
    return _snapshot(
      EventParticipant(
        eventId: wrongEvent ?? id,
        address: wrongAddress ? '0x2222222222222222222222222222222222222222' : address,
        registered: registered,
        ownVolume: registered ? Decimal.parse('1500.000000000000000001') : null,
        blockReason: blockReason,
      ),
    );
  }
}
