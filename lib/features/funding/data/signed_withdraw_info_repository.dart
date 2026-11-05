import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/withdraw_info.dart';
import 'withdraw_info_mapper.dart';

class SignedWithdrawInfoRepository implements WithdrawInfoRepository {
  SignedWithdrawInfoRepository(
    AsterAccountService service,
    AccountRequestSigner sign, {
    required AsterReadNonces nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.withdrawInfo,
         sign: sign,
         nonces: nonces,
         nanosecondNonce: true,
         signatureLifetime: const Duration(seconds: 30),
       );
  final SignedAccountRequest request;
  final DateTime Function() now;
  @override
  Future<WithdrawInfo> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    final payload = await request.read(address: address, isCurrent: isCurrent, onStep: onStep);
    try {
      return mapWithdrawInfo(payload, address: address, receivedAt: now());
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
