import 'package:decimal/decimal.dart';

import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/aster_open_orders.dart';
import '../domain/order_cancellation.dart';
import '../domain/order_modification.dart';
import 'aster_account_service.dart';
import 'signed_account_request.dart';

/// Signed `PUT /fapi/v3/order` for one LIMIT order. An ambiguous outcome is
/// resolved by querying the order through [verifier]; the PUT is never resent.
class SignedOrderModificationRepository implements OrderModificationRepository {
  SignedOrderModificationRepository(
    this.service,
    this.sign, {
    required this.verifier,
    required this.nonces,
    this.authorization,
  });
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final OrderCancellationRepository verifier;
  final AsterReadNonces nonces;
  final AccountRequestAuthorization? authorization;

  /// Aster codes meaning the backend may still have executed the request.
  static const _unknownCodes = {-1000, -1001, -1006, -1007};

  @override
  Future<OrderModificationResult> modify({
    required String address,
    required OrderModification request,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    final order = request.order;
    var submitted = false;
    AccountReadFailure? failure;
    try {
      final payload =
          await SignedAccountRequest(
            serverTime: service.serverTime,
            send: service.modifyOrder,
            sign: sign,
            authorization: authorization,
            nonces: nonces,
          ).read(
            address: address,
            parameters: _parameters(request),
            isCurrent: isCurrent,
            onStep: (step) {
              if (step == AccountReadStep.loading) submitted = true;
              onStep(switch (step) {
                AccountReadStep.signing => OrderCancelStep.signing,
                AccountReadStep.loading => OrderCancelStep.submitting,
                _ => OrderCancelStep.preparing,
              });
            },
          );
      if (_modified(payload, request) case final updated?) {
        return OrderModificationResult(OrderModifyOutcome.modified, order: updated);
      }
      failure = const AccountReadFailure('accountDataInvalid');
    } on AccountReadFailure catch (error) {
      if (!submitted || !isCurrent()) rethrow;
      if (_refused(error)) {
        return OrderModificationResult(OrderModifyOutcome.rejected, order: order, failure: error);
      }
      failure = error;
    }
    final checked = await verifier.recheck(
      address: address,
      order: order,
      isCurrent: isCurrent,
      onStep: onStep,
    );
    final resolution = checked.resolution;
    if (resolution == null || !resolution.consistent) {
      return OrderModificationResult(
        OrderModifyOutcome.unknown,
        failure: checked.failure ?? failure,
      );
    }
    final current = resolution.openOrder;
    if (current != null && current.price == request.price && current.origQty == request.quantity) {
      return OrderModificationResult(OrderModifyOutcome.modified, order: current);
    }
    return OrderModificationResult(
      OrderModifyOutcome.rejected,
      order: current,
      closed: resolution.terminal,
      failure: failure,
    );
  });

  /// An explicit client-side refusal leaves the original order untouched.
  static bool _refused(AccountReadFailure error) {
    final status = error.details?.status;
    if (status == 429 || status == 418) return true;
    return error.code != null &&
        !_unknownCodes.contains(error.code) &&
        status != null &&
        status >= 400 &&
        status < 500;
  }

  /// The PUT response carries no placement time, so the verified terms are
  /// applied to the known order instead of re-mapping the row.
  static AsterOpenOrder? _modified(Object? payload, OrderModification request) {
    final order = request.order;
    if (payload is! Map<String, dynamic> ||
        payload['symbol'] != order.symbol ||
        '${payload['orderId']}' != order.orderId ||
        payload['type'] != 'LIMIT' ||
        payload['side'] != order.side) {
      return null;
    }
    final status = payload['status'];
    final price = _decimal(payload['price']);
    final quantity = _decimal(payload['origQty']);
    final executed = _decimal(payload['executedQty']);
    if (status is! String ||
        !const {'NEW', 'PARTIALLY_FILLED'}.contains(status) ||
        price != request.price ||
        quantity != request.quantity ||
        executed == null ||
        executed < Decimal.zero ||
        executed >= quantity!) {
      return null;
    }
    final updated = payload['updateTime'];
    return AsterOpenOrder(
      symbol: order.symbol,
      orderId: order.orderId,
      side: order.side,
      positionSide: order.positionSide,
      type: order.type,
      status: status,
      time: order.time,
      origQty: quantity,
      executedQty: executed,
      price: price!,
      stopPrice: order.stopPrice,
      workingType: order.workingType,
      pegPriceType: order.pegPriceType,
      reduceOnly: order.reduceOnly,
      timeInForce: order.timeInForce,
      units: order.units,
      updatedAt: updated is int && updated > 0
          ? DateTime.fromMillisecondsSinceEpoch(updated, isUtc: true)
          : order.updatedAt,
      originalType: order.originalType,
      transactionHash: order.transactionHash,
      clientOrderId: order.clientOrderId,
    );
  }

  static Decimal? _decimal(Object? value) =>
      value is String && RegExp(r'^\d+(\.\d+)?$').hasMatch(value) ? Decimal.parse(value) : null;

  static Map<String, String> _parameters(OrderModification request) {
    final order = request.order;
    if (!RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(order.symbol) ||
        !RegExp(r'^[1-9]\d{0,30}$').hasMatch(order.orderId) ||
        !const {'BUY', 'SELL'}.contains(order.side) ||
        request.price <= Decimal.zero ||
        request.quantity <= Decimal.zero) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    return {
      'symbol': order.symbol,
      'orderId': order.orderId,
      'side': order.side,
      'quantity': request.quantity.toString(),
      'price': request.price.toString(),
    };
  }
}
