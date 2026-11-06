import '../../../core/network/request_scope.dart';

import 'package:decimal/decimal.dart';

import '../domain/account_snapshot.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order.dart';
import '../domain/quick_order.dart';
import 'aster_account_service.dart';
import 'aster_open_orders_mapper.dart';
import 'position_leverage_mapper.dart';
import 'signed_account_request.dart';

class SignedQuickOrderRepository implements QuickOrderRepository {
  SignedQuickOrderRepository(this.service, this.sign, {required this.nonces});
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  @override
  Future<QuickOrderSizing> readSizing({
    required LiveOrderContext context,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    Future<Object?> read(
      Future<Object?> Function({required String query, required String signature}) send,
    ) =>
        SignedAccountRequest(
          serverTime: service.serverTime,
          send: send,
          sign: sign,
          nonces: nonces,
        ).read(
          address: context.address,
          parameters: {'symbol': context.symbol},
          isCurrent: isCurrent,
          onStep: onStep,
        );
    try {
      final feePayload = await read(service.commissionRate);
      if (feePayload is! Map<String, dynamic> || feePayload['symbol'] != context.symbol) {
        throw const FormatException();
      }
      final fee = parseOrderDecimal(
        feePayload['takerCommissionRate'] is String
            ? feePayload['takerCommissionRate'] as String
            : '',
      );
      if (fee == null || fee < Decimal.zero || fee >= Decimal.one) throw const FormatException();
      final brackets = mapLeverageBrackets(await read(service.leverageBrackets), context.symbol);
      final orders = mapAsterOpenOrders(
        await read(service.openOrders),
        address: context.address,
        receivedAt: context.receivedAt,
      );
      if (orders.orders.any(
        (o) =>
            o.symbol != context.symbol ||
            (context.mode == FuturesPositionMode.oneWay
                ? o.positionSide != 'BOTH'
                : o.positionSide == 'BOTH'),
      )) {
        throw const FormatException();
      }
      return QuickOrderSizing(context: context, takerFee: fee, brackets: brackets, orders: orders);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });
}
