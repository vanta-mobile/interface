import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/position_margin_mode.dart';
import 'aster_account_service.dart';
import 'aster_open_orders_mapper.dart';
import 'position_configuration_rows.dart';
import 'position_margin_mode_mapper.dart';
import 'signed_account_request.dart';

class SignedPositionMarginModeRepository implements PositionMarginModeRepository {
  SignedPositionMarginModeRepository(
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
  Future<PositionMarginModeContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(MarginModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      validatePositionSymbol(symbol);
      void progress(AccountReadStep step) => onStep(switch (step) {
        AccountReadStep.signing => MarginModeStep.signingContext,
        AccountReadStep.loading => MarginModeStep.loadingContext,
        _ => MarginModeStep.preparing,
      });
      final config = mapMarginConfiguration(
        await _request(service.positionRisk).read(
          address: address,
          parameters: {'symbol': symbol},
          isCurrent: isCurrent,
          onStep: progress,
        ),
        symbol,
      );
      final receivedAt = now();
      final payload = await _request(service.openOrders).read(
        address: address,
        parameters: {'symbol': symbol},
        isCurrent: isCurrent,
        onStep: progress,
      );
      if (payload is! List ||
          payload.any((row) => row is! Map<String, dynamic> || row['symbol'] != symbol)) {
        throw const FormatException('Wrong order scope');
      }
      final orders = mapAsterOpenOrders(payload, address: address, receivedAt: now());
      return PositionMarginModeContext(
        address: address,
        symbol: symbol,
        current: config.mode,
        hasPosition: config.hasPosition,
        openOrderCount: orders.orders.length,
        receivedAt: receivedAt,
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });

  @override
  Future<MarginModeResult> change({
    required MarginModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(MarginModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      validatePositionSymbol(intent.context.symbol);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
    if (intent.context.blocked || intent.target == intent.context.current) {
      throw const AccountReadFailure('marginModeChangeBlocked');
    }
    var submitted = false;
    AccountReadFailure? submitFailure;
    try {
      await _request(({required query, required signature}) {
        if (!canSubmit()) throw const AccountReadFailure('marginModeContextExpired');
        submitted = true;
        onStep(MarginModeStep.submitting);
        return service.changeMarginMode(query: query, signature: signature);
      }).read(
        address: intent.context.address,
        parameters: {'symbol': intent.context.symbol, 'marginType': intent.target.parameter},
        isCurrent: isCurrent,
        onStep: (step) {
          if (!canSubmit()) throw const AccountReadFailure('marginModeContextExpired');
          if (step != AccountReadStep.loading) {
            onStep(
              step == AccountReadStep.signing ? MarginModeStep.signing : MarginModeStep.preparing,
            );
          }
        },
      );
    } on AccountReadFailure catch (failure) {
      if (!submitted || !isCurrent()) rethrow;
      submitFailure = AccountReadFailure(
        switch (failure.code) {
          -4046 => 'marginModeAlreadySet',
          -4047 => 'marginModeOpenOrders',
          -4048 => 'marginModeHasPosition',
          _ => failure.key,
        },
        code: failure.code,
        details: failure.details,
      );
    }
    final result = await recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
    return MarginModeResult(
      observed: result.observed,
      checkedAt: result.checkedAt,
      failure: result.failure ?? (result.observed == intent.target ? null : submitFailure),
    );
  });

  @override
  Future<MarginModeResult> recheck({
    required MarginModeIntent intent,
    required bool Function() isCurrent,
    required void Function(MarginModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      validatePositionSymbol(intent.context.symbol);
      final payload = await _request(service.positionRisk).read(
        address: intent.context.address,
        parameters: {'symbol': intent.context.symbol},
        isCurrent: isCurrent,
        onStep: (step) => onStep(
          step == AccountReadStep.signing ? MarginModeStep.checkSigning : MarginModeStep.checking,
        ),
      );
      return MarginModeResult(
        observed: mapMarginConfiguration(payload, intent.context.symbol).mode,
        checkedAt: now(),
      );
    } on FormatException {
      return const MarginModeResult(failure: AccountReadFailure('accountDataInvalid'));
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      return MarginModeResult(failure: failure);
    }
  });
}
