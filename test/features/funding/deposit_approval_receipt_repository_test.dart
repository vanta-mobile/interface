import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/funding/data/deposit_approval_receipt_repository.dart';
import 'package:vanta/features/funding/data/deposit_rpc_service.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/deposit_approval.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8);
  final hash = '0x${'b' * 64}', blockHash = '0x${'c' * 64}';
  late DepositApprovalRecord record;
  late Map<String, Object?> transaction, receipt, head, canonical;
  late List<Map<String, dynamic>> calls;
  late Object? Function(Map<String, dynamic>) respond;
  late DepositRpcService service;
  late RpcDepositApprovalReceiptRepository repository;
  late bool current;
  Object? normal(Map<String, dynamic> request) => switch (request['method']) {
    'eth_chainId' => '0x38',
    'eth_getTransactionByHash' => transaction,
    'eth_getTransactionReceipt' => receipt,
    'eth_getBlockByNumber' => (request['params'] as List).first == 'latest' ? head : canonical,
    _ => throw StateError('unexpected RPC'),
  };
  Future<DepositApprovalReceipt> read([String? candidate]) =>
      repository.read(record, candidate ?? hash, isCurrent: () => current);
  Matcher fails(String key) => throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', key));
  setUp(() {
    record = approvalRecord(now: time);
    current = true;
    calls = [];
    transaction = {
      'hash': hash,
      'from': record.transaction.from,
      'to': record.transaction.to,
      'chainId': '0x38',
      'nonce': '0x7',
      'input': record.transaction.data,
      'value': '0x0',
      'blockNumber': '0x123',
      'blockHash': blockHash,
      'gas': '0x6272',
      'gasPrice': '0x3b9aca00',
    };
    receipt = {
      'transactionHash': hash,
      'from': transaction['from'],
      'to': transaction['to'],
      'blockNumber': '0x123',
      'blockHash': blockHash,
      'status': '0x1',
      'gasUsed': '0x5208',
      'effectiveGasPrice': '0x77359400',
    };
    head = {
      'number': '0x124',
      'hash': '0x${'d' * 64}',
      'timestamp': '0x${(time.millisecondsSinceEpoch ~/ 1000).toRadixString(16)}',
    };
    canonical = {'number': '0x123', 'hash': blockHash};
    respond = normal;
    service = DepositRpcService(
      client: MockClient((request) async {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        calls.add(payload);
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': payload['id'], 'result': respond(payload)}),
          200,
        );
      }),
    );
    repository = RpcDepositApprovalReceiptRepository(service, now: () => time);
  });
  tearDown(() => service.close());
  for (final success in [true, false]) {
    test(
      'canonical two-confirmation ${success ? 'success' : 'revert'} retains exact fee',
      () async {
        receipt['status'] = success ? '0x1' : '0x0';
        final result = await read();
        expect(
          result.status,
          success ? DepositReceiptStatus.succeeded : DepositReceiptStatus.reverted,
        );
        expect(result.bound && result.matchesIntent, true);
        expect(result.confirmations, 2);
        expect(result.gasFee, BigInt.parse('42000000000000'));
        expect(calls.map((c) => c['method']), [
          'eth_chainId',
          'eth_getTransactionByHash',
          'eth_getTransactionReceipt',
          'eth_getBlockByNumber',
          'eth_getBlockByNumber',
        ]);
      },
    );
  }
  test('one canonical confirmation remains pending', () async {
    head.addAll({'number': '0x123', 'hash': blockHash});
    final result = await read();
    expect(result.status, DepositReceiptStatus.pending);
    expect(result.confirmations, 1);
  });
  for (final missing in ['eth_getTransactionByHash', 'eth_getTransactionReceipt']) {
    test('$missing null stays unresolved', () async {
      respond = (req) => req['method'] == missing ? null : normal(req);
      final result = await read();
      expect(result.status, DepositReceiptStatus.pending);
      expect(result.bound, missing == 'eth_getTransactionReceipt');
      expect(calls.last['method'], missing);
    });
  }
  for (final field in ['hash', 'from', 'chainId', 'nonce']) {
    test('candidate with wrong $field cannot bind or continue reading', () async {
      transaction[field] = switch (field) {
        'chainId' => '0x1',
        'nonce' => '0x8',
        'from' => '0x${'3' * 40}',
        _ => '0x${'a' * 64}',
      };
      await expectLater(read(), fails('depositApprovalMismatch'));
      expect(calls.last['method'], 'eth_getTransactionByHash');
    });
  }
  test('wrong RPC chain stops before wallet lookup', () async {
    respond = (req) => req['method'] == 'eth_chainId' ? '0x1' : normal(req);
    await expectLater(read(), fails('depositRpcWrongChain'));
    expect(calls.length, 1);
  });
  test('bad candidate rejected before network', () async {
    await expectLater(read('0x${'0' * 64}'), fails('depositRpcInvalid'));
    expect(calls, isEmpty);
  });
  test('same-intent speedup uses candidate fee and preserves original record hash', () async {
    record = record.withHash('0x${'a' * 64}');
    transaction['gasPrice'] = '0x4a817c800';
    final result = await read();
    expect(result.status, DepositReceiptStatus.succeeded);
    expect(record.hash, '0x${'a' * 64}');
  });
  for (final change in ['to', 'input', 'value', 'creation']) {
    for (final confirmations in [1, 2]) {
      test(
        'same-nonce $change replacement resolves only at $confirmations confirmations',
        () async {
          if (change == 'to') transaction['to'] = record.transaction.from;
          if (change == 'input') transaction['input'] = '0x';
          if (change == 'value') transaction['value'] = '0x1';
          if (change == 'creation') transaction['to'] = null;
          receipt['to'] = transaction['to'];
          if (confirmations == 1) head.addAll({'number': '0x123', 'hash': blockHash});
          final result = await read();
          expect(result.matchesIntent, false);
          expect(result.bound, true);
          expect(
            result.status,
            confirmations == 1 ? DepositReceiptStatus.pending : DepositReceiptStatus.replaced,
          );
        },
      );
    }
  }
  for (final field in [
    'transactionHash',
    'from',
    'to',
    'blockHash',
    'blockNumber',
    'status',
    'gasUsed',
  ]) {
    test('malformed or inconsistent receipt $field cannot resolve', () async {
      receipt[field] = switch (field) {
        'transactionHash' || 'blockHash' => '0x${'e' * 64}',
        'from' || 'to' => '0x${'e' * 40}',
        'blockNumber' => '0x122',
        'status' => '0x2',
        _ => '0xffff',
      };
      await expectLater(read(), fails('depositRpcInvalid'));
    });
  }
  for (final change in ['input', 'to', 'value', 'gas']) {
    test('invalid transaction encoding $change cannot resolve', () async {
      transaction[change] = switch (change) {
        'input' => '0xa',
        'to' => 'invalid',
        'value' => '0x00',
        _ => '0x0',
      };
      await expectLater(read(), fails('depositRpcInvalid'));
    });
  }
  test('legacy fee fallback remains exact above double precision', () async {
    receipt.remove('effectiveGasPrice');
    transaction['gasPrice'] = '0x20000000000001';
    expect((await read()).gasFee, BigInt.from(21000) * BigInt.parse('9007199254740993'));
  });
  test('missing fee price is unknown', () async {
    receipt.remove('effectiveGasPrice');
    transaction.remove('gasPrice');
    expect((await read()).gasFee, null);
  });
  test('canonical reorg never resolves', () async {
    canonical['hash'] = '0x${'e' * 64}';
    await expectLater(read(), fails('depositRpcReorg'));
  });
  for (final seconds in [-120, 120]) {
    test('head outside freshness window $seconds cannot resolve', () async {
      head['timestamp'] =
          '0x${(time.add(Duration(seconds: seconds)).millisecondsSinceEpoch ~/ 1000).toRadixString(16)}';
      await expectLater(read(), fails('depositReadStale'));
    });
  }
  for (final method in [
    'eth_chainId',
    'eth_getTransactionByHash',
    'eth_getTransactionReceipt',
    'eth_getBlockByNumber',
  ]) {
    test('scope loss after $method stops reads and never broadcasts', () async {
      respond = (req) {
        if (req['method'] == method) current = false;
        return normal(req);
      };
      await expectLater(read(), fails('authWalletChanged'));
      expect(calls.last['method'], method);
    });
  }
}
