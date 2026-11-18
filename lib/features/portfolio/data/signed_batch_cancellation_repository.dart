import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/aster_open_orders.dart';
import '../domain/aster_account.dart' show AsterContractUnits;
import '../domain/order_cancellation.dart';
import 'aster_account_service.dart';
import 'aster_open_orders_mapper.dart';
import 'signed_account_request.dart';

class SignedBatchCancellationRepository implements BatchOrderCancellationRepository {
  final AccountRequestAuthorization? authorization;
  SignedBatchCancellationRepository(
    this.service,
    this.sign, {
    this.authorization,
    required this.nonces,
  });
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;

  @override
  Future<BatchSymbolCancellation> cancelSymbol({
    required String address,
    required String symbol,
    required Iterable<AsterOpenOrder> originalOrders,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    var submitted = false;
    AccountReadFailure? cancelFailure;
    try {
      final payload = await _request(service.cancelAllOrders).read(
        address: address,
        parameters: _parameters(symbol),
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
      // An explicit success leaves no open order for the symbol. Only a
      // response that does not confirm it is looked up again.
      if (payload is Map<String, dynamic> && '${payload['code']}' == '200') {
        return BatchSymbolCancellation(
          symbol: symbol,
          submitted: true,
          snapshot: AsterOpenOrders(
            address: address,
            receivedAt: DateTime.now(),
            orders: const [],
            units: _units(symbol, originalOrders),
          ),
        );
      }
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      if (!submitted) {
        return BatchSymbolCancellation(symbol: symbol, submitted: false, failure: failure);
      }
      cancelFailure = failure;
    }
    final checked = await recheckSymbol(
      address: address,
      symbol: symbol,
      originalOrders: originalOrders,
      isCurrent: isCurrent,
      onStep: onStep,
    );
    return BatchSymbolCancellation(
      symbol: symbol,
      submitted: true,
      snapshot: checked.snapshot,
      failure: checked.failure ?? (checked.snapshot?.orders.isEmpty == true ? null : cancelFailure),
    );
  });

  @override
  Future<BatchSymbolCancellation> recheckSymbol({
    required String address,
    required String symbol,
    required Iterable<AsterOpenOrder> originalOrders,
    required bool Function() isCurrent,
    required void Function(OrderCancelStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      final payload = await _request(service.openOrders).read(
        address: address,
        parameters: _parameters(symbol),
        isCurrent: isCurrent,
        onStep: (step) => onStep(
          step == AccountReadStep.signing ? OrderCancelStep.checkSigning : OrderCancelStep.checking,
        ),
      );
      // Every row, including terminal rows, must belong to the requested
      // symbol. A malformed response must not erase another symbol's orders.
      if (payload is! List<dynamic> ||
          payload.any((row) => row is! Map<String, dynamic> || row['symbol'] != symbol)) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final snapshot = mapAsterOpenOrders(
        payload,
        address: address,
        receivedAt: DateTime.now(),
        units: _units(symbol, originalOrders),
      );
      return BatchSymbolCancellation(symbol: symbol, submitted: true, snapshot: snapshot);
    } on AccountReadFailure catch (failure) {
      if (!isCurrent()) rethrow;
      return BatchSymbolCancellation(symbol: symbol, submitted: true, failure: failure);
    } on FormatException {
      return BatchSymbolCancellation(
        symbol: symbol,
        submitted: true,
        failure: const AccountReadFailure('accountDataInvalid'),
      );
    } catch (_) {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      return BatchSymbolCancellation(
        symbol: symbol,
        submitted: true,
        failure: const AccountReadFailure('accountReadFailed'),
      );
    }
  });

  static Map<String, AsterContractUnits> _units(String symbol, Iterable<AsterOpenOrder> orders) {
    final units = <String, AsterContractUnits>{};
    for (final order in orders) {
      final unit = order.units;
      if (order.symbol == symbol && unit != null) units[symbol] = unit;
    }
    return units;
  }

  SignedAccountRequest _request(
    Future<Object?> Function({required String query, required String signature}) send,
  ) => SignedAccountRequest(
    serverTime: service.serverTime,
    send: send,
    sign: sign,
    authorization: authorization,
    nonces: nonces,
  );

  Map<String, String> _parameters(String symbol) {
    if (!RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    return {'symbol': symbol};
  }
}
