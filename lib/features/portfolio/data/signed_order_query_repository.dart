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
    this.notFoundRetryDelays = defaultNotFoundRetryDelays,
  });

  /// A just-dispatched order may not be readable yet. -2013 is retried after
  /// these delays before it is reported; it never leads to a re-POST.
  static const defaultNotFoundRetryDelays = [Duration(seconds: 1), Duration(seconds: 2)];
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  final OrderRecoveryJournal? journal;
  final List<Duration> notFoundRetryDelays;
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
    Future<Object?> lookup() async {
      endpoint = strategy == null ? '/fapi/v3/order' : '/fapi/v3/strategyOpenOrder';
      try {
        return await read(strategy == null ? service.queryOrder : service.strategyOpenOrder);
      } on AccountReadFailure catch (failure) {
        if (strategy == null || failure.code != -2013 || !isCurrent()) rethrow;
        endpoint = '/fapi/v3/strategyHistoryOrder';
        return read(service.strategyHistoryOrder);
      }
    }

    try {
      Object? payload;
      for (var attempt = 0; ; attempt++) {
        try {
          payload = await lookup();
          break;
        } on AccountReadFailure catch (failure) {
          if (failure.code != -2013 || attempt >= notFoundRetryDelays.length || !isCurrent()) {
            rethrow;
          }
          await _wait(notFoundRetryDelays[attempt], isCurrent);
        }
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

/// Waits in short slices so that leaving the operation stops the backoff.
Future<void> _wait(Duration delay, bool Function() isCurrent) async {
  const slice = Duration(milliseconds: 100);
  var left = delay;
  while (left > Duration.zero) {
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    final step = left < slice ? left : slice;
    await Future<void>.delayed(step);
    left -= step;
  }
  if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
}
