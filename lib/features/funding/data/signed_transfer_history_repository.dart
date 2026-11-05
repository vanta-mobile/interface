import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/transfer_history.dart';
import 'transfer_history_mapper.dart';

class SignedTransferHistoryRepository implements TransferHistoryRepository {
  SignedTransferHistoryRepository(
    this.service,
    this.sign, {
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  @override
  Future<TransferHistory> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    final payload = await SignedAccountRequest(
      serverTime: service.serverTime,
      send: service.transferHistory,
      sign: sign,
      nonces: nonces,
      nanosecondNonce: true,
      signatureLifetime: const Duration(seconds: 30),
    ).read(address: address, isCurrent: isCurrent, onStep: onStep);
    try {
      return TransferHistory(
        address: address.toLowerCase(),
        receivedAt: now().toUtc(),
        records: mapTransferHistory(payload),
      );
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
