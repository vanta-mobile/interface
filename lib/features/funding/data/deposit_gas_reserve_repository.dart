import 'package:decimal/decimal.dart';

import '../../../core/network/request_scope.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/deposit_wallet.dart';
import 'deposit_rpc_service.dart';

/// Gas units budgeted for one deposit from the wallet: an allowance approval
/// plus the vault deposit, with margin. Only sizes the top-up hint; the deposit
/// itself still runs its own exact estimate before anything is signed.
const depositGasBudget = 250000;

/// Native amount to keep in the wallet at the chain's current gas price.
class RpcDepositGasReserveRepository {
  RpcDepositGasReserveRepository(this.service);
  final DepositRpcService service;

  Future<Decimal> reserve(int chain, {required bool Function() isCurrent}) =>
      RequestScope.run(isCurrent, () async {
        try {
          final price = rpcQuantity(await service.read(chain, 'eth_gasPrice', []));
          if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
          if (price <= BigInt.zero) throw const FormatException();
          return depositQuantity(depositReserveRoundUp(price * BigInt.from(depositGasBudget)), 18);
        } on FormatException {
          throw const AccountReadFailure('depositRpcInvalid');
        }
      });
}

/// Rounds wei up to two significant digits so the hint reads as an estimate
/// and never falls below the computed amount.
BigInt depositReserveRoundUp(BigInt wei) {
  final digits = wei.toString().length;
  if (digits <= 2) return wei;
  final step = BigInt.from(10).pow(digits - 2);
  return (wei + step - BigInt.one) ~/ step * step;
}
