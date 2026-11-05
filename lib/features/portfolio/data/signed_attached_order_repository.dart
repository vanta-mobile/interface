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
  SignedAttachedOrderRepository(this.service, this.sign, this.nonces, this.now, {this.journal});
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  final OrderRecoveryJournal? journal;

  SignedAccountRequest _request(
    Future<Object?> Function({required String query, required String signature}) send,
  ) => SignedAccountRequest(serverTime: service.serverTime, send: send, sign: sign, nonces: nonces);

  Future<LiveOrderResult> submit({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LiveOrderStep) onStep,
  }) async {
    var submitted = false;
    AccountReadFailure? postFailure;
    try {
      final payload =
          await _request(({required query, required signature}) async {
            if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
            await persistOrderBeforePost(journal, intent, now(), canSubmit);
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
      postFailure = failure;
    }
    // A failed acknowledgement can still follow an accepted request. Only
    // matching strategy/leg/linkage queries resolve the unknown; never re-POST.
    final result = await recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
    return result.needsRecheck && postFailure != null
        ? LiveOrderResult(failure: postFailure)
        : result;
  }

  Future<LiveOrderResult> recheck({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  }) async {
    return SignedOrderQueryRepository(
      service,
      sign,
      nonces,
      now,
      journal: journal,
    ).query(OrderQuery.capture(intent), isCurrent: isCurrent, onStep: onStep);
  }
}
