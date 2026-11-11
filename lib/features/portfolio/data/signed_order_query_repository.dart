import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/order_query.dart';
import '../domain/order_recovery.dart';
import 'aster_account_service.dart';
import 'attached_order_mapper.dart';
import 'live_order_mapper.dart';
import 'signed_account_request.dart';
import 'order_recovery_boundary.dart';
import 'order_response_failure.dart';

/// All paths here are GET-only, using original public IDs with fresh signatures.
class SignedOrderQueryRepository implements OrderRecoveryRepository {
  final AccountRequestAuthorization? authorization;
  SignedOrderQueryRepository(
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
  @override
  Future<LiveOrderResult> query(
    OrderQuery query, {
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    final strategy = query.draft.attachment;
    Future<Object?> read(
      Future<Object?> Function({required String query, required String signature}) send,
    ) =>
        SignedAccountRequest(
          serverTime: service.serverTime,
          send: send,
          sign: sign,
          authorization: authorization,
          nonces: nonces,
        ).read(
          address: query.address,
          isCurrent: isCurrent,
          parameters: strategy == null
              ? {'symbol': query.symbol, 'origClientOrderId': query.clientOrderId}
              : {'clientStrategyId': query.clientOrderId, 'strategyType': strategy.strategyType},
          onStep: (step) => onStep(
            step == AccountReadStep.signing ? LiveOrderStep.checkSigning : LiveOrderStep.checking,
          ),
        );
    var endpoint = strategy == null ? '/fapi/v3/order' : '/fapi/v3/strategyOpenOrder';
    try {
      Object? payload;
      try {
        payload = await read(strategy == null ? service.queryOrder : service.strategyOpenOrder);
      } on AccountReadFailure catch (failure) {
        if (strategy == null || failure.code != -2013 || !isCurrent()) rethrow;
        endpoint = '/fapi/v3/strategyHistoryOrder';
        payload = await read(service.strategyHistoryOrder);
      }
      final result = strategy == null
          ? mapRecoveredOrderQuery(payload, query, checkedAt: now())
          : mapRecoveredStrategyQuery(payload, query, now());
      if (!result.needsRecheck) {
        completeOrderRecord(journal, query.key);
      }
      return result;
    } on FormatException catch (failure) {
      return LiveOrderResult(failure: orderResponseFailure(failure, endpoint));
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      return LiveOrderResult(failure: failure);
    }
  });
}
