import 'package:decimal/decimal.dart';

import '../../../core/exact_json.dart';
import '../domain/points.dart';

Map<String, dynamic> pointsObject(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException();
  return value;
}

List<dynamic> pointsRows(Object? value) {
  final rows = pointsObject(value)['items'];
  if (rows is! List || rows.length > 5000) throw const FormatException();
  return rows;
}

String pointsText(Object? value, {int max = 1024, bool empty = false}) {
  if (value is! String ||
      value.length > max ||
      (!empty && value.trim().isEmpty) ||
      RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\u202a-\u202e\u2066-\u2069]').hasMatch(value)) {
    throw const FormatException();
  }
  return value;
}

int pointsPositiveInt(Object? raw) {
  final value = raw is FundingJsonNumber
      ? raw.integer
      : raw is int
      ? raw
      : null;
  if (value == null || value <= 0 || value > 9223372036854775807) throw const FormatException();
  return value;
}

Decimal pointsAmount(Object? raw) {
  final text = raw is FundingJsonNumber
      ? raw.text
      : raw is String
      ? raw
      : null;
  if (text == null || text.length > 160 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) {
    throw const FormatException();
  }
  return Decimal.parse(text);
}

Decimal? pointsOptionalAmount(Map<String, dynamic> row, String key) =>
    row[key] == null ? null : pointsAmount(row[key]);

DateTime pointsTime(Object? raw) {
  final text = pointsText(raw, max: 40);
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|[+-](\d{2}):(\d{2}))$',
  ).firstMatch(text);
  if (match == null) throw const FormatException();
  final year = int.parse(match[1]!), month = int.parse(match[2]!), day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  if (year < 1970 ||
      date.year != year ||
      date.month != month ||
      date.day != day ||
      int.parse(match[4]!) > 23 ||
      int.parse(match[5]!) > 59 ||
      int.parse(match[6]!) > 59 ||
      int.parse(match[8] ?? '0') > 23 ||
      int.parse(match[9] ?? '0') > 59) {
    throw const FormatException();
  }
  final result = DateTime.tryParse(text);
  if (result == null) throw const FormatException();
  return result.toUtc();
}

PointsCampaign _campaign(Object? value) {
  final row = pointsObject(value),
      start = pointsTime(row['startTime']),
      end = pointsTime(row['endTime']);
  if (!end.isAfter(start) || row['currentCampaign'] is! bool) throw const FormatException();
  return PointsCampaign(
    number: pointsPositiveInt(row['campaignNumber']),
    name: pointsText(row['campaignName'], empty: true),
    pool: pointsAmount(row['totalVantaPoints']),
    start: start,
    end: end,
    current: row['currentCampaign'] as bool,
    status: pointsText(row['status'], max: 64),
    broker: pointsText(row['orderlyBrokerId'], max: 128),
    description: row['description'] == null
        ? ''
        : pointsText(row['description'], max: 8192, empty: true),
  );
}

PointsCampaign? mapCurrentPointsCampaign(Object? payload) {
  final row = pointsObject(payload);
  if (!row.containsKey('campaign')) throw const FormatException();
  final campaign = row['campaign'];
  if (campaign == null) return null;
  final result = _campaign(campaign);
  if (!result.current) throw const FormatException();
  return result;
}

List<PointsCampaign> mapPointsCampaigns(Object? payload) {
  final numbers = <int>{};
  var currentCount = 0;
  final rows = <PointsCampaign>[];
  for (final raw in pointsRows(payload)) {
    final row = _campaign(raw);
    if (!numbers.add(row.number) || (row.current && ++currentCount > 1)) {
      throw const FormatException();
    }
    rows.add(row);
  }
  return List.unmodifiable(rows);
}

String pointsAddress(Object? raw) {
  final value = pointsText(raw, max: 64);
  if (!isPointsEvmAddress(value) && !RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(value)) {
    throw const FormatException();
  }
  return value;
}

PointsLeaderboard mapPointsLeaderboard(Object? payload, {required int? campaign}) {
  final rows = pointsRows(payload), addresses = <String>{};
  final result = <PointsRanking>[];
  for (final raw in rows) {
    final row = pointsObject(raw), address = pointsAddress(row['address']);
    if (campaign != null && pointsPositiveInt(row['campaignNumber']) != campaign) {
      throw const FormatException();
    }
    if (!addresses.add(pointsAddressKey(address))) throw const FormatException();
    final rank = pointsPositiveInt(row['rank']);
    final points = pointsAmount(row[campaign == null ? 'totalPoint' : 'points']);
    result.add(
      PointsRanking(
        address: address,
        rank: rank,
        points: points,
        settled: campaign == null ? pointsOptionalAmount(row, 'settledPoints') : null,
        special: campaign == null ? pointsOptionalAmount(row, 'specialPoints') : null,
        current: campaign == null ? pointsOptionalAmount(row, 'currentPoint') : null,
      ),
    );
  }
  return PointsLeaderboard(
    campaign: campaign,
    rows: result.take(100),
    truncated: result.length > 100,
  );
}

void _walletResponseAddress(Map<String, dynamic> row, String address) {
  if (!isPointsEvmAddress(address) ||
      row['address'] != null &&
          pointsAddressKey(pointsAddress(row['address'])) != pointsAddressKey(address)) {
    throw const FormatException();
  }
}

WalletPoints mapWalletPoints(Object? payload, {required String address}) {
  final row = pointsObject(payload);
  _walletResponseAddress(row, address);
  return WalletPoints(
    address: address,
    total: pointsAmount(row['totalPoint']),
    current: pointsAmount(row['currentPoint']),
    settled: pointsOptionalAmount(row, 'settledPoints'),
    special: pointsOptionalAmount(row, 'specialPoints'),
  );
}

WalletPointsHistory mapWalletPointsHistory(Object? payload, {required String address}) {
  final envelope = pointsObject(payload), campaigns = <int>{}, result = <WalletCampaignPoints>[];
  _walletResponseAddress(envelope, address);
  for (final raw in pointsRows(payload)) {
    final row = pointsObject(raw), number = pointsPositiveInt(row['campaignNumber']);
    if (!campaigns.add(number)) throw const FormatException();
    _walletResponseAddress(row, address);
    result.add(
      WalletCampaignPoints(
        campaign: number,
        points: pointsAmount(row['points']),
        name: row['campaignName'] == null ? '' : pointsText(row['campaignName'], empty: true),
      ),
    );
  }
  return WalletPointsHistory(address: address, rows: result);
}
