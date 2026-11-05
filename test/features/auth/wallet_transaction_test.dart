import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart' show JsonRpcError;
import 'package:vanta/features/auth/data/wallet_transaction_dispatch.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';

import '../../support/wallet_transaction.dart';

void main() {
  for (final chain in [1, 56, 42161]) {
    test('exact immutable wallet RPC payload on $chain preserves BigInt', () {
      final tx = walletTransaction(chainId: chain);
      expect(tx.parameters, {
        'chainId': '0x${chain.toRadixString(16)}',
        'from': '0x${'2' * 40}',
        'to': '0x${'5' * 40}',
        'data': '0x095ea7b3',
        'value': '0x1111d67bb1bb0001',
        'gas': '0x6272',
        'gasPrice': '0x3b9aca00',
        'nonce': '0x7',
      });
      expect(() => tx.parameters['value'] = '0x0', throwsUnsupportedError);
      final max = (BigInt.one << 256) - BigInt.one;
      expect(walletTransaction(value: max, gasPrice: max).parameters['value'], '0x${'f' * 64}');
      expect(walletTransaction(value: BigInt.zero, nonce: BigInt.zero).parameters['value'], '0x0');
    });
  }
  for (final invalid in <String, EvmWalletTransaction Function()>{
    'chain': () => walletTransaction(chainId: 8453),
    'negativeChain': () => walletTransaction(chainId: -1),
    'from': () => walletTransaction(from: 'invalid'),
    'zeroFrom': () => walletTransaction(from: '0x${'0' * 40}'),
    'to': () => walletTransaction(to: '0x123'),
    'zeroTo': () => walletTransaction(to: '0x${'0' * 40}'),
    'oddCalldata': () => walletTransaction(data: '0x123'),
    'nonhexCalldata': () => walletTransaction(data: '0xgg'),
    'unboundedCalldata': () => walletTransaction(data: '0x${'aa' * 65537}'),
    'negativeValue': () => walletTransaction(value: -BigInt.one),
    'overflowValue': () => walletTransaction(value: BigInt.one << 256),
    'zeroGas': () => walletTransaction(gasLimit: BigInt.zero),
    'overflowGas': () => walletTransaction(gasLimit: BigInt.one << 64),
    'zeroPrice': () => walletTransaction(gasPrice: BigInt.zero),
    'negativePrice': () => walletTransaction(gasPrice: -BigInt.one),
    'overflowPrice': () => walletTransaction(gasPrice: BigInt.one << 256),
    'negativeNonce': () => walletTransaction(nonce: -BigInt.one),
    'exhaustedNonce': () => walletTransaction(nonce: (BigInt.one << 64) - BigInt.one),
  }.entries) {
    test('invalid ${invalid.key} is known not sent', () {
      expect(
        invalid.value,
        throwsA(
          isA<WalletTransactionNotSent>().having((e) => e.key, 'key', 'walletTransactionInvalid'),
        ),
      );
    });
  }
  for (final response in [
    null,
    <String, Object?>{},
    1,
    '0x${'a' * 130}',
    '0x${'0' * 64}',
    'not a hash',
  ]) {
    test('malformed response $response is unknown, not proof of no send', () async {
      final result = await dispatchWalletTransaction(() async => response);
      expect(result.status, WalletTransactionStatus.unknown);
      expect(result.hash, null);
    });
  }
  test('reported hash retained verbatim without asserting a receipt', () async {
    final hash = '0x${'Ab' * 32}';
    final result = await dispatchWalletTransaction(() async => hash);
    expect(result.status, WalletTransactionStatus.hashReported);
    expect(result.hash, hash);
  });
  for (final error in [
    PlatformException(code: '4001', message: 'private details'),
    JsonRpcError(code: 4001, message: 'private details'),
  ]) {
    test('only structured 4001 rejection ${error.runtimeType} proves wallet refusal', () async {
      final result = await dispatchWalletTransaction(() async => throw error);
      expect(result.status, WalletTransactionStatus.rejected);
      expect(result.hash, null);
    });
  }
  for (final error in [
    PlatformException(code: 'RPC_REQUEST_FAILED', message: '4001 rejected'),
    JsonRpcError(code: -32000, message: 'user rejected'),
    const AuthFailure('authWalletRejected'),
    const FormatException('raw sensitive data'),
    TimeoutException('timed out'),
    StateError('disconnected'),
  ]) {
    test('ambiguous ${error.runtimeType}/$error never becomes retryable rejection', () async {
      var requests = 0;
      final result = await dispatchWalletTransaction(() async {
        requests++;
        throw error;
      });
      expect(result.status, WalletTransactionStatus.unknown);
      expect(requests, 1);
    });
  }
  test('separate async modal error is contained; late hash cannot cause replay', () async {
    final gate = Completer<Object?>();
    final result = await dispatchWalletTransaction(() {
      scheduleMicrotask(() => throw StateError('raw modal failure'));
      return gate.future;
    });
    expect(result.status, WalletTransactionStatus.unknown);
    gate.complete('0x${'a' * 64}');
    await Future<void>.delayed(Duration.zero);
  });
}
