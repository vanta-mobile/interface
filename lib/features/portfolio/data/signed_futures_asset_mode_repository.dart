import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/futures_asset_mode.dart';
import 'aster_account_service.dart';
import 'aster_account_mapper.dart';

import 'package:decimal/decimal.dart';

import 'futures_asset_mode_mapper.dart';
import 'signed_account_request.dart';

class SignedFuturesAssetModeRepository implements FuturesAssetModeRepository {
  SignedFuturesAssetModeRepository(
    this.service,
    this.sign, {
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  SignedAccountRequest _request(
    Future<Object?> Function({required String query, required String signature}) send,
  ) => SignedAccountRequest(serverTime: service.serverTime, send: send, sign: sign, nonces: nonces);

  @override
  Future<FuturesAssetModeContext> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AssetModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      void progress(AccountReadStep step) => onStep(switch (step) {
        AccountReadStep.signing => AssetModeStep.signingContext,
        AccountReadStep.loading => AssetModeStep.loadingContext,
        _ => AssetModeStep.preparing,
      });
      final mode = mapFuturesAssetMode(
        await _request(service.assetMode)
            .read(address: address, isCurrent: isCurrent, onStep: progress),
      );
      final receivedAt = now();
      final isolatedSymbols = mapAssetModeIsolatedSymbols(
        await _request(service.positionRisk)
            .read(address: address, isCurrent: isCurrent, onStep: progress),
      );
      Decimal? usdt;
      if (mode == FuturesAssetMode.multi) {
        final account = mapAsterAccount(
          await _request(service.account)
              .read(address: address, isCurrent: isCurrent, onStep: progress),
          address: address,
          receivedAt: now(),
        );
        usdt = account.assets.where((a) => a.asset == 'USDT').singleOrNull?.walletBalance;
      }
      return FuturesAssetModeContext(
        address: address,
        current: mode,
        isolatedSymbols: isolatedSymbols,
        receivedAt: receivedAt,
        usdtWalletBalance: usdt,
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });

  @override
  Future<AssetModeResult> change({
    required AssetModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(AssetModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    if (intent.context.blocks(intent.target) || intent.target == intent.context.current) {
      throw const AccountReadFailure('assetModeChangeBlocked');
    }
    var submitted = false;
    AccountReadFailure? submitFailure;
    try {
      await _request(({required query, required signature}) {
        if (!canSubmit()) throw const AccountReadFailure('assetModeContextExpired');
        submitted = true;
        onStep(AssetModeStep.submitting);
        return service.changeAssetMode(query: query, signature: signature);
      }).read(
        address: intent.context.address,
        parameters: {'multiAssetsMargin': intent.target.parameter},
        isCurrent: isCurrent,
        onStep: (step) {
          if (!canSubmit()) throw const AccountReadFailure('assetModeContextExpired');
          if (step != AccountReadStep.loading) {
            onStep(
              step == AccountReadStep.signing ? AssetModeStep.signing : AssetModeStep.preparing,
            );
          }
        },
      );
    } on AccountReadFailure catch (failure) {
      if (!submitted || !isCurrent()) rethrow;
      submitFailure = failure;
    }
    final result = await recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
    return AssetModeResult(
      observed: result.observed,
      checkedAt: result.checkedAt,
      failure: result.failure ?? (result.observed == intent.target ? null : submitFailure),
    );
  });

  @override
  Future<AssetModeResult> recheck({
    required AssetModeIntent intent,
    required bool Function() isCurrent,
    required void Function(AssetModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      final payload = await _request(service.assetMode).read(
        address: intent.context.address,
        isCurrent: isCurrent,
        onStep: (step) => onStep(
          step == AccountReadStep.signing ? AssetModeStep.checkSigning : AssetModeStep.checking,
        ),
      );
      return AssetModeResult(observed: mapFuturesAssetMode(payload), checkedAt: now());
    } on FormatException {
      return const AssetModeResult(failure: AccountReadFailure('accountDataInvalid'));
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      return AssetModeResult(failure: failure);
    }
  });
}
