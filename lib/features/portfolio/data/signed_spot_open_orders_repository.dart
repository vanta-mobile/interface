import '../domain/spot_history.dart';
import '../domain/spot_open_orders.dart';
import '../domain/account_snapshot.dart';
import 'aster_spot_service.dart';
import 'signed_account_request.dart';
import 'spot_history_mapper.dart';
import 'spot_open_orders_mapper.dart';

class SignedSpotOpenOrdersRepository implements SpotOpenOrdersRepository {
  SignedSpotOpenOrdersRepository(
    this.service,
    AccountRequestSigner sign, {
    AsterReadNonces? nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.openOrders,
         sign: sign,
         nonces: nonces,
       );
  final AsterSpotService service;
  final SignedAccountRequest _request;
  final DateTime Function() now;
  @override
  Future<SpotOpenOrders> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    final payload = await _request.read(address: address, isCurrent: isCurrent, onStep: onStep);
    try {
      final receivedAt = now().toUtc();
      final snapshot = mapSpotOpenOrders(payload, address: address, receivedAt: receivedAt);
      if (snapshot.orders.isEmpty) return snapshot;
      Map<String, SpotSymbolUnits> units;
      try {
        units = mapSpotSymbolUnits(await service.exchangeInfo());
      } catch (_) {
        units = const {};
      }
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      return mapSpotOpenOrders(payload, address: address, receivedAt: receivedAt, units: units);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
