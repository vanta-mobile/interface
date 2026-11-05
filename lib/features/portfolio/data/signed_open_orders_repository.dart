import '../domain/aster_account.dart';
import '../domain/aster_open_orders.dart';
import 'aster_account_service.dart';
import 'aster_open_orders_mapper.dart';
import 'signed_account_request.dart';

class SignedOpenOrdersRepository implements AsterOpenOrdersRepository {
  SignedOpenOrdersRepository(
    this.service,
    AccountRequestSigner sign, {
    DateTime Function()? now,
    AsterReadNonces? nonces,
  }) : now = now ?? DateTime.now,
       _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.openOrders,
         sign: sign,
         nonces: nonces,
       );
  final AsterAccountService service;
  final DateTime Function() now;
  final SignedAccountRequest _request;

  @override
  Future<AsterOpenOrders> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    final payload = await _request.read(address: address, isCurrent: isCurrent, onStep: onStep);
    try {
      final snapshotTime = now();
      final snapshot = mapAsterOpenOrders(payload, address: address, receivedAt: snapshotTime);
      if (snapshot.orders.isEmpty) return snapshot;
      final units = await (() async {
        try {
          return await service.contractUnits();
        } catch (_) {
          return const <String, AsterContractUnits>{};
        }
      })();
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      return mapAsterOpenOrders(payload, address: address, receivedAt: snapshotTime, units: units);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
