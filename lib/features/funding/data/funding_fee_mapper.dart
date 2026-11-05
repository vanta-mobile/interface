import 'package:decimal/decimal.dart';

import '../domain/funding_fee.dart';
import 'funding_money.dart';

FundingFeeQuote mapFundingFee(
  Object? payload, {
  required FundingFeeQuery query,
  required DateTime receivedAt,
}) {
  if (payload is! Map<String, dynamic> ||
      payload['code'] != '000000' ||
      payload['success'] != true) {
    throw const FormatException();
  }
  final row = payload['data'];
  if (row is! Map<String, dynamic>) throw const FormatException();
  final price = row['tokenPrice'] == null ? null : fundingMoney(row['tokenPrice']);
  if (price != null && price <= Decimal.zero) throw const FormatException();
  return FundingFeeQuote(
    query: query,
    receivedAt: receivedAt.toUtc(),
    assetFee: fundingMoney(row['gasCost']),
    usdFee: fundingMoney(row['gasUsdValue']),
    assetPriceUsd: price,
  );
}
