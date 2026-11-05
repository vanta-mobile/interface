import '../domain/aster_account.dart';
import '../domain/position_risk.dart';
import 'aster_account_service.dart';
import 'position_risk_mapper.dart';
import 'signed_account_request.dart';

class SignedPositionRiskRepository implements PositionRiskRepository {
  SignedPositionRiskRepository(
    this.service,
    AccountRequestSigner sign, {
    DateTime Function()? now,
    AsterReadNonces? nonces,
  }) : now = now ?? DateTime.now,
       _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.positionRisk,
         sign: sign,
         nonces: nonces,
       );
  final AsterAccountService service;
  final DateTime Function() now;
  final SignedAccountRequest _request;

  @override
  Future<PositionRiskSnapshot> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    final payload = await _request.read(address: address, isCurrent: isCurrent, onStep: onStep);
    try {
      final receivedAt = now();
      mapPositionRisk(payload, address: address, receivedAt: receivedAt);
      Map<String, AsterContractUnits> units;
      try {
        units = await service.contractUnits();
      } catch (_) {
        units = const {};
      }
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      return mapPositionRisk(payload, address: address, receivedAt: receivedAt, units: units);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
