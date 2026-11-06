import '../../../core/errors/api_error_details.dart';

import 'package:decimal/decimal.dart';

import 'trading_event.dart';
import 'event_engagement.dart';

class PointsSnapshot<T> {
  const PointsSnapshot({required this.value, required this.receivedAt});
  final T value;
  final DateTime receivedAt;
}

class PointsLoadState<T> {
  const PointsLoadState({
    this.snapshot,
    this.loading = false,
    this.stale = false,
    this.active = true,
    this.failureKey,
    this.errorDetails,
  });
  final PointsSnapshot<T>? snapshot;
  final bool loading, stale, active;
  final ApiErrorDetails? errorDetails;
  final String? failureKey;
}

/// Vanta's published program. Its venue/broker is not the Aster trading account.
class PointsCampaign {
  const PointsCampaign({
    required this.number,
    required this.name,
    required this.pool,
    required this.start,
    required this.end,
    required this.status,
    required this.current,
    required this.broker,
    this.description = '',
  });
  final int number;
  final String name, description, status, broker;
  final Decimal pool;
  final DateTime start, end;
  final bool current;
}

class PointsRanking {
  const PointsRanking({
    required this.address,
    required this.rank,
    required this.points,
    this.settled,
    this.special,
    this.current,
  });
  final String address;
  final int rank;
  final Decimal points;
  final Decimal? settled, special, current;
}

class PointsLeaderboard {
  PointsLeaderboard({
    required this.campaign,
    required Iterable<PointsRanking> rows,
    this.truncated = false,
  }) : rows = List.unmodifiable(rows);
  final int? campaign;
  final List<PointsRanking> rows;
  final bool truncated;
  int? rankFor(String address) {
    final key = pointsAddressKey(address);
    for (final row in rows) {
      if (pointsAddressKey(row.address) == key) return row.rank;
    }
    return null;
  }
}

class WalletPoints {
  const WalletPoints({
    required this.address,
    required this.total,
    required this.current,
    this.settled,
    this.special,
  });
  final String address;
  final Decimal total, current;
  final Decimal? settled, special;
}

class WalletCampaignPoints {
  const WalletCampaignPoints({required this.campaign, required this.points, this.name = ''});
  final int campaign;
  final String name;
  final Decimal points;
}

class WalletPointsHistory {
  WalletPointsHistory({required this.address, required Iterable<WalletCampaignPoints> rows})
    : rows = List.unmodifiable(rows);
  final String address;
  final List<WalletCampaignPoints> rows;
}

String pointsAddressKey(String address) =>
    address.startsWith('0x') ? address.toLowerCase() : address;
bool isPointsEvmAddress(String address) => RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);

abstract interface class PointsRepository {
  Future<PointsSnapshot<PointsCampaign?>> currentCampaign();
  Future<PointsSnapshot<List<PointsCampaign>>> campaigns();
  Future<PointsSnapshot<PointsLeaderboard>> leaderboard(int? campaign);
  Future<PointsSnapshot<WalletPoints>> wallet(String address);
  Future<PointsSnapshot<WalletPointsHistory>> walletHistory(String address);
  Future<PointsSnapshot<List<TradingEvent>>> events({
    TradingEventType type = TradingEventType.retail,
  });
  Future<PointsSnapshot<TradingEvent>> event(int id);
  Future<PointsSnapshot<EventLeaderboard>> eventLeaderboard(
    int id, {
    TradingEventType type = TradingEventType.retail,
  });
  Future<PointsSnapshot<EventTaskProgress>> eventTaskProgress(int id, String address);
  Future<PointsSnapshot<EventParticipant>> eventParticipant(int id, String address);
}

class PointsFailure implements Exception, DetailedApiFailure {
  const PointsFailure(this.key, {this.details});
  @override
  final ApiErrorDetails? details;
  final String key;
}
