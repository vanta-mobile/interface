import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/funding/data/deposit_rpc_service.dart';
import 'package:vanta/features/funding/data/deposit_wallet_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  String word(BigInt value) => '0x${value.toRadixString(16).padLeft(64, '0')}';
  late List<Map<String, dynamic>> calls;
  late int chain;
  late Map<String, Object?> block;
  late Object? Function(Map<String, dynamic>) response;
  late DepositRpcService service;
  late RpcDepositWalletRepository repository;
  late bool current;
  Object? normal(Map<String, dynamic> request) {
    final params = request['params'] as List<dynamic>;
    return switch (request['method']) {
      'eth_chainId' => '0x${chain.toRadixString(16)}',
      'eth_getBlockByNumber' => block,
      'eth_getBalance' => '0x8ac7230489e80000',
      'eth_call' => switch ((params.first as Map<String, dynamic>)['data'] as String) {
        '0x313ce567' => word(BigInt.from(18)),
        final String data when data.startsWith('0x70a08231') => word(
          BigInt.parse('9007199254740993123456789'),
        ),
        _ => word((BigInt.one << 256) - BigInt.one),
      },
      _ => throw StateError('Unexpected RPC method'),
    };
  }

  setUp(() {
    calls = [];
    chain = 56;
    current = true;
    block = {
      'number': '0x123',
      'hash': '0x${'a' * 64}',
      'timestamp': '0x${(now.millisecondsSinceEpoch ~/ 1000).toRadixString(16)}',
    };
    response = normal;
    service = DepositRpcService(
      client: MockClient((request) async {
        expect(request.url.toString(), depositRpcOrigins[chain]);
        expect(request.method, 'POST');
        expect(request.followRedirects, false);
        expect(request.headers['Content-Type'], 'application/json');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        calls.add(payload);
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': payload['id'], 'result': response(payload)}),
          200,
        );
      }),
    );
    repository = RpcDepositWalletRepository(service, now: () => now);
  });
  tearDown(() => service.close());
  for (final network in [1, 56, 42161]) {
    test('token balances/decimals/allowance use exact words and one checked block on $network', () async {
      chain = network;
      final query = depositQuery(chain: network);
      final snapshot = await repository.read(
        address: accountAddress,
        query: query,
        isCurrent: () => current,
      );
      expect(snapshot.assetUnits.toString(), '9007199254740993123456789');
      expect(snapshot.allowanceUnits, (BigInt.one << 256) - BigInt.one);
      expect(snapshot.assetBalance.toString(), '9007199.254740993123456789');
      expect(snapshot.nativeBalance.toString(), '10');
      expect(snapshot.blockTime, now);
      expect(calls.length, 7);
      expect(calls.where((r) => r['method'] == 'eth_getBlockByNumber').length, 2);
      for (final rpc in calls.where((r) => ['eth_call', 'eth_getBalance'].contains(r['method']))) {
        expect((rpc['params'] as List<dynamic>).last, '0x123');
      }
      expect(
        ((calls[5]['params'] as List<dynamic>).first as Map<String, dynamic>)['data'],
        '0xdd62ed3e${rpcAddressWord(accountAddress)}${rpcAddressWord({'1': '0x604DD02d620633Ae427888d41bfd15e38483736E', '56': '0x128463A60784c4D3f46c23Af3f65Ed859Ba87974', '42161': '0x9E36CB86a159d479cEd94Fa05036f235Ac40E1d5'}['$network']!)}',
      );
      expect(calls.every((r) => !(r['method'] as String).startsWith('eth_send')), true);
    });
  }
  test(
    'native asset reads only chain, block and native balance, no ERC20 calls or allowance',
    () async {
      final snapshot = await repository.read(
        address: accountAddress,
        query: depositQuery(native: true),
        isCurrent: () => true,
      );
      expect(snapshot.assetUnits, snapshot.nativeUnits);
      expect(snapshot.allowance, null);
      expect(calls.map((r) => r['method']), [
        'eth_chainId',
        'eth_getBlockByNumber',
        'eth_getBalance',
        'eth_getBlockByNumber',
      ]);
    },
  );
  for (final scenario in ['chain', 'decimals', 'block', 'reorg', 'future', 'word']) {
    test('rejects inconsistent $scenario and never returns qualifying balance', () async {
      var blocks = 0;
      response = (request) {
        if (scenario == 'chain' && request['method'] == 'eth_chainId') return '0x1';
        if (request['method'] == 'eth_getBlockByNumber') {
          blocks++;
          if (scenario == 'block') return null;
          if (scenario == 'reorg' && blocks == 2) return {...block, 'hash': '0x${'b' * 64}'};
          if (scenario == 'future') {
            return {
              ...block,
              'timestamp': '0x${((now.millisecondsSinceEpoch ~/ 1000) + 1000).toRadixString(16)}',
            };
          }
        }
        if (request['method'] == 'eth_call' &&
            ((request['params'] as List<dynamic>).first as Map<String, dynamic>)['data'] ==
                '0x313ce567') {
          if (scenario == 'decimals') return word(BigInt.from(6));
          if (scenario == 'word') return '0x12';
        }
        return normal(request);
      };
      await expectLater(
        repository.read(address: accountAddress, query: depositQuery(), isCurrent: () => true),
        throwsA(isA<AccountReadFailure>()),
      );
      if (scenario == 'chain') expect(calls.length, 1);
    });
  }
  test('invalid address/native decimals rejected before RPC', () async {
    await expectLater(
      repository.read(address: 'invalid', query: depositQuery(), isCurrent: () => true),
      throwsA(isA<AccountReadFailure>()),
    );
    await expectLater(
      repository.read(
        address: accountAddress,
        query: depositQuery(native: true, decimals: 6),
        isCurrent: () => true,
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(calls, isEmpty);
  });
  test('scope lost after chain response sends no further RPC requests', () async {
    response = (request) {
      current = false;
      return normal(request);
    };
    await expectLater(
      repository.read(address: accountAddress, query: depositQuery(), isCurrent: () => current),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    expect(calls.length, 1);
  });
  for (final raw in ['0x', '0x00', '0x-1', '0x${'1' * 65}', 1, null]) {
    test('rejects noncanonical or non-string RPC quantity $raw', () {
      expect(() => rpcQuantity(raw), throwsFormatException);
    });
  }
  test('RPC service refuses broadcast methods and unsupported chain before HTTP', () async {
    await expectLater(
      service.read(56, 'eth_sendTransaction', []),
      throwsA(isA<AccountReadFailure>()),
    );
    await expectLater(service.read(999, 'eth_chainId', []), throwsA(isA<AccountReadFailure>()));
    expect(calls, isEmpty);
  });
  for (final issue in ['redirect', 'rate', 'malformed', 'error', 'id', 'oversize', 'network']) {
    test('RPC transport reports safe $issue without exposing raw response', () async {
      service.close();
      service = DepositRpcService(
        client: MockClient((request) async {
          if (issue == 'network') throw const FormatException('sensitive raw detail');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            switch (issue) {
              'malformed' => '{bad',
              'oversize' => ' ' * 131073,
              'error' => jsonEncode({
                'jsonrpc': '2.0',
                'id': payload['id'],
                'error': {'code': -32000, 'message': 'sensitive raw detail'},
              }),
              'id' => jsonEncode({'jsonrpc': '2.0', 'id': 999, 'result': '0x38'}),
              _ => '{}',
            },
            issue == 'redirect'
                ? 302
                : issue == 'rate'
                ? 429
                : 200,
          );
        }),
      );
      await expectLater(service.read(56, 'eth_chainId', []), throwsA(isA<AccountReadFailure>()));
    });
  }
  test('timeout returns safe network failure', () async {
    service.close();
    final gate = Completer<http.Response>();
    service = DepositRpcService(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => gate.future),
    );
    await expectLater(
      service.read(56, 'eth_chainId', []),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountNetwork')),
    );
    gate.complete(http.Response('{}', 200));
  });
}
