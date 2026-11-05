import '../../portfolio/domain/account_snapshot.dart';
import '../../auth/domain/wallet_transaction.dart';
import '../domain/deposit_approval.dart';
import 'deposit_rpc_service.dart';

class RpcDepositApprovalReceiptRepository implements DepositApprovalReceiptRepository {
  RpcDepositApprovalReceiptRepository(this.service, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final DepositRpcService service;
  final DateTime Function() now;
  @override
  Future<DepositApprovalReceipt> read(
    DepositApprovalRecord record,
    String hash, {
    required bool Function() isCurrent,
  }) => readTransaction(record.transaction, record.baseBlock, hash, isCurrent: isCurrent);

  Future<DepositApprovalReceipt> readTransaction(
    EvmWalletTransaction expected,
    BigInt baseBlock,
    String hash, {
    required bool Function() isCurrent,
  }) async {
    void current() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    }

    bool same(Object? a, String b) => a is String && a.toLowerCase() == b.toLowerCase();
    final chain = expected.chainId;
    try {
      current();
      if (!validFundingHash(hash)) {
        throw const FormatException();
      }
      final chainId = rpcQuantity(await service.read(chain, 'eth_chainId', []));
      current();
      if (chainId != BigInt.from(chain)) throw const AccountReadFailure('depositRpcWrongChain');
      final tx = await service.read(chain, 'eth_getTransactionByHash', [hash]);
      current();
      if (tx == null) {
        return DepositApprovalReceipt(
          hash: hash,
          bound: false,
          status: DepositReceiptStatus.pending,
        );
      }
      if (tx is! Map<String, dynamic> ||
          !same(tx['hash'], hash) ||
          !same(tx['from'], expected.from) ||
          rpcQuantity(tx['chainId']) != BigInt.from(chain) ||
          rpcQuantity(tx['nonce']) != expected.nonce) {
        throw const AccountReadFailure('depositApprovalMismatch');
      }
      if (tx['input'] is! String ||
          !RegExp(r'^0x(?:[a-fA-F0-9]{2})*$').hasMatch(tx['input'] as String) ||
          tx['to'] != null &&
              (tx['to'] is! String ||
                  !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(tx['to'] as String))) {
        throw const FormatException();
      }
      final value = rpcQuantity(tx['value']);
      final matchesIntent =
          same(tx['to'], expected.to) &&
          same(tx['input'], expected.data) &&
          value == expected.value;
      final receipt = await service.read(chain, 'eth_getTransactionReceipt', [hash]);
      current();
      if (receipt == null) {
        return DepositApprovalReceipt(
          hash: hash,
          bound: true,
          matchesIntent: matchesIntent,
          status: DepositReceiptStatus.pending,
        );
      }
      if (receipt is! Map<String, dynamic> ||
          !same(receipt['transactionHash'], hash) ||
          !same(receipt['from'], expected.from) ||
          (tx['to'] == null ? receipt['to'] != null : !same(receipt['to'], tx['to'] as String)) ||
          !validFundingHash(receipt['blockHash'] is String ? receipt['blockHash'] as String : '')) {
        throw const FormatException();
      }
      final block = rpcQuantity(receipt['blockNumber']), status = rpcQuantity(receipt['status']);
      if (status > BigInt.one ||
          block < baseBlock ||
          rpcQuantity(tx['blockNumber']) != block ||
          !same(tx['blockHash'], receipt['blockHash'] as String)) {
        throw const FormatException();
      }
      final used = rpcQuantity(receipt['gasUsed']), limit = rpcQuantity(tx['gas']);
      final price = receipt['effectiveGasPrice'] ?? tx['gasPrice'];
      if (used > limit || used == BigInt.zero) throw const FormatException();
      final head = await service.read(chain, 'eth_getBlockByNumber', ['latest', false]);
      current();
      if (head is! Map<String, dynamic>) throw const FormatException();
      final height = rpcQuantity(head['number']), stamp = rpcQuantity(head['timestamp']);
      if (head['hash'] is! String ||
          !validFundingHash(head['hash'] as String) ||
          height == block && !same(head['hash'], receipt['blockHash'] as String)) {
        throw const AccountReadFailure('depositRpcReorg');
      }
      if (stamp <= BigInt.zero || stamp > BigInt.from(253402300799) || height < block) {
        throw const FormatException();
      }
      final age = now().toUtc().difference(
        DateTime.fromMillisecondsSinceEpoch(stamp.toInt() * 1000, isUtc: true),
      );
      if (age.abs() >= const Duration(minutes: 2)) {
        throw const AccountReadFailure('depositReadStale');
      }
      final canonical = await service.read(chain, 'eth_getBlockByNumber', [
        '0x${block.toRadixString(16)}',
        false,
      ]);
      current();
      if (canonical is! Map<String, dynamic> ||
          rpcQuantity(canonical['number']) != block ||
          !same(canonical['hash'], receipt['blockHash'] as String)) {
        throw const AccountReadFailure('depositRpcReorg');
      }
      final depth = height - block + BigInt.one;
      return DepositApprovalReceipt(
        hash: hash,
        bound: true,
        matchesIntent: matchesIntent,
        blockNumber: block,
        confirmations: depth > BigInt.from(2147483647) ? 2147483647 : depth.toInt(),
        gasFee: price == null ? null : used * rpcQuantity(price),
        status: depth < BigInt.two
            ? DepositReceiptStatus.pending
            : !matchesIntent
            ? DepositReceiptStatus.replaced
            : status == BigInt.one
            ? DepositReceiptStatus.succeeded
            : DepositReceiptStatus.reverted,
      );
    } on AccountReadFailure {
      rethrow;
    } on FormatException {
      throw const AccountReadFailure('depositRpcInvalid');
    }
  }
}
