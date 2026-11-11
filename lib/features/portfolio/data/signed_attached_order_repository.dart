import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/attached_order.dart';
import '../domain/live_order.dart';
import 'aster_account_service.dart';
import 'attached_order_mapper.dart';
import 'signed_account_request.dart';
import 'signed_order_query_repository.dart';
import 'order_recovery_boundary.dart';
import '../domain/order_query.dart';
import '../domain/order_recovery.dart';

class SignedAttachedOrderRepository {
  final AccountRequestAuthorization? authorization;
  SignedAttachedOrderRepository(
    this.service,
    this.sign,
    this.nonces,
    this.now, {
    this.authorization,
    this.journal,
  });
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  final OrderRecoveryJournal? journal;

  SignedAccountRequest _request(
    Future<Object?> Function({required String query, required String signature}) send,
  ) => SignedAccountRequest(
    serverTime: service.serverTime,
    send: send,
    sign: sign,
    authorization: authorization,
    nonces: nonces,
  );

  Future<LiveOrderResult> submit({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LiveOrderStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    var submitted = false;
    AccountReadFailure? postFailure;
    try {
      final payload =
          await _request(({required query, required signature}) async {
            if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
            recordOrderAttempt(journal, intent, now());
            if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
            submitted = true;
            onStep(LiveOrderStep.submitting);
            return service.placeStrategyOrder(query: query, signature: signature);
          }).read(
            address: intent.context.address,
            parameters: intent.strategyParameters,
            isCurrent: isCurrent,
            onStep: (step) {
              if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
              if (step != AccountReadStep.loading) {
                onStep(
                  step == AccountReadStep.signing ? LiveOrderStep.signing : LiveOrderStep.preparing,
                );
              }
            },
          );
      checkAttachedOrderAcknowledgement(payload);
    } on AccountReadFailure catch (failure) {
      if (!submitted || !isCurrent()) rethrow;
      // -1102 is a concrete gateway parameter-validation rejection. It is
      // not the ambiguous transport/acknowledgement case below, and querying
      // an order that could not be created must not turn it into "unknown".
      if (failure.code == -1102 &&
          failure.details?.status == 400 &&
          failure.details?.cause == null) {
        completeOrderRecord(journal, OrderQuery.capture(intent).key);
        return LiveOrderResult(failure: failure, rejected: true);
      }
      postFailure = failure;
    }
    // A failed acknowledgement can still follow an accepted request. Only
    // matching strategy/leg/linkage queries resolve the unknown; never re-POST.
    final result = await recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
    return result.needsRecheck && postFailure != null
        ? LiveOrderResult(failure: postFailure)
        : result;
  });

  Future<LiveOrderResult> recheck({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    return SignedOrderQueryRepository(
      service,
      sign,
      nonces,
      now,
      journal: journal,
      authorization: authorization,
    ).query(OrderQuery.capture(intent), isCurrent: isCurrent, onStep: onStep);
  });
}
