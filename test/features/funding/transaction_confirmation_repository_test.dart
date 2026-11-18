import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/funding/data/deposit_rpc_service.dart';
import 'package:vanta/features/funding/data/transaction_confirmation_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

void main() {
  final hash = '0x${'b' * 64}', blockHash = '0x${'c' * 64}';
  late Map<String, Object?>? receipt;
  late Map<String, Object?> canonical;
  late List<String> calls;
  late DepositRpcService service;
  late RpcTransactionConfirmationRepository repository;
  late bool current;
  var loseScope = false;

  setUp(() {
    calls = [];
    current = true;
    loseScope = false;
    receipt = {
      'transactionHash': hash,
      'blockHash': blockHash,
      'blockNumber': '0x10',
      'status': '0x1',
    };
    canonical = {'number': '0x10', 'hash': blockHash};
    service = DepositRpcService(
      client: MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final method = payload['method'] as String;
        calls.add(method);
        if (method == 'eth_chainId' && loseScope) current = false;
        final result = switch (method) {
          'eth_chainId' => '0x38',
          'eth_getTransactionReceipt' => receipt,
          'eth_getBlockByNumber' => canonical,
          _ => throw StateError('unexpected RPC'),
        };
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': payload['id'], 'result': result}),
          200,
        );
      }),
    );
    repository = RpcTransactionConfirmationRepository(service);
  });
  tearDown(() => service.close());

  Future<bool> read([String? candidate, int chain = 56]) =>
      repository.confirmed(chain, candidate ?? hash, isCurrent: () => current);

  test('a successful receipt in a canonical block is confirmed', () async {
    expect(await read(), true);
    expect(calls, ['eth_chainId', 'eth_getTransactionReceipt', 'eth_getBlockByNumber']);
  });
  test('unmined, reverted and reorganized transactions are not confirmed', () async {
    receipt = null;
    expect(await read(), false);
    receipt = {
      'transactionHash': hash,
      'blockHash': blockHash,
      'blockNumber': '0x10',
      'status': '0x0',
    };
    expect(await read(), false);
    receipt = {...receipt!, 'status': '0x1'};
    canonical = {'number': '0x10', 'hash': '0x${'d' * 64}'};
    expect(await read(), false);
  });
  test('malformed receipts fail safely', () async {
    receipt = {...receipt!, 'transactionHash': '0x${'e' * 64}'};
    await expectLater(
      read(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'depositRpcInvalid')),
    );
  });
  test('unsupported chains and non-EVM hashes send no request', () async {
    await expectLater(read('not-a-hash'), throwsA(isA<AccountReadFailure>()));
    await expectLater(read(null, 999), throwsA(isA<AccountReadFailure>()));
    expect(calls, isEmpty);
  });
  test('a lost scope stops before reading the receipt', () async {
    loseScope = true;
    await expectLater(
      read(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    expect(calls, isNot(contains('eth_getTransactionReceipt')));
  });
}
