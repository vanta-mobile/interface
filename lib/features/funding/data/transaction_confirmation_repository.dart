import '../../../core/network/request_scope.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/deposit_approval.dart';
import 'deposit_rpc_service.dart';

/// Reads whether an exchange-reported transfer hash is mined on its chain.
/// Read-only; the exchange record stays the source of the business status.
class RpcTransactionConfirmationRepository {
  RpcTransactionConfirmationRepository(this.service);
  final DepositRpcService service;

  /// `true` only for a successful receipt whose block is still canonical.
  /// Unmined, reverted or reorganized transactions read as `false`.
  Future<bool> confirmed(int chain, String hash, {required bool Function() isCurrent}) =>
      RequestScope.run(isCurrent, () async {
        void current() {
          if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
        }

        bool same(Object? a, String b) => a is String && a.toLowerCase() == b.toLowerCase();
        if (!depositRpcOrigins.containsKey(chain) || !validFundingHash(hash)) {
          throw const AccountReadFailure('depositRpcInvalid');
        }
        try {
          final chainId = rpcQuantity(await service.read(chain, 'eth_chainId', []));
          current();
          if (chainId != BigInt.from(chain)) {
            throw const AccountReadFailure('depositRpcWrongChain');
          }
          final receipt = await service.read(chain, 'eth_getTransactionReceipt', [hash]);
          current();
          if (receipt == null) return false;
          if (receipt is! Map<String, dynamic> ||
              !same(receipt['transactionHash'], hash) ||
              receipt['blockHash'] is! String ||
              !validFundingHash(receipt['blockHash'] as String)) {
            throw const FormatException();
          }
          final block = rpcQuantity(receipt['blockNumber']),
              status = rpcQuantity(receipt['status']);
          if (status > BigInt.one) throw const FormatException();
          if (status != BigInt.one) return false;
          final canonical = await service.read(chain, 'eth_getBlockByNumber', [
            '0x${block.toRadixString(16)}',
            false,
          ]);
          current();
          return canonical is Map<String, dynamic> &&
              same(canonical['hash'], receipt['blockHash'] as String);
        } on FormatException {
          throw const AccountReadFailure('depositRpcInvalid');
        }
      });
}
