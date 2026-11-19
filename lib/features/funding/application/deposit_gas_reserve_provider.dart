import '../../../core/network/network_providers.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/deposit_gas_reserve_repository.dart';
import '../data/deposit_rpc_service.dart';

final depositGasReserveRepositoryProvider = Provider.autoDispose<RpcDepositGasReserveRepository>((
  ref,
) {
  final service = DepositRpcService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return RpcDepositGasReserveRepository(service);
});

/// Native gas to keep in the wallet for a deposit on `chainId`, from the
/// public gas price. A failed read leaves the hint out; it is not retried.
final depositGasReserveProvider = FutureProvider.autoDispose.family<Decimal, int>((ref, chain) {
  final repository = ref.watch(depositGasReserveRepositoryProvider);
  return repository.reserve(chain, isCurrent: () => ref.mounted);
}, retry: (_, _) => null);
