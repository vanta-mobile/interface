import 'package:decimal/decimal.dart';

import '../../../core/domain/wallet_operation.dart';
import 'transfer_history.dart';

/// Only the exact server-returned request ID binds a withdrawal to history.
/// Similar balance movements, amounts or the signature digest cannot bind it.
TransferRecord? reconcileWithdrawal(WalletOperationRecord operation, TransferHistory history) {
  if (operation.kind != WalletOperationKind.withdrawal ||
      operation.reference == null ||
      !operation.acknowledged ||
      history.address.toLowerCase() != operation.address.toLowerCase() ||
      history.receivedAt.isBefore(operation.preparedAt)) {
    return null;
  }
  final matches = history.records
      .where(
        (r) =>
            r.type == TransferType.withdraw &&
            r.id == operation.reference &&
            r.market.name == operation.terms['market'],
      )
      .toList();
  if (matches.length != 1) return null;
  final r = matches.single;
  if (r.chainId.toString() != operation.terms['chain'] ||
      r.asset != operation.terms['asset'] ||
      r.amount != Decimal.parse(operation.terms['amount']!) ||
      r.recordTime.isBefore(operation.preparedAt.subtract(const Duration(minutes: 5)))) {
    return null;
  }
  return r;
}
