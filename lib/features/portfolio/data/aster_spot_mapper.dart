import 'package:decimal/decimal.dart';

import '../domain/aster_spot_account.dart';

AsterSpotAccount mapAsterSpotAccount(
  Object? payload, {
  required String address,
  required DateTime receivedAt,
}) {
  if (payload is! Map<String, dynamic> || payload['balances'] is! List<dynamic>) {
    throw const FormatException();
  }
  final balances = <AsterSpotBalance>[];
  final seen = <String>{};
  for (final row in payload['balances'] as List<dynamic>) {
    if (row is! Map<String, dynamic>) throw const FormatException();
    final asset = row['asset'];
    if (asset is! String ||
        !RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(asset) ||
        !seen.add(asset)) {
      throw const FormatException();
    }
    balances.add(
      AsterSpotBalance(asset: asset, free: _amount(row['free']), locked: _amount(row['locked'])),
    );
  }
  return AsterSpotAccount(address: address, receivedAt: receivedAt, balances: balances);
}

Decimal _amount(Object? value) {
  if (value is! String && value is! int) throw const FormatException();
  final text = '$value';
  if (text.length > 160 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) {
    throw const FormatException();
  }
  return Decimal.parse(text);
}
