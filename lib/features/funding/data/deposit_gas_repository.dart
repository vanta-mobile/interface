import '../../../core/network/request_scope.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_rpc_service.dart';
import 'deposit_wallet_repository.dart';

class RpcDepositGasRepository implements DepositGasRepository {
  RpcDepositGasRepository(this.service, {DateTime Function()? now}) : now = now ?? DateTime.now;
  final DepositRpcService service;
  final DateTime Function() now;
  @override
  Future<DepositGasQuote> estimate({
    required String address,
    required DepositWalletQuery query,
    required String amount,
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    void current() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    }

    try {
      current();
      if (query.asset.routeType != 'normal') {
        throw const AccountReadFailure('depositGasRouteUnsupported');
      }
      final wallet = await RpcDepositWalletRepository(
        service,
        now: now,
      ).read(address: address, query: query, isCurrent: isCurrent);
      current();
      bool fresh() {
        final age = now().toUtc().difference(wallet.receivedAt);
        return age >= Duration.zero &&
            age < const Duration(seconds: 30) &&
            now().toUtc().difference(wallet.blockTime) < const Duration(minutes: 2);
      }

      final check = checkDepositAmount(
        input: amount,
        query: query,
        snapshot: wallet,
        stale: !fresh(),
      );
      if (check.errorKey case final key?) throw AccountReadFailure(key);
      if (check.units == null) throw const AccountReadFailure('depositAmountInvalid');
      final transaction = nextDepositTransaction(wallet, check.units!), chain = query.asset.chainId;
      final price = rpcQuantity(await service.read(chain, 'eth_gasPrice', []));
      current();
      final latest = rpcQuantity(
        await service.read(chain, 'eth_getTransactionCount', [address, 'latest']),
      );
      current();
      final nonce = rpcQuantity(
        await service.read(chain, 'eth_getTransactionCount', [address, 'pending']),
      );
      current();
      if (nonce < latest) throw const AccountReadFailure('depositRpcInvalid');
      if (price <= BigInt.zero || nonce >= (BigInt.one << 64) - BigInt.one) {
        throw const FormatException();
      }
      // Every supported EVM transaction consumes at least 21,000 gas. Prove
      // obvious shortages locally: nodes may reject the simulation before
      // returning an estimate (notably Max native deposits or zero gas funds).
      if (transaction.value + BigInt.from(21000) * price > wallet.nativeUnits) {
        throw const AccountReadFailure('depositGasBalanceInsufficient');
      }
      final estimated = rpcQuantity(
        await service.read(chain, 'eth_estimateGas', [
          {...transaction.call, 'gasPrice': depositHex(price), 'nonce': depositHex(nonce)},
          'pending',
        ]),
      );
      current();
      if (estimated <= BigInt.zero) throw const FormatException();
      // Explicit client reserve: ceil(estimate × 1.20), not actual consumed gas.
      final limit = (estimated * BigInt.from(120) + BigInt.from(99)) ~/ BigInt.from(100);
      final block = await service.read(chain, 'eth_getBlockByNumber', [
        depositHex(wallet.blockNumber),
        false,
      ]);
      current();
      if (block is! Map<String, dynamic> || block['hash'] != wallet.blockHash) {
        throw const AccountReadFailure('depositRpcReorg');
      }
      final blockLimit = rpcQuantity(block['gasLimit']);
      if (limit > blockLimit) throw const AccountReadFailure('depositGasBlockLimit');
      final after = rpcQuantity(
        await service.read(chain, 'eth_getTransactionCount', [address, 'pending']),
      );
      current();
      if (after != nonce) throw const AccountReadFailure('depositGasPendingTransactions');
      if (!fresh()) throw const AccountReadFailure('depositReadStale');
      final quote = DepositGasQuote(
        wallet: wallet,
        transaction: transaction,
        estimatedGas: estimated,
        gasLimit: limit,
        gasPrice: price,
        nonce: nonce,
        receivedAt: now().toUtc(),
      );
      if (quote.nativeRequired > wallet.nativeUnits) {
        throw const AccountReadFailure('depositGasBalanceInsufficient');
      }
      return quote;
    } on AccountReadFailure {
      rethrow;
    } on FormatException {
      throw const AccountReadFailure('depositRpcInvalid');
    }
  });
}
