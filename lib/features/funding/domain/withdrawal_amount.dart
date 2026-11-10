import 'package:decimal/decimal.dart';

import 'funding_catalog.dart';

/// The platform deducts withdrawal fees from exchange funds, not wallet gas.
String? withdrawAmountError(
  String text,
  FundingAsset asset,
  Decimal? withdrawable, {
  Decimal? fee,
}) {
  if (text.isEmpty) return null;
  final value = text.length > 160 || !RegExp(r'^(0|[1-9]\d*)(?:\.\d+)?$').hasMatch(text)
      ? null
      : Decimal.parse(text);
  if (value == null || value <= Decimal.zero || value.scale > asset.decimals) {
    return 'withdrawalAmountInvalid';
  }
  if (withdrawable != null) {
    if (value > withdrawable) return 'fundingBalanceInsufficient';
    if (fee != null && value + fee > withdrawable) return 'fundingWithdrawalFeeInsufficient';
  }
  return null;
}
