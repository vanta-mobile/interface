import 'package:decimal/decimal.dart';

import 'dart:async';

import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import 'aster_account.dart';

final assetModeClock = DateTime.utc(2026, 11, 3, 12);
List<Map<String, Object?>> assetModeRows({
  String symbol = 'BTCUSDT',
  bool hedge = false,
  String quantity = '0',
  String margin = 'cross',
  String wallet = '0',
}) => [
  for (final side in hedge ? ['LONG', 'SHORT'] : ['BOTH'])
    {
      'symbol': symbol,
      'positionSide': side,
      'marginType': margin,
      'isolatedWallet': wallet,
      'positionAmt': side == 'SHORT' && quantity != '0' ? '-$quantity' : quantity,
    },
];
FuturesAssetModeContext assetModeContext({
  String address = accountAddress,
  FuturesAssetMode current = FuturesAssetMode.single,
  List<String> isolatedSymbols = const [],
  DateTime? time,
  Decimal? usdt,
}) => FuturesAssetModeContext(
  address: address,
  current: current,
  isolatedSymbols: isolatedSymbols,
  receivedAt: time ?? assetModeClock,
  usdtWalletBalance: usdt ?? Decimal.zero,
);

class TestFuturesAssetModeRepository implements FuturesAssetModeRepository {
  int reads = 0, changes = 0, checks = 0;
  Completer<void>? readGate, changeGate, checkGate;
  AccountReadFailure? readFailure, changeFailure;
  bool submit = true;
  FuturesAssetModeContext? context;
  AssetModeResult result = AssetModeResult(
    observed: FuturesAssetMode.multi,
    checkedAt: assetModeClock,
  );
  bool Function()? latestCurrent;
  @override
  Future<FuturesAssetModeContext> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AssetModeStep) onStep,
  }) async {
    reads++;
    latestCurrent = isCurrent;
    await readGate?.future;
    if (readFailure case final failure?) throw failure;
    return context ?? assetModeContext(address: address);
  }

  @override
  Future<AssetModeResult> change({
    required AssetModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(AssetModeStep) onStep,
  }) async {
    changes++;
    latestCurrent = isCurrent;
    onStep(AssetModeStep.signing);
    await changeGate?.future;
    if (submit && canSubmit()) onStep(AssetModeStep.submitting);
    if (changeFailure case final failure?) throw failure;
    return result;
  }

  @override
  Future<AssetModeResult> recheck({
    required AssetModeIntent intent,
    required bool Function() isCurrent,
    required void Function(AssetModeStep) onStep,
  }) async {
    checks++;
    latestCurrent = isCurrent;
    onStep(AssetModeStep.checkSigning);
    await checkGate?.future;
    return result;
  }
}
