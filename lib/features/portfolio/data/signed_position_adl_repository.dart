import '../../../core/network/request_scope.dart';
import '../domain/position_adl.dart';
import 'aster_account_service.dart';
import 'position_adl_mapper.dart';
import 'signed_account_request.dart';

class SignedPositionAdlRepository implements PositionAdlRepository {
  SignedPositionAdlRepository(
    AsterAccountService service,
    AccountRequestSigner sign, {
    DateTime Function()? now,
    AsterReadNonces? nonces,
  }) : now = now ?? DateTime.now,
       _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.positionAdl,
         sign: sign,
         nonces: nonces,
       );
  final DateTime Function() now;
  final SignedAccountRequest _request;
  @override
  Future<PositionAdlSnapshot> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) => RequestScope.run(isCurrent, () async {
    final payload = await _request.read(address: address, isCurrent: isCurrent, onStep: onStep);
    try {
      return mapPositionAdl(payload, address: address, receivedAt: now());
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });
}
