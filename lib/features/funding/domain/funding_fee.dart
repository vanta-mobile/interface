import '../../../core/errors/api_error_details.dart';

import 'package:decimal/decimal.dart';

import 'transfer_history.dart';

class FundingFeeQuery {
  const FundingFeeQuery({required this.market, required this.chainId, required this.asset});
  final TransferMarket market;
  final int chainId;
  final String asset;
  @override
  bool operator ==(Object other) =>
      other is FundingFeeQuery &&
      other.market == market &&
      other.chainId == chainId &&
      other.asset == asset;
  @override
  int get hashCode => Object.hash(market, chainId, asset);
}

/// Platform withdrawal fee estimate, not wallet transaction gas or permission.
class FundingFeeQuote {
  const FundingFeeQuote({
    required this.query,
    required this.receivedAt,
    required this.assetFee,
    required this.usdFee,
    this.assetPriceUsd,
  });
  final FundingFeeQuery query;
  final DateTime receivedAt;
  final Decimal assetFee, usdFee;
  final Decimal? assetPriceUsd;
}

abstract interface class FundingFeeRepository {
  Future<FundingFeeQuote> read(FundingFeeQuery query);
}

class FundingFeeState {
  const FundingFeeState({
    this.quote,
    this.loading = false,
    this.stale = false,
    this.failureKey,
    this.errorDetails,
  });
  final FundingFeeQuote? quote;
  final bool loading, stale;
  final ApiErrorDetails? errorDetails;
  final String? failureKey;
}
