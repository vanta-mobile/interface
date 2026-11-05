import 'package:decimal/decimal.dart';

import '../../portfolio/domain/account_snapshot.dart';
import 'transfer_history.dart';

class WithdrawChainInfo {
  const WithdrawChainInfo({
    required this.chainId,
    this.spotMaxAmount,
    this.perpMaxAmount,
    this.chainLimit,
    this.fee,
  });
  final int chainId;
  final Decimal? spotMaxAmount, perpMaxAmount, chainLimit, fee;
  Decimal? maximum(TransferMarket market) =>
      market == TransferMarket.spot ? spotMaxAmount : perpMaxAmount;
}

class WithdrawAssetInfo {
  WithdrawAssetInfo({
    required this.asset,
    required Map<int, WithdrawChainInfo> chains,
    this.spotTotalAmount,
    this.perpTotalAmount,
    this.dailyLimitUsd,
  }) : chains = Map.unmodifiable(chains);
  final String asset;
  final Map<int, WithdrawChainInfo> chains;
  final Decimal? spotTotalAmount, perpTotalAmount, dailyLimitUsd;
  Decimal? total(TransferMarket market) =>
      market == TransferMarket.spot ? spotTotalAmount : perpTotalAmount;
}

/// USD limits remain separate from asset quantities. These reported values
/// are a snapshot, not a synthesized final withdrawal allowance or permission.
class WithdrawInfo implements WalletAccountSnapshot {
  WithdrawInfo({
    required this.address,
    required this.receivedAt,
    required Map<String, WithdrawAssetInfo> assets,
    this.userDailyLimitUsd,
    this.userRemainingDailyLimitUsd,
    this.totalDailyLimitUsd,
    this.totalRemainingDailyLimitUsd,
  }) : assets = Map.unmodifiable(assets);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final Map<String, WithdrawAssetInfo> assets;
  final Decimal? userDailyLimitUsd,
      userRemainingDailyLimitUsd,
      totalDailyLimitUsd,
      totalRemainingDailyLimitUsd;
}

typedef WithdrawInfoRepository = WalletAccountRepository<WithdrawInfo>;
typedef WithdrawInfoState = AccountSnapshotState<WithdrawInfo>;
