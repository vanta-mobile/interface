import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/subaccount_directory.dart';
import 'subaccount_list_mapper.dart';

class SignedSubaccountListRepository implements SubaccountListRepository {
  SignedSubaccountListRepository(
    AsterAccountService service,
    AccountRequestSigner sign, {
    AsterReadNonces? nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       _request = SignedAccountRequest(
         serverTime: service.serverTime,
         send: service.subaccountList,
         sign: sign,
         nonces: nonces,
       );
  final DateTime Function() now;
  final SignedAccountRequest _request;
  @override
  Future<SubaccountDirectory> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    final payload = await _request.read(address: address, isCurrent: isCurrent, onStep: onStep);
    try {
      return mapSubaccountDirectory(payload, address: address, receivedAt: now());
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
