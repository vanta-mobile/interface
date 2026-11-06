import '../../../core/errors/api_error_details.dart';

import 'package:decimal/decimal.dart';

import 'transfer_history.dart';

enum FundingOperation { deposit, withdraw }

/// This EVM client queries the three mainnets listed by the official funding
/// document. This is not a claim that other Aster networks do not exist.
const fundingEvmChainIds = [1, 56, 42161];
const fundingNativePlaceholder = '0xfdae1ba7c826abdc4c99903c8056f82a1a04a615';

class FundingCatalogQuery {
  const FundingCatalogQuery(this.market, this.operation);
  final TransferMarket market;
  final FundingOperation operation;
  @override
  bool operator ==(Object other) =>
      other is FundingCatalogQuery && other.market == market && other.operation == operation;
  @override
  int get hashCode => Object.hash(market, operation);
}

class FundingAsset {
  const FundingAsset({
    required this.asset,
    required this.displayName,
    required this.chainId,
    required this.tokenAddress,
    required this.decimals,
    required this.isNative,
    required this.routeType,
    this.isProfit,
    this.minimumDeposit,
  });
  final String asset, displayName, tokenAddress, routeType;
  final int chainId, decimals;
  final bool isNative;
  final bool? isProfit;
  final Decimal? minimumDeposit;
}

class FundingCatalog {
  FundingCatalog({
    required this.query,
    required this.receivedAt,
    required Iterable<FundingAsset> assets,
  }) : assets = List.unmodifiable(assets);
  final FundingCatalogQuery query;
  final DateTime receivedAt;
  final List<FundingAsset> assets;
}

abstract interface class FundingCatalogRepository {
  Future<FundingCatalog> read(FundingCatalogQuery query);
}

class FundingCatalogState {
  const FundingCatalogState({
    this.catalog,
    this.loading = false,
    this.stale = false,
    this.failureKey,
    this.errorDetails,
  });
  final FundingCatalog? catalog;
  final bool loading, stale;
  final ApiErrorDetails? errorDetails;
  final String? failureKey;
}
