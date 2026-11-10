import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/futures_position_mode.dart';
import 'aster_account_service.dart';
import 'aster_open_orders_mapper.dart';
import 'futures_position_mode_mapper.dart';
import 'signed_account_request.dart';

class SignedFuturesPositionModeRepository implements FuturesPositionModeRepository {
  final AccountRequestAuthorization? authorization;
  SignedFuturesPositionModeRepository(
    this.service,
    this.sign, {
    this.authorization,
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  SignedAccountRequest _request(
    Future<Object?> Function({required String query, required String signature}) send,
  ) => SignedAccountRequest(
    serverTime: service.serverTime,
    send: send,
    sign: sign,
    authorization: authorization,
    nonces: nonces,
  );

  @override
  Future<FuturesPositionModeContext> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(PositionModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      void progress(AccountReadStep step) => onStep(switch (step) {
        AccountReadStep.signing => PositionModeStep.signingContext,
        AccountReadStep.loading => PositionModeStep.loadingContext,
        _ => PositionModeStep.preparing,
      });
      final mode = mapFuturesPositionMode(
        await _request(service.positionMode)
            .read(address: address, isCurrent: isCurrent, onStep: progress),
      );
      final receivedAt = now();
      final hasPosition = hasPositionModeBlocker(
        await _request(service.positionRisk)
            .read(address: address, isCurrent: isCurrent, onStep: progress),
        mode,
      );
      final payload = await _request(service.openOrders)
          .read(address: address, isCurrent: isCurrent, onStep: progress);
      final orders = mapAsterOpenOrders(payload, address: address, receivedAt: now());
      if (orders.orders.any(
        (order) => mode == FuturesPositionMode.oneWay
            ? order.positionSide != 'BOTH'
            : !{'LONG', 'SHORT'}.contains(order.positionSide),
      )) {
        throw const FormatException('Conflicting order mode');
      }
      return FuturesPositionModeContext(
        address: address,
        current: mode,
        hasPosition: hasPosition,
        openOrderCount: orders.orders.length,
        receivedAt: receivedAt,
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });

  @override
  Future<PositionModeResult> change({
    required PositionModeIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(PositionModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    if (intent.context.blocked || intent.target == intent.context.current) {
      throw const AccountReadFailure('positionModeChangeBlocked');
    }
    var submitted = false;
    AccountReadFailure? submitFailure;
    try {
      await _request(({required query, required signature}) {
        if (!canSubmit()) throw const AccountReadFailure('positionModeContextExpired');
        submitted = true;
        onStep(PositionModeStep.submitting);
        return service.changePositionMode(query: query, signature: signature);
      }).read(
        address: intent.context.address,
        parameters: {'dualSidePosition': intent.target.parameter},
        isCurrent: isCurrent,
        onStep: (step) {
          if (!canSubmit()) throw const AccountReadFailure('positionModeContextExpired');
          if (step != AccountReadStep.loading) {
            onStep(
              step == AccountReadStep.signing
                  ? PositionModeStep.signing
                  : PositionModeStep.preparing,
            );
          }
        },
      );
    } on AccountReadFailure catch (failure) {
      if (!submitted || !isCurrent()) rethrow;
      submitFailure = AccountReadFailure(
        switch (failure.code) {
          -4059 => 'positionModeAlreadySet',
          -4067 => 'positionModeOpenOrders',
          -4068 => 'positionModeHasPosition',
          _ => failure.key,
        },
        code: failure.code,
        details: failure.details,
      );
    }
    final result = await recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
    return PositionModeResult(
      observed: result.observed,
      checkedAt: result.checkedAt,
      failure: result.failure ?? (result.observed == intent.target ? null : submitFailure),
    );
  });

  @override
  Future<PositionModeResult> recheck({
    required PositionModeIntent intent,
    required bool Function() isCurrent,
    required void Function(PositionModeStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      final payload = await _request(service.positionMode).read(
        address: intent.context.address,
        isCurrent: isCurrent,
        onStep: (step) => onStep(
          step == AccountReadStep.signing
              ? PositionModeStep.checkSigning
              : PositionModeStep.checking,
        ),
      );
      return PositionModeResult(observed: mapFuturesPositionMode(payload), checkedAt: now());
    } on FormatException {
      return const PositionModeResult(failure: AccountReadFailure('accountDataInvalid'));
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      return PositionModeResult(failure: failure);
    }
  });
}
