import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/position_leverage.dart';
import 'aster_account_service.dart';
import 'position_leverage_mapper.dart';
import 'signed_account_request.dart';

class SignedPositionLeverageRepository implements PositionLeverageRepository {
  final AccountRequestAuthorization? authorization;
  SignedPositionLeverageRepository(
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
  Future<PositionLeverageContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(LeverageStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      validateLeverageSymbol(symbol);
      void progress(AccountReadStep step) => onStep(switch (step) {
        AccountReadStep.signing => LeverageStep.signingContext,
        AccountReadStep.loading => LeverageStep.loadingContext,
        _ => LeverageStep.preparing,
      });
      final brackets = mapLeverageBrackets(
        await _request(service.leverageBrackets).read(
          address: address,
          parameters: {'symbol': symbol},
          isCurrent: isCurrent,
          onStep: progress,
        ),
        symbol,
      );
      final receivedAt = now();
      final current = mapCurrentLeverage(
        await _request(service.positionRisk).read(
          address: address,
          parameters: {'symbol': symbol},
          isCurrent: isCurrent,
          onStep: progress,
        ),
        symbol,
      );
      return PositionLeverageContext(
        address: address,
        symbol: symbol,
        current: current,
        receivedAt: receivedAt,
        brackets: brackets,
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });

  @override
  Future<LeverageResult> change({
    required LeverageIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LeverageStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    final context = intent.context;
    try {
      validateLeverageSymbol(context.symbol);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
    if (context.target('${intent.target}') != intent.target) {
      throw const AccountReadFailure('leverageInvalidTarget');
    }
    var submitted = false;
    AccountReadFailure? submitFailure;
    try {
      await _request(({required query, required signature}) {
        // Repeat the lease check at the actual send boundary. An expired
        // confirmation or a late wallet approval must not submit a write.
        if (!canSubmit()) throw const AccountReadFailure('leverageContextExpired');
        submitted = true;
        onStep(LeverageStep.submitting);
        return service.changeLeverage(query: query, signature: signature);
      }).read(
        address: context.address,
        parameters: {'symbol': context.symbol, 'leverage': '${intent.target}'},
        isCurrent: isCurrent,
        onStep: (step) {
          if (!canSubmit()) throw const AccountReadFailure('leverageContextExpired');
          if (step != AccountReadStep.loading) {
            onStep(step == AccountReadStep.signing ? LeverageStep.signing : LeverageStep.preparing);
          }
        },
      );
    } on AccountReadFailure catch (failure) {
      if (!submitted || !isCurrent()) rethrow;
      submitFailure = AccountReadFailure(
        switch (failure.code) {
          -2027 => 'leverageExposureLimit',
          -2028 => 'leverageMarginInsufficient',
          -4028 => 'leverageNotAllowed',
          _ => failure.key,
        },
        code: failure.code,
        details: failure.details,
      );
    }
    final result = await recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
    return LeverageResult(
      observed: result.observed,
      checkedAt: result.checkedAt,
      failure: result.failure ?? (result.observed == intent.target ? null : submitFailure),
    );
  });

  @override
  Future<LeverageResult> recheck({
    required LeverageIntent intent,
    required bool Function() isCurrent,
    required void Function(LeverageStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      validateLeverageSymbol(intent.context.symbol);
      final payload = await _request(service.positionRisk).read(
        address: intent.context.address,
        parameters: {'symbol': intent.context.symbol},
        isCurrent: isCurrent,
        onStep: (step) => onStep(
          step == AccountReadStep.signing ? LeverageStep.checkSigning : LeverageStep.checking,
        ),
      );
      return LeverageResult(
        observed: mapCurrentLeverage(payload, intent.context.symbol),
        checkedAt: now(),
      );
    } on FormatException {
      return const LeverageResult(failure: AccountReadFailure('accountDataInvalid'));
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      return LeverageResult(failure: failure);
    }
  });
}
