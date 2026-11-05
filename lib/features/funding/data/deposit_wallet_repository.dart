import '../../portfolio/domain/account_snapshot.dart';
import '../domain/deposit_wallet.dart';
import '../domain/funding_catalog.dart';
import 'deposit_rpc_service.dart';

class RpcDepositWalletRepository implements DepositWalletRepository {
  RpcDepositWalletRepository(this.service, {DateTime Function()? now}) : now = now ?? DateTime.now;
  final DepositRpcService service;
  final DateTime Function() now;
  @override
  Future<DepositWalletSnapshot> read({
    required String address,
    required DepositWalletQuery query,
    required bool Function() isCurrent,
  }) async {
    void current() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    }

    try {
      final asset = query.asset, spender = depositVaults[query.asset.chainId];
      final ownerWord = rpcAddressWord(address);
      if (spender == null ||
          asset.decimals < 0 ||
          asset.decimals > 255 ||
          asset.isNative && asset.decimals != 18 ||
          asset.isNative != (asset.tokenAddress.toLowerCase() == fundingNativePlaceholder)) {
        throw const FormatException();
      }
      rpcAddressWord(asset.tokenAddress);
      current();
      final chain = rpcQuantity(await service.read(asset.chainId, 'eth_chainId', []));
      current();
      if (chain != BigInt.from(asset.chainId)) {
        throw const AccountReadFailure('depositRpcWrongChain');
      }
      final block = await service.read(asset.chainId, 'eth_getBlockByNumber', ['latest', false]);
      current();
      if (block is! Map<String, dynamic>) throw const FormatException();
      final height = rpcQuantity(block['number']),
          time = rpcQuantity(block['timestamp']),
          hash = block['hash'];
      if (hash is! String ||
          !RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(hash) ||
          time <= BigInt.zero ||
          time > BigInt.from(253402300799)) {
        throw const FormatException();
      }
      final blockTag = '0x${height.toRadixString(16)}';
      final values = await Future.wait([
        service.read(asset.chainId, 'eth_getBalance', [address, blockTag]),
        if (!asset.isNative) ...[
          service.read(asset.chainId, 'eth_call', [
            {'to': asset.tokenAddress, 'data': '0x313ce567'},
            blockTag,
          ]),
          service.read(asset.chainId, 'eth_call', [
            {'to': asset.tokenAddress, 'data': '0x70a08231$ownerWord'},
            blockTag,
          ]),
          service.read(asset.chainId, 'eth_call', [
            {'to': asset.tokenAddress, 'data': '0xdd62ed3e$ownerWord${rpcAddressWord(spender)}'},
            blockTag,
          ]),
        ],
      ]);
      current();
      final finalBlock = await service.read(asset.chainId, 'eth_getBlockByNumber', [
        blockTag,
        false,
      ]);
      current();
      if (finalBlock is! Map<String, dynamic> || finalBlock['hash'] != hash) {
        throw const AccountReadFailure('depositRpcReorg');
      }
      final native = rpcQuantity(values[0]);
      if (!asset.isNative && rpcUint256(values[1]) != BigInt.from(asset.decimals)) {
        throw const AccountReadFailure('depositTokenDecimalsChanged');
      }
      final receivedAt = now().toUtc();
      final blockTime = DateTime.fromMillisecondsSinceEpoch(time.toInt() * 1000, isUtc: true);
      if (blockTime.isAfter(receivedAt.add(const Duration(minutes: 2)))) {
        throw const FormatException();
      }
      return DepositWalletSnapshot(
        address: address,
        query: query,
        receivedAt: receivedAt,
        assetUnits: asset.isNative ? native : rpcUint256(values[2]),
        nativeUnits: native,
        allowanceUnits: asset.isNative ? null : rpcUint256(values[3]),
        blockNumber: height,
        blockHash: hash,
        blockTime: blockTime,
      );
    } on AccountReadFailure {
      rethrow;
    } on FormatException {
      throw const AccountReadFailure('depositRpcInvalid');
    }
  }
}
