import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/funding/data/deposit_rpc_service.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

void main() {
  final nodes = depositRpcOrigins[56]!;
  late List<String> hosts;
  late http.Response Function(String origin, Map<String, dynamic> payload) answer;
  late DepositRpcService service;

  http.Response ok(Map<String, dynamic> payload, Object? result) =>
      http.Response(jsonEncode({'jsonrpc': '2.0', 'id': payload['id'], 'result': result}), 200);

  setUp(() {
    hosts = [];
    answer = (_, payload) => ok(payload, '0x38');
    service = DepositRpcService(
      client: MockClient((request) async {
        final origin = request.url.toString();
        hosts.add(origin);
        return answer(origin, jsonDecode(request.body) as Map<String, dynamic>);
      }),
    );
  });
  tearDown(() => service.close());

  test('each supported chain has nodes from more than one operator', () {
    for (final origins in depositRpcOrigins.values) {
      expect(origins.length, greaterThan(1));
      expect(origins.map((o) => Uri.parse(o).host).toSet().length, origins.length);
    }
  });

  test('a refusing node fails over and the answering node stays preferred', () async {
    answer = (origin, payload) => origin == nodes.first
        ? http.Response('{"error":"Archive requests require a personal token"}', 403)
        : ok(payload, '0x38');
    expect(await service.read(56, 'eth_chainId', []), '0x38');
    expect(await service.read(56, 'eth_chainId', []), '0x38');
    expect(hosts, [nodes[0], nodes[1], nodes[1]]);
  });

  for (final fault in ['rate', 'rpc-error', 'malformed', 'network']) {
    test('$fault on one node is retried on the next', () async {
      answer = (origin, payload) {
        if (origin != nodes.first) return ok(payload, '0x10');
        return switch (fault) {
          'rate' => http.Response('{}', 429),
          'rpc-error' => http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': payload['id'],
              'error': {'code': -32005, 'message': 'limit'},
            }),
            200,
          ),
          'malformed' => http.Response('{bad', 200),
          _ => throw http.ClientException('down'),
        };
      };
      expect(await service.read(56, 'eth_getBlockByNumber', ['latest', false]), '0x10');
      expect(hosts, [nodes[0], nodes[1]]);
    });
  }

  test('every node failing reports the last failure after one pass', () async {
    answer = (_, _) => http.Response('{}', 503);
    await expectLater(
      service.read(56, 'eth_chainId', []),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'depositRpcFailed')),
    );
    expect(hosts, nodes);
  });

  test('a failed gas simulation is the chain answer and does not fail over', () async {
    answer = (_, payload) => http.Response(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': payload['id'],
        'error': {'code': 3, 'message': 'execution reverted'},
      }),
      200,
    );
    await expectLater(
      service.read(56, 'eth_estimateGas', [{}]),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'depositGasSimulationFailed')),
    );
    expect(hosts, [nodes.first]);
  });

  test('cancellation stops without trying another node', () async {
    answer = (_, _) => throw http.RequestAbortedException();
    await expectLater(
      service.read(56, 'eth_chainId', []),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountNetwork')),
    );
    expect(hosts, [nodes.first]);
  });
}
