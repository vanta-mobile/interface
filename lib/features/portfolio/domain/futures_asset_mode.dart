import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';

enum FuturesAssetMode {
  single('false'),
  multi('true');

  const FuturesAssetMode(this.parameter);
  final String parameter;
}

class FuturesAssetModeContext {
  FuturesAssetModeContext({
    required this.address,
    required this.current,
    required List<String> isolatedSymbols,
    required this.receivedAt,
    this.usdtWalletBalance,
  }) : isolatedSymbols = List.unmodifiable(isolatedSymbols);
  final String address;
  final FuturesAssetMode current;
  final List<String> isolatedSymbols;
  final DateTime receivedAt;
  final Decimal? usdtWalletBalance;
  bool blocks(FuturesAssetMode target) =>
      target == FuturesAssetMode.multi && isolatedSymbols.isNotEmpty ||
      target == FuturesAssetMode.single &&
          current == FuturesAssetMode.multi &&
          (usdtWalletBalance == null || usdtWalletBalance! < Decimal.zero);
}

enum AssetModeStep {
  idle,
  preparing,
  signingContext,
  loadingContext,
  signing,
  submitting,
  checkSigning,
  checking,
}

class AssetModeIntent {
  const AssetModeIntent({required this.context, required this.target, required this.revision});
  final FuturesAssetModeContext context;
  final FuturesAssetMode target;
  final int revision;
}

class AssetModeResult {
  const AssetModeResult({this.observed, this.failure, this.checkedAt});
  final FuturesAssetMode? observed;
  final DateTime? checkedAt;
  final AccountReadFailure? failure;
  bool get needsRecheck => observed == null;
}

class FuturesAssetModeState {
  const FuturesAssetModeState({
    this.context,
    this.intent,
    this.result,
    this.failure,
    this.step = AssetModeStep.idle,
    this.stale = false,
  });
  final FuturesAssetModeContext? context;
  final AssetModeIntent? intent;
  final AssetModeResult? result;
  final AccountReadFailure? failure;
  final AssetModeStep step;
  final bool stale;
  bool get busy => step != AssetModeStep.idle;
  bool get needsRecheck => result?.needsRecheck == true;
}

abstract interface class FuturesAssetModeRepository {
  Future<FuturesAssetModeContext> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AssetModeStep) onStep,
  });
  Future<AssetModeResult> change({
    required AssetModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(AssetModeStep) onStep,
  });
  Future<AssetModeResult> recheck({
    required AssetModeIntent intent,
    required bool Function() isCurrent,
    required void Function(AssetModeStep) onStep,
  });
}
