import '../domain/account_snapshot.dart';
import '../domain/aster_spot_account.dart';
import 'aster_spot_mapper.dart';
import 'aster_spot_service.dart';
import 'signed_account_request.dart';

class SignedSpotRepository implements AsterSpotAccountRepository {
  SignedSpotRepository(
    AsterSpotService service,
    AccountRequestSigner sign, {
    DateTime Function()? now,
    AsterReadNonces? nonces,
  }) : now = now ?? DateTime.now,
       _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.account,
         sign: sign,
         nonces: nonces,
       );
  final DateTime Function() now;
  final SignedAccountRequest _request;

  @override
  Future<AsterSpotAccount> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    final payload = await _request.read(address: address, isCurrent: isCurrent, onStep: onStep);
    try {
      return mapAsterSpotAccount(payload, address: address, receivedAt: now());
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
