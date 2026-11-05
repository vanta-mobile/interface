import 'dart:async';

import 'package:vanta/features/funding/data/funding_catalog_mapper.dart';
import 'package:vanta/features/funding/data/withdraw_info_mapper.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/withdraw_info.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import 'aster_account.dart';

Map<String, Object?> fundingAssetRow({
  String asset = 'USDT',
  int chain = 56,
  bool native = false,
}) => {
  'name': asset,
  'displayName': asset,
  'chainId': chain,
  'network': 'EVM',
  'contractAddress': native
      ? fundingNativePlaceholder
      : '0x5555555555555555555555555555555555555555',
  'decimals': 18,
  'isNative': native,
  'isProfit': true,
  'depositType': 'normal',
  'withdrawType': 'autoWithdraw',
};
Map<String, Object?> fundingCatalogPayload([List<Map<String, Object?>>? rows]) => {
  'code': '000000',
  'success': true,
  'data':
      rows ??
      [
        fundingAssetRow(),
        fundingAssetRow(asset: 'BNB', native: true),
        fundingAssetRow(asset: 'ETH', chain: 1, native: true),
      ],
};
Map<String, Object?> withdrawChainRow() => {
  'chainId': 56,
  'spotMaxWithdrawAmount': '1.230000000000000001',
  'perpMaxWithdrawAmount': '2.340000000000000002',
  'chainLimit': '3.450000000000000003',
  'withdrawFee': '0.000000000000000001',
};
Map<String, Object?> withdrawBalanceRow() => {
  'currency': 'USDT',
  'spotTotalWithdrawAmount': '12.300000000000000001',
  'perpTotalWithdrawAmount': '23.400000000000000002',
  'dailyLimit': '9000',
  'chainBalances': {'56': withdrawChainRow()},
};
Map<String, Object?> withdrawInfoPayload() => {
  'userDailyLimit': '10000',
  'userRemainingDailyLimit': '9000',
  'totalDailyLimit': '1000000',
  'totalRemainingDailyLimit': '980000',
  'balances': {'USDT': withdrawBalanceRow()},
};
WithdrawInfo withdrawInfoFixture({String address = accountAddress}) => mapWithdrawInfo(
  withdrawInfoPayload(),
  address: address,
  receivedAt: DateTime.utc(2026, 11, 3, 12),
);

class TestFundingCatalogRepository implements FundingCatalogRepository {
  final calls = <FundingCatalogQuery>[];
  final gates = <FundingCatalogQuery, Completer<FundingCatalog>>{};
  List<Map<String, Object?>>? rows;
  Object? failure;
  @override
  Future<FundingCatalog> read(FundingCatalogQuery query) async {
    calls.add(query);
    if (gates[query] case final gate?) return gate.future;
    if (failure case final error?) throw error;
    return mapFundingCatalog(fundingCatalogPayload(rows), query: query, receivedAt: DateTime.now());
  }
}

class TestWithdrawInfoRepository implements WithdrawInfoRepository {
  WithdrawInfo result = withdrawInfoFixture();
  Completer<void>? gate;
  AccountReadFailure? failure;
  int calls = 0, sends = 0;
  @override
  Future<WithdrawInfo> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    calls++;
    onStep(AccountReadStep.signing);
    await gate?.future;
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    sends++;
    onStep(AccountReadStep.loading);
    if (failure case final error?) throw error;
    return result;
  }
}
