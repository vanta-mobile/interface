import 'package:decimal/decimal.dart';

import '../../portfolio/data/aster_account_mapper.dart';
import '../../portfolio/data/aster_spot_mapper.dart';
import '../../portfolio/domain/futures_asset_mode.dart';
import '../domain/internal_transfer.dart';

bool? _permission(Object? v) => v == null || v is bool ? v as bool? : throw const FormatException();
Decimal? _money(Object? v) {
  if (v == null) return null;
  if (v is! String || v.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(v)) {
    throw const FormatException();
  }
  return Decimal.parse(v);
}

String _asset(Object? v) => v is String && RegExp(r'^[A-Za-z0-9_.-]{1,60}$').hasMatch(v)
    ? v
    : throw const FormatException();
List<dynamic> _rows(Object? v) {
  if (v is! Map<String, dynamic> ||
      v['code'] != '000000' ||
      v['success'] != true ||
      v['data'] is! List ||
      (v['data'] as List).length > 5000) {
    throw const FormatException();
  }
  return v['data'] as List;
}

InternalTransferCatalog mapInternalTransferCatalog(
  Object? supported,
  Object? precision,
  DateTime receivedAt,
) {
  final names = <String>{}, decimals = <String, int>{};
  for (final v in _rows(supported)) {
    if (!names.add(_asset(v))) throw const FormatException();
  }
  for (final row in _rows(precision)) {
    if (row is! Map<String, dynamic>) throw const FormatException();
    final name = _asset(row['assetCode']), places = row['assetDecimal'];
    if (places is! int ||
        places < 0 ||
        places > 255 ||
        decimals.containsKey(name) && decimals[name] != places) {
      throw const FormatException();
    }
    decimals[name] = places;
  }
  // Match the public website's transfer input rule, not on-chain decimals:
  // cap at eight, with two-place fallback for absent/zero display precision.
  return InternalTransferCatalog(
    receivedAt: receivedAt,
    assets: names.map((a) {
      final p = decimals[a];
      return InternalTransferAsset(
        a,
        p == null || p == 0
            ? 2
            : p > 8
            ? 8
            : p,
      );
    }),
  );
}

InternalTransferContext mapInternalTransferContext({
  required Object? spotPayload,
  required Object? futuresPayload,
  required InternalTransferCatalog catalog,
  required String address,
  required String asset,
  required InternalTransferDirection direction,
  required FuturesAssetMode mode,
  required DateTime receivedAt,
  required DateTime completedAt,
}) {
  if (spotPayload is! Map<String, dynamic> || futuresPayload is! Map<String, dynamic>) {
    throw const FormatException();
  }
  final spot = mapAsterSpotAccount(spotPayload, address: address, receivedAt: completedAt),
      futures = mapAsterAccount(futuresPayload, address: address, receivedAt: completedAt);
  final row = (futuresPayload['assets'] as List)
      .where((a) => a is Map<String, dynamic> && a['asset'] == asset)
      .singleOrNull;
  final fromSpot = direction == InternalTransferDirection.spotToFutures;
  return InternalTransferContext(
    address: address,
    direction: direction,
    assetName: asset,
    catalog: catalog,
    spot: spot,
    futures: futures,
    mode: mode,
    receivedAt: receivedAt,
    maximum: fromSpot
        ? spot.balances.where((a) => a.asset == asset).singleOrNull?.free
        : row == null
        ? null
        : _money((row as Map<String, dynamic>)['maxWithdrawAmount']),
    sourcePermission: _permission((fromSpot ? spotPayload : futuresPayload)['canWithdraw']),
    destinationPermission: _permission((fromSpot ? futuresPayload : spotPayload)['canDeposit']),
  );
}

InternalTransferReply mapInternalTransferReply(Object? payload) {
  if (payload is! Map<String, dynamic> ||
      payload['status'] != 'SUCCESS' ||
      payload['tranId'] is! int) {
    throw const FormatException();
  }
  return InternalTransferReply('${payload['tranId']}');
}
