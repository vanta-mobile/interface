import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/aster_open_orders.dart';
import '../domain/order_cancellation.dart';
import 'aster_account_service.dart';
import 'aster_open_orders_mapper.dart';
import 'signed_account_request.dart';

class SignedOrderCancellationRepository implements OrderCancellationRepository {
  SignedOrderCancellationRepository(this.service, this.sign, {required this.nonces});
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;

  @override
  Future<OrderCancellationResult> cancel({
    required String address,
    required AsterOpenOrder order,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    var submitted = false;
    AccountReadFailure? cancelFailure;
    try {
      await _request(service.cancelOrder).read(
        address: address,
        parameters: _parameters(order),
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
    } on AccountReadFailure catch (failure) {
      // A refused signature cannot have cancelled an order. Once a request
      // may have reached Aster, query its state; never repeat the DELETE.
      if (!submitted || !isCurrent()) rethrow;
      cancelFailure = failure;
    }
    final checked = await recheck(
      address: address,
      order: order,
      isCurrent: isCurrent,
      onStep: onStep,
    );
    return OrderCancellationResult(
      resolution: checked.resolution,
      failure: checked.failure ?? (checked.resolution?.terminal == true ? null : cancelFailure),
    );
  });

  @override
  Future<OrderCancellationResult> recheck({
    required String address,
    required AsterOpenOrder order,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      final payload = await _request(service.queryOrder).read(
        address: address,
        parameters: _parameters(order),
        isCurrent: isCurrent,
        onStep: (step) => onStep(
          step == AccountReadStep.signing ? OrderCancelStep.checkSigning : OrderCancelStep.checking,
        ),
      );
      if (payload is! Map<String, dynamic> ||
          payload['symbol'] != order.symbol ||
          '${payload['orderId']}' != order.orderId) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final status = payload['status'];
      if (status is! String ||
          !{
            'NEW',
            'PARTIALLY_FILLED',
            'CANCELED',
            'FILLED',
            'EXPIRED',
            'REJECTED',
          }.contains(status)) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final units = order.units;
      final parsed = mapAsterOpenOrders(
        [payload],
        address: address,
        receivedAt: DateTime.now(),
        units: units == null ? const {} : {order.symbol: units},
      );
      return OrderCancellationResult(
        resolution: OrderResolution(
          symbol: order.symbol,
          orderId: order.orderId,
          status: status,
          openOrder: parsed.orders.firstOrNull,
        ),
      );
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      return OrderCancellationResult(failure: failure);
    } on FormatException {
      return const OrderCancellationResult(failure: AccountReadFailure('accountDataInvalid'));
    } catch (_) {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      return const OrderCancellationResult(failure: AccountReadFailure('accountReadFailed'));
    }
  });

  SignedAccountRequest _request(
    Future<Object?> Function({required String query, required String signature}) send,
  ) => SignedAccountRequest(serverTime: service.serverTime, send: send, sign: sign, nonces: nonces);

  Map<String, String> _parameters(AsterOpenOrder order) {
    if (!RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(order.symbol) ||
        !RegExp(r'^[1-9]\d{0,30}$').hasMatch(order.orderId)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    return {'symbol': order.symbol, 'orderId': order.orderId};
  }
}
