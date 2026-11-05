import '../domain/deposit_approval.dart';
import '../domain/deposit_submission.dart';
import 'deposit_approval_receipt_repository.dart';

class RpcDepositSubmissionReceiptRepository implements DepositSubmissionReceiptRepository {
  RpcDepositSubmissionReceiptRepository(this.receipts);
  final RpcDepositApprovalReceiptRepository receipts;
  @override
  Future<DepositApprovalReceipt> read(
    DepositSubmissionRecord record,
    String hash, {
    required bool Function() isCurrent,
  }) => receipts.readTransaction(record.transaction, record.baseBlock, hash, isCurrent: isCurrent);
}
