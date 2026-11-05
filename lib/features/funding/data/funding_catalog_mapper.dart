import '../domain/funding_catalog.dart';
import 'funding_json.dart';
import 'funding_money.dart';

Object? decodeFundingCatalogJson(String source) {
  final payload = decodeFundingJson(source);
  if (payload is! Map<String, dynamic>) return payload;
  final code = payload['code'];
  if (code is FundingJsonNumber && code.integer != null && code.integer! < 0) {
    payload['code'] = code.integer;
  }
  final rows = payload['data'];
  if (rows is List) {
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      for (final key in ['chainId', 'decimals']) {
        if (row[key] case final FundingJsonNumber number) row[key] = number.integer ?? number;
      }
      if (row['minDeposit'] case FundingJsonNumber(:final text)) row['minDeposit'] = text;
    }
  }
  return payload;
}

FundingCatalog mapFundingCatalog(
  Object? payload, {
  required FundingCatalogQuery query,
  required DateTime receivedAt,
}) {
  if (payload is! Map<String, dynamic> ||
      payload['code'] != '000000' ||
      payload['success'] != true) {
    throw const FormatException();
  }
  final rows = payload['data'];
  if (rows is! List || rows.length > 5000) throw const FormatException();
  final assets = <FundingAsset>[], keys = <String>{};
  for (final raw in rows) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final asset = raw['name'],
        name = raw['displayName'],
        chain = raw['chainId'],
        token = raw['contractAddress'],
        decimals = raw['decimals'],
        native = raw['isNative'],
        profit = raw['isProfit'];
    final route = raw[query.operation == FundingOperation.deposit ? 'depositType' : 'withdrawType'];
    if (asset is! String ||
        !RegExp(r'^[\p{L}\p{N}_.-]{1,60}$', unicode: true).hasMatch(asset) ||
        name is! String ||
        name.length > 256 ||
        chain is! int ||
        !fundingEvmChainIds.contains(chain) ||
        raw['network'] != 'EVM' ||
        token is! String ||
        !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(token) ||
        decimals is! int ||
        decimals < 0 ||
        decimals > 255 ||
        native is! bool ||
        route is! String ||
        route.isEmpty ||
        route.length > 64 ||
        profit != null && profit is! bool ||
        !keys.add('$chain:$asset')) {
      throw const FormatException();
    }
    if (native != (token.toLowerCase() == fundingNativePlaceholder) ||
        token.toLowerCase() == '0x0000000000000000000000000000000000000000') {
      throw const FormatException();
    }
    assets.add(
      FundingAsset(
        asset: asset,
        displayName: name,
        chainId: chain,
        tokenAddress: token,
        decimals: decimals,
        isNative: native,
        routeType: route,
        isProfit: profit as bool?,
        minimumDeposit: raw['minDeposit'] == null
            ? null
            : fundingMoney(
                raw['minDeposit'] is int ? raw['minDeposit'].toString() : raw['minDeposit'],
              ),
      ),
    );
  }
  return FundingCatalog(query: query, receivedAt: receivedAt.toUtc(), assets: assets);
}
