import '../../../core/network/request_scope.dart';
import '../domain/aster_account.dart';
import 'aster_account_mapper.dart';
import 'aster_account_service.dart';
import 'signed_account_request.dart';
export 'signed_account_request.dart';

class SignedAccountRepository implements AsterAccountRepository {
  final AccountRequestAuthorization? authorization;
  SignedAccountRepository(
    this.service,
    AccountRequestSigner sign, {
    this.authorization,
    DateTime Function()? now,
    AsterReadNonces? nonces,
  }) : now = now ?? DateTime.now,
       _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.account,
         sign: sign,
         authorization: authorization,
         nonces: nonces,
       );
  final AsterAccountService service;
  final DateTime Function() now;
  final SignedAccountRequest _request;

  @override
  Future<AsterAccount> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    try {
      final payload = await _request.read(address: address, isCurrent: isCurrent, onStep: onStep);
      final receivedAt = now();
      mapAsterAccount(payload, address: address, receivedAt: receivedAt);
      Map<String, AsterContractUnits> units;
      try {
        units = await service.contractUnits();
      } catch (_) {
        // Preserve signed data when public contract units cannot be loaded.
        units = const {};
      }
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      return mapAsterAccount(payload, address: address, receivedAt: receivedAt, units: units);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });
}
