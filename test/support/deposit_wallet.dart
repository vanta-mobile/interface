import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/domain/funding_catalog.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';

import 'aster_account.dart';

DepositWalletQuery depositQuery({
  bool native = false,
  int chain = 56,
  int decimals = 18,
  String? minimum = '0.1',
  TransferMarket market = TransferMarket.perp,
  String route = 'normal',
  String? tokenAddress,
}) => DepositWalletQuery(
  market: market,
  asset: FundingAsset(
    asset: native
        ? chain == 56
              ? 'BNB'
              : 'ETH'
        : 'USDT',
    displayName: 'Test asset',
    chainId: chain,
    tokenAddress:
        tokenAddress ??
        (native ? fundingNativePlaceholder : '0x5555555555555555555555555555555555555555'),
    decimals: decimals,
    isNative: native,
    routeType: route,
    minimumDeposit: minimum == null ? null : Decimal.parse(minimum),
  ),
);

DepositWalletSnapshot depositSnapshot({
  required DepositWalletQuery query,
  String address = accountAddress,
  BigInt? assetUnits,
  BigInt? allowance,
  Duration blockAge = Duration.zero,
  DateTime? receivedAt,
  BigInt? nativeUnits,
}) {
  final now = receivedAt ?? DateTime.now().toUtc();
  final native = nativeUnits ?? BigInt.parse('10000000000000000000');
  return DepositWalletSnapshot(
    address: address,
    query: query,
    receivedAt: now,
    blockTime: now.subtract(blockAge),
    assetUnits:
        assetUnits ?? (query.asset.isNative ? native : BigInt.parse('123456789012345678901')),
    nativeUnits: native,
    allowanceUnits: query.asset.isNative ? null : allowance ?? BigInt.parse('2000000000000000000'),
    blockNumber: BigInt.from(123),
    blockHash: '0x${'a' * 64}',
  );
}

class TestDepositWalletRepository implements DepositWalletRepository {
  final calls = <(String, DepositWalletQuery)>[];
  Completer<void>? gate;
  Object? failure;
  DepositWalletSnapshot? result;
  @override
  Future<DepositWalletSnapshot> read({
    required String address,
    required DepositWalletQuery query,
    required bool Function() isCurrent,
  }) async {
    calls.add((address, query));
    await gate?.future;
    if (failure case final error?) throw error;
    return result ?? depositSnapshot(query: query, address: address);
  }
}
