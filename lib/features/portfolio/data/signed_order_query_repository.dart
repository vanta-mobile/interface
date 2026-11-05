import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/order_query.dart';
import '../domain/order_recovery.dart';
import 'aster_account_service.dart';
import 'attached_order_mapper.dart';
import 'live_order_mapper.dart';
import 'signed_account_request.dart';

/// All paths here are GET-only, using original public IDs with fresh signatures.
class SignedOrderQueryRepository implements OrderRecoveryRepository {
  SignedOrderQueryRepository(this.service, this.sign, this.nonces, this.now, {this.journal});
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
  }) async {
    final strategy = query.draft.attachment;
    Future<Object?> read(
      Future<Object?> Function({required String query, required String signature}) send,
    ) =>
        SignedAccountRequest(
          serverTime: service.serverTime,
          send: send,
          sign: sign,
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
    try {
      Object? payload;
      try {
        payload = await read(strategy == null ? service.queryOrder : service.strategyOpenOrder);
      } on AccountReadFailure catch (failure) {
        if (strategy == null || failure.code != -2013 || !isCurrent()) rethrow;
        payload = await read(service.strategyHistoryOrder);
      }
      final result = strategy == null
          ? mapRecoveredOrderQuery(payload, query, checkedAt: now())
          : mapRecoveredStrategyQuery(payload, query, now());
      if (!result.needsRecheck) {
        try {
          await journal?.complete(query.key);
        } on AccountReadFailure {
          /* Keep the verified result and the durable pending entry. */
        }
      }
      return result;
    } on FormatException {
      return const LiveOrderResult(failure: AccountReadFailure('accountDataInvalid'));
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      return LiveOrderResult(failure: failure);
    }
  }
}
