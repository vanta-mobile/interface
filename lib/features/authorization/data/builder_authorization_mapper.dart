import 'package:decimal/decimal.dart';

import '../domain/builder_authorization.dart';

BuilderAuthorization mapBuilderAuthorization(Object? payload, String owner) {
  if (payload is! List || payload.length > 1000) throw const FormatException();
  Decimal? cap;
  final addresses = <String>{};
  for (final item in payload) {
    if (item is! Map<String, dynamic> ||
        item['userAddress'] is! String ||
        (item['userAddress'] as String).toLowerCase() != owner.toLowerCase() ||
        item['builderAddress'] is! String ||
        !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(item['builderAddress'] as String)) {
      throw const FormatException();
    }
    final builder = (item['builderAddress'] as String).toLowerCase();
    if (!addresses.add(builder)) throw const FormatException();
    final raw = item['maxFeeRate'];
    // The documented read response uses a JSON number; signatures use strings.
    if (raw is! String && raw is! num) throw const FormatException();
    final rate = Decimal.tryParse('$raw');
    if (rate == null || rate < Decimal.zero || rate > Decimal.parse('0.001')) {
      throw const FormatException();
    }
    if (builder == VantaBuilder.address.toLowerCase()) cap = rate;
  }
  return BuilderAuthorization(owner: owner, maxFeeRate: cap);
}

Map<String, Object?> builderApprovalTypedData({
  required String owner,
  required int nonce,
  required bool update,
}) {
  final primary = update ? 'UpdateBuilder' : 'ApproveBuilder';
  final fields = <Map<String, String>>[
    {'name': 'Builder', 'type': 'string'},
    {'name': 'MaxFeeRate', 'type': 'string'},
    if (!update) {'name': 'BuilderName', 'type': 'string'},
    {'name': 'AsterChain', 'type': 'string'},
    {'name': 'User', 'type': 'string'},
    {'name': 'Nonce', 'type': 'uint256'},
  ];
  return {
    'types': {
      'EIP712Domain': [
        {'name': 'name', 'type': 'string'},
        {'name': 'version', 'type': 'string'},
        {'name': 'chainId', 'type': 'uint256'},
        {'name': 'verifyingContract', 'type': 'address'},
      ],
      primary: fields,
    },
    'primaryType': primary,
    'domain': {
      'name': 'AsterSignTransaction',
      'version': '1',
      'chainId': 56,
      'verifyingContract': '0x0000000000000000000000000000000000000000',
    },
    'message': {
      'Builder': VantaBuilder.address,
      'MaxFeeRate': VantaBuilder.approvalCap.toString(),
      if (!update) 'BuilderName': VantaBuilder.name,
      'AsterChain': 'Mainnet',
      'User': owner,
      'Nonce': nonce,
    },
  };
}
