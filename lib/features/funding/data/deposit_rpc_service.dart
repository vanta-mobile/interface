import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../market/data/market_http_client.dart';
import '../../portfolio/domain/account_snapshot.dart';

const depositRpcOrigins = {
  1: 'https://ethereum-rpc.publicnode.com',
  56: 'https://bsc-rpc.publicnode.com',
  42161: 'https://arbitrum-one-rpc.publicnode.com',
};

/// Read-only JSON-RPC transport. No signing or broadcasting method is exposed.
class DepositRpcService {
  DepositRpcService({http.Client? client, this.timeout = const Duration(seconds: 12)})
    : _client = client ?? createMarketHttpClient();
  final http.Client _client;
  final Duration timeout;
  int _id = 0;
  Future<Object?> read(int chain, String method, List<Object?> params) async {
    final origin = depositRpcOrigins[chain];
    if (origin == null ||
        !const [
          'eth_chainId',
          'eth_getBlockByNumber',
          'eth_getBalance',
          'eth_call',
          'eth_gasPrice',
          'eth_getTransactionCount',
          'eth_estimateGas',
          'eth_getTransactionByHash',
          'eth_getTransactionReceipt',
        ].contains(method)) {
      throw const AccountReadFailure('depositRpcInvalid');
    }
    final id = ++_id;
    try {
      final response = await (() async {
        final request = http.Request('POST', Uri.parse(origin))
          ..followRedirects = false
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
        return http.Response.fromStream(await _client.send(request));
      })().timeout(timeout);
      if (response.statusCode == 429) throw const AccountReadFailure('accountRateLimited');
      if (response.statusCode != 200) throw const AccountReadFailure('depositRpcFailed');
      if (response.bodyBytes.length > 131072) throw const FormatException();
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is! Map<String, dynamic> ||
          payload['jsonrpc'] != '2.0' ||
          payload['id'] != id ||
          !payload.containsKey('result') && !payload.containsKey('error')) {
        throw const AccountReadFailure('depositRpcInvalid');
      }
      if (payload.containsKey('error')) {
        throw AccountReadFailure(
          method == 'eth_estimateGas' ? 'depositGasSimulationFailed' : 'depositRpcInvalid',
        );
      }
      return payload['result'];
    } on AccountReadFailure {
      rethrow;
    } on FormatException {
      throw const AccountReadFailure('depositRpcInvalid');
    } on TimeoutException {
      throw const AccountReadFailure('accountNetwork');
    } catch (_) {
      throw const AccountReadFailure('accountNetwork');
    }
  }

  void close() => _client.close();
}

BigInt rpcQuantity(Object? value) {
  if (value is! String || !RegExp(r'^0x(?:0|[1-9a-fA-F][a-fA-F0-9]{0,63})$').hasMatch(value)) {
    throw const FormatException();
  }
  return BigInt.parse(value.substring(2), radix: 16);
}

BigInt rpcUint256(Object? value) {
  if (value is! String || !RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(value)) {
    throw const FormatException();
  }
  return BigInt.parse(value.substring(2), radix: 16);
}

String rpcAddressWord(String address) {
  if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address) ||
      BigInt.parse(address.substring(2), radix: 16) == BigInt.zero) {
    throw const FormatException();
  }
  return address.substring(2).toLowerCase().padLeft(64, '0');
}
