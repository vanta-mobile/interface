import '../../../core/errors/api_error_details.dart';
import '../../../core/errors/api_error_parser.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../market/data/market_http_client.dart';
import '../../portfolio/domain/account_snapshot.dart';

/// Public read-only nodes per chain, in preference order. Probed 2026-11-18:
/// publicnode refuses older receipts (archive) with HTTP 403, so each chain
/// keeps nodes from other operators to fail over to.
const depositRpcOrigins = {
  1: ['https://ethereum-rpc.publicnode.com', 'https://eth.drpc.org', 'https://1rpc.io/eth'],
  56: [
    'https://bsc-dataseed.bnbchain.org',
    'https://bsc-rpc.publicnode.com',
    'https://bsc-dataseed1.defibit.io',
    'https://1rpc.io/bnb',
  ],
  42161: [
    'https://arb1.arbitrum.io/rpc',
    'https://arbitrum-one-rpc.publicnode.com',
    'https://arbitrum.drpc.org',
  ],
};

/// Read-only JSON-RPC transport. No signing or broadcasting method is exposed.
///
/// Every allowed method is a read, so a node that fails (transport, timeout,
/// HTTP status, malformed body or JSON-RPC error) is skipped for the next one.
/// The node that last answered stays preferred so one snapshot's reads keep
/// hitting the same node. Cancellation never fails over.
class DepositRpcService {
  DepositRpcService({http.Client? client, this.timeout = const Duration(seconds: 12)})
    : _client = createMarketHttpClient(client: client, timeout: timeout);
  final http.Client _client;
  final Duration timeout;
  final _preferred = <int, int>{};
  int _id = 0;
  Future<Object?> read(int chain, String method, List<Object?> params) async {
    final origins = depositRpcOrigins[chain];
    if (origins == null ||
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
    final start = _preferred[chain] ?? 0;
    late AccountReadFailure failure;
    for (var attempt = 0; attempt < origins.length; attempt++) {
      final index = (start + attempt) % origins.length;
      try {
        final result = await _readFrom(origins[index], method, params);
        _preferred[chain] = index;
        return result;
      } on _NodeFailure catch (error) {
        failure = error.failure;
      }
    }
    throw failure;
  }

  Future<Object?> _readFrom(String origin, String method, List<Object?> params) async {
    final id = ++_id;
    try {
      final response = await (() async {
        final request = http.Request('POST', Uri.parse(origin))
          ..followRedirects = false
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
        return http.Response.fromStream(await _client.send(request));
      })().timeout(timeout);
      if (response.statusCode == 429) {
        throw _NodeFailure(
          AccountReadFailure(
            'accountRateLimited',
            details: apiErrorDetails(
              decodeErrorPayload(response.body),
              status: response.statusCode,
            ),
          ),
        );
      }
      if (response.statusCode != 200) {
        throw _NodeFailure(
          AccountReadFailure(
            'depositRpcFailed',
            details: apiErrorDetails(
              decodeErrorPayload(response.body),
              status: response.statusCode,
            ),
          ),
        );
      }
      if (response.bodyBytes.length > 131072) throw const FormatException();
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is! Map<String, dynamic> ||
          payload['jsonrpc'] != '2.0' ||
          payload['id'] != id ||
          !payload.containsKey('result') && !payload.containsKey('error')) {
        throw const FormatException();
      }
      if (payload.containsKey('error')) {
        final failure = AccountReadFailure(
          method == 'eth_estimateGas' ? 'depositGasSimulationFailed' : 'depositRpcInvalid',
          details: apiErrorDetails(payload['error'], status: response.statusCode),
        );
        // A failed simulation is the chain's answer, not a node fault.
        if (method == 'eth_estimateGas') throw failure;
        throw _NodeFailure(failure);
      }
      return payload['result'];
    } on AccountReadFailure {
      rethrow;
    } on _NodeFailure {
      rethrow;
    } on FormatException {
      throw const _NodeFailure(AccountReadFailure('depositRpcInvalid'));
    } on TimeoutException {
      throw const _NodeFailure(
        AccountReadFailure(
          'accountNetwork',
          details: ApiErrorDetails(cause: ApiErrorCause.timeout),
        ),
      );
    } on http.RequestAbortedException {
      throw const AccountReadFailure(
        'accountNetwork',
        details: ApiErrorDetails(cause: ApiErrorCause.cancelled),
      );
    } catch (_) {
      throw const _NodeFailure(
        AccountReadFailure(
          'accountNetwork',
          details: ApiErrorDetails(cause: ApiErrorCause.connection),
        ),
      );
    }
  }

  void close() => _client.close();
}

/// A node-level failure that the next node may not share.
class _NodeFailure implements Exception {
  const _NodeFailure(this.failure);
  final AccountReadFailure failure;
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
