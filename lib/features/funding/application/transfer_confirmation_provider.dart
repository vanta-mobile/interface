import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/deposit_rpc_service.dart';
import '../data/transaction_confirmation_repository.dart';
import '../domain/deposit_approval.dart';
import '../domain/transfer_history.dart';

final transactionConfirmationRepositoryProvider =
    Provider.autoDispose<RpcTransactionConfirmationRepository>((ref) {
      final service = DepositRpcService(client: ref.watch(backendHttpPoolProvider).lease());
      ref.onDispose(service.close);
      return RpcTransactionConfirmationRepository(service);
    });

/// Chain confirmation of one record's hash, keyed by `(chainId, txHash)`.
/// No automatic retry: a refused or failed read falls back to the existing
/// copy instead of keeping the step loading.
final transferConfirmationProvider = FutureProvider.autoDispose.family<bool, (int, String)>((
  ref,
  key,
) {
  final repository = ref.watch(transactionConfirmationRepositoryProvider);
  return repository.confirmed(key.$1, key.$2, isCurrent: () => ref.mounted);
}, retry: (_, _) => null);

/// The confirmation key for a still-processing record whose hash this app can
/// read. Completed records need no chain read.
(int, String)? transferConfirmationKey(TransferRecord record) {
  final hash = record.txHash;
  return record.status == TransferStatus.processing &&
          hash != null &&
          depositRpcOrigins.containsKey(record.chainId) &&
          validFundingHash(hash)
      ? (record.chainId, hash)
      : null;
}
