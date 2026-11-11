import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/aster_open_orders.dart';
import '../domain/open_order_strategy.dart';
import 'aster_account_service.dart';
import 'open_order_strategy_mapper.dart';
import 'signed_account_request.dart';

/// Read-only `GET /fapi/v3/strategyOpenOrder` (weight 5) through the device
/// trading grant; without an active grant the request fails without prompting.
class SignedOpenOrderStrategyRepository implements OpenOrderStrategyRepository {
  SignedOpenOrderStrategyRepository(
    AsterAccountService service,
    AccountRequestSigner sign, {
    AccountRequestAuthorization? authorization,
    AsterReadNonces? nonces,
  }) : _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.strategyOpenOrder,
         sign: sign,
         authorization: authorization,
         nonces: nonces,
       );
  final SignedAccountRequest _request;

  @override
  Future<OpenOrderStrategy?> read({
    required String address,
    required AsterOpenOrder order,
    required OpenOrderStrategyQuery query,
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    for (final type in query.types) {
      final Object? payload;
      try {
        payload = await _request.read(
          address: address,
          isCurrent: isCurrent,
          onStep: (_) {},
          parameters: {...query.parameters, 'strategyType': type},
        );
      } on AccountReadFailure catch (failure) {
        // Not found under this type: try the next candidate type.
        if (failure.code == -2013) continue;
        rethrow;
      }
      try {
        return mapOpenOrderStrategy(payload, order);
      } on FormatException {
        throw const AccountReadFailure('accountDataInvalid');
      }
    }
    return null;
  });
}
