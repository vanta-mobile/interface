import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/funding/data/deposit_gas_repository.dart';
import 'package:vanta/features/funding/data/deposit_rpc_service.dart';
import 'package:vanta/features/funding/domain/deposit_transaction.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_wallet.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  String hex(BigInt v) => '0x${v.toRadixString(16)}';
  String word(BigInt v) => '0x${v.toRadixString(16).padLeft(64, '0')}';
  late DateTime now;
  late List<Map<String, dynamic>> calls;
  late DepositWalletQuery query;
  late BigInt native, allowance;
  late Map<String, Object?> block;
  late Object? Function(Map<String, dynamic>) response;
  late DepositRpcService service;
  late RpcDepositGasRepository repository;
  late bool current, simulationError;
  Object? normal(Map<String, dynamic> request) {
    final params = request['params'] as List<dynamic>;
    return switch (request['method']) {
      'eth_chainId' => hex(BigInt.from(query.asset.chainId)),
      'eth_getBlockByNumber' => block,
      'eth_getBalance' => hex(native),
      'eth_call' => switch ((params.first as Map<String, dynamic>)['data'] as String) {
        '0x313ce567' => word(BigInt.from(query.asset.decimals)),
        final String d when d.startsWith('0x70a08231') => word(
          BigInt.parse('9007199254740993123456789'),
        ),
        _ => word(allowance),
      },
      'eth_gasPrice' => '0x3b9aca00',
      'eth_getTransactionCount' => '0x7',
      'eth_estimateGas' => '0x5209',
      _ => throw StateError('Unexpected method ${request['method']}'),
    };
  }

  Future<DepositGasQuote> estimate([String amount = '1.230000000000000001']) => repository.estimate(
    address: accountAddress,
    query: query,
    amount: amount,
    isCurrent: () => current,
  );
  Matcher fails(String key) =>
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'safe key', key));
  setUp(() {
    now = time;
    calls = [];
    query = depositQuery();
    native = BigInt.parse('10000000000000000000');
    allowance = (BigInt.one << 256) - BigInt.one;
    current = true;
    simulationError = false;
    block = {
      'number': '0x123',
      'hash': '0x${'a' * 64}',
      'timestamp': hex(BigInt.from(time.millisecondsSinceEpoch ~/ 1000)),
      'gasLimit': '0x1c9c380',
    };
    response = normal;
    service = DepositRpcService(
      client: MockClient((request) async {
        expect(request.url.toString(), depositRpcOrigins[query.asset.chainId]);
        expect(request.followRedirects, false);
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        calls.add(payload);
        return http.Response(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': payload['id'],
            if (simulationError && payload['method'] == 'eth_estimateGas')
              'error': {'code': -32000, 'message': 'private raw revert detail'}
            else
              'result': response(payload),
          }),
          200,
        );
      }),
    );
    repository = RpcDepositGasRepository(service, now: () => now);
  });
  tearDown(() => service.close());
  for (final chain in [1, 56, 42161]) {
    for (final nativeAsset in [false, true]) {
      test(
        'exact unsigned pending simulation and native fee reserve $chain/$nativeAsset',
        () async {
          query = depositQuery(chain: chain, native: nativeAsset, market: TransferMarket.spot);
          final quote = await estimate();
          expect(quote.transaction.kind, DepositTransactionKind.deposit);
          expect(quote.transaction.amountUnits.toString(), '1230000000000000001');
          expect(
            quote.wallet.assetUnits,
            nativeAsset ? native : BigInt.parse('9007199254740993123456789'),
          );
          expect(quote.estimatedGas, BigInt.from(21001));
          expect(quote.gasLimit, BigInt.from(25202));
          expect(quote.feeReserve.toString(), '25202000000000');
          expect(
            quote.nativeRequired,
            (nativeAsset ? quote.transaction.amountUnits : BigInt.zero) + quote.feeReserve,
          );
          final request = calls.singleWhere((c) => c['method'] == 'eth_estimateGas');
          expect(request['params'], [
            {
              'from': accountAddress,
              'to': depositVaults[chain],
              'data': quote.transaction.data,
              'value': nativeAsset ? '0x1111d67bb1bb0001' : '0x0',
              'gasPrice': '0x3b9aca00',
              'nonce': '0x7',
            },
            'pending',
          ]);
          expect(
            calls.where((c) => c['method'] == 'eth_getTransactionCount').map((c) => c['params']),
            [
              [accountAddress, 'latest'],
              [accountAddress, 'pending'],
              [accountAddress, 'pending'],
            ],
          );
          expect(
            calls.every(
              (c) => ![
                'eth_sendTransaction',
                'eth_sendRawTransaction',
                'personal_sign',
              ].contains(c['method']),
            ),
            true,
          );
        },
      );
    }
  }
  for (final initial in [BigInt.zero, BigInt.one]) {
    test('estimate covers only ${initial == BigInt.zero ? 'exact approval' : 'reset'}', () async {
      allowance = initial;
      final quote = await estimate();
      expect(
        quote.transaction.kind,
        initial == BigInt.zero
            ? DepositTransactionKind.approve
            : DepositTransactionKind.resetApproval,
      );
      expect(quote.transaction.to, query.asset.tokenAddress);
      expect(quote.transaction.value, BigInt.zero);
      expect(calls.where((c) => c['method'] == 'eth_estimateGas').length, 1);
      expect(quote.nativeRequired, quote.feeReserve);
    });
  }
  test('insufficient native balance blocks token approval reserve', () async {
    allowance = BigInt.zero;
    native = BigInt.one;
    await expectLater(estimate(), fails('depositGasBalanceInsufficient'));
  });
  test('native value fits but full-balance deposit cannot cover fee reserve', () async {
    query = depositQuery(native: true);
    await expectLater(estimate('10'), fails('depositGasBalanceInsufficient'));
  });
  test('exact native value plus padded fee is allowed', () async {
    query = depositQuery(native: true);
    native = BigInt.parse('1000025202000000000');
    final quote = await estimate('1');
    expect(quote.nativeRequired, native);
  });
  test('unsupported route rejected before any RPC', () async {
    query = depositQuery(route: 'bridge');
    await expectLater(estimate(), fails('depositGasRouteUnsupported'));
    expect(calls, isEmpty);
  });
  for (final amount in ['', '0', '-1', '0.01', '1.0000000000000000001', '1e2', '9007200']) {
    test('invalid/minimum/precision/balance amount "$amount" never estimates', () async {
      await expectLater(estimate(amount), throwsA(isA<AccountReadFailure>()));
      expect(calls.where((c) => c['method'] == 'eth_estimateGas'), isEmpty);
    });
  }
  for (final issue in [
    'pending',
    'nonceChanged',
    'nonceOverflow',
    'zeroPrice',
    'malformedPrice',
    'overflowPrice',
    'zeroGas',
    'malformedGas',
    'gasLimit',
    'reorg',
    'oldBlock',
    'slow',
    'clockBackwards',
  ]) {
    test('rejects $issue and cannot produce a usable quote', () async {
      var pendingCalls = 0, blocks = 0;
      response = (req) {
        if (req['method'] == 'eth_getBlockByNumber') {
          blocks++;
          if (issue == 'oldBlock') {
            return {
              ...block,
              'timestamp': hex(
                BigInt.from(
                  time.subtract(const Duration(seconds: 120)).millisecondsSinceEpoch ~/ 1000,
                ),
              ),
            };
          }
          if (blocks == 3 && issue == 'reorg') return {...block, 'hash': '0x${'b' * 64}'};
          if (blocks == 3 && issue == 'gasLimit') return {...block, 'gasLimit': '0x5209'};
        }
        if (req['method'] == 'eth_getTransactionCount') {
          if ((req['params'] as List).last == 'pending') pendingCalls++;
          if (issue == 'nonceOverflow') return '0xffffffffffffffff';
          if (issue == 'pending' && pendingCalls == 1) return '0x8';
          if (issue == 'nonceChanged' && pendingCalls == 2) return '0x8';
        }
        if (req['method'] == 'eth_gasPrice') {
          if (issue == 'zeroPrice') return '0x0';
          if (issue == 'malformedPrice') return '0x01';
          if (issue == 'overflowPrice') return '0x${'f' * 65}';
        }
        if (req['method'] == 'eth_estimateGas') {
          if (issue == 'zeroGas') return '0x0';
          if (issue == 'malformedGas') return 21000;
          if (issue == 'slow') now = time.add(const Duration(seconds: 30));
          if (issue == 'clockBackwards') now = time.subtract(const Duration(seconds: 1));
        }
        return normal(req);
      };
      await expectLater(
        estimate(),
        fails(switch (issue) {
          'pending' || 'nonceChanged' => 'depositGasPendingTransactions',
          'gasLimit' => 'depositGasBlockLimit',
          'reorg' => 'depositRpcReorg',
          'oldBlock' || 'slow' || 'clockBackwards' => 'depositReadStale',
          _ => 'depositRpcInvalid',
        }),
      );
    });
  }
  test('simulation error without result becomes safe localized failure', () async {
    simulationError = true;
    await expectLater(estimate(), fails('depositGasSimulationFailed'));
    expect(calls.last['method'], 'eth_estimateGas');
  });
  for (final stopAfter in ['eth_gasPrice', 'eth_getTransactionCount', 'eth_estimateGas']) {
    test('scope lost after $stopAfter prevents all subsequent reads', () async {
      response = (req) {
        if (req['method'] == stopAfter) current = false;
        return normal(req);
      };
      await expectLater(estimate(), fails('authWalletChanged'));
      expect(calls.last['method'], stopAfter);
    });
  }
  test('RPC cannot expose broadcast even after enabling estimates', () async {
    for (final method in [
      'eth_sendTransaction',
      'eth_sendRawTransaction',
      'eth_sign',
      'personal_sign',
    ]) {
      await expectLater(service.read(56, method, []), fails('depositRpcInvalid'));
    }
    expect(calls, isEmpty);
  });
}
