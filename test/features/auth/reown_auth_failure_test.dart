import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_auth_failure.dart';

void main() {
  test(
    'Dart timeout boilerplate uses the concrete timeout cause without a false wallet reason',
    () {
      final failure = failureFromReown(TimeoutException('Future not completed'));
      expect(failure.key, 'authWalletConnectionTimeout');
      expect(failure.reason, isNull);
      expect(
        failureFromReown(TimeoutException('MetaMask relay approval timed out')).reason,
        'MetaMask relay approval timed out',
      );
    },
  );

  test('preserves concrete relay, core and transport causes across SDK error shapes', () {
    for (final (error, message) in <(Object, String)>[
      (
        'The client closed with pending request "irn_subscribe".',
        'The client closed with pending request "irn_subscribe".',
      ),
      (const ReownCoreError(code: 1006, message: 'Relay socket closed'), 'Relay socket closed'),
      (const SocketException('Connection reset by peer'), 'Connection reset by peer'),
      (const WebSocketException('WebSocket handshake failed'), 'WebSocket handshake failed'),
      (TimeoutException('Relay subscription timed out'), 'Relay subscription timed out'),
      (
        const FormatException('Invalid wallet response', 'raw sensitive source'),
        'Invalid wallet response',
      ),
      ({'message': 'Relay refused the subscription'}, 'Relay refused the subscription'),
      (
        PlatformException(code: 'relay', details: {'message': 'Relay unavailable'}),
        'Relay unavailable',
      ),
      (Exception('Wallet RPC failed'), 'Wallet RPC failed'),
    ]) {
      expect(failureFromReown(error).reason, message, reason: '${error.runtimeType}');
    }
  });

  test('unknown and unsafe causes fall back without dumping arbitrary objects', () {
    for (final error in <Object>[
      Object(),
      Exception(),
      '',
      '#0 internal.frame (package:private/source.dart:1)',
      {'payload': 'raw sensitive payload'},
      'wc:topic@2?symKey=private',
      Exception('{"token":"private"}'),
    ]) {
      final failure = failureFromReown(error);
      expect(failure.key, 'authWalletUnavailable');
      expect(failure.reason, isNull);
    }
    expect(
      failureFromReown('Relay failed token=private\n at internal.frame').reason,
      'Relay failed token=•••',
    );
  });

  test('retains structured RPC and platform causes instead of a connection fallback', () {
    for (final error in [
      JsonRpcError(code: -32602, message: 'Chain ID must match the active network'),
      PlatformException(code: '-32602', message: 'Chain ID must match the active network'),
    ]) {
      expect(failureFromReown(error).reason, 'Chain ID must match the active network');
    }
    expect(
      failureFromReown(TimeoutException('sensitive transport context')).key,
      'authWalletConnectionTimeout',
    );
  });
  test('rejection remains distinct from transport and malformed-request errors', () {
    for (final code in [4001, 5002]) {
      expect(
        failureFromReown(JsonRpcError(code: code, message: 'Declined')).key,
        'authWalletRejected',
      );
    }
    expect(
      failureFromReown(JsonRpcError(code: -32602, message: 'Invalid parameters')).key,
      'authWalletUnavailable',
    );
  });
  test('wallet messages exclude credentials, payloads, pairing links and stack traces', () {
    final failure = failureFromReown(
      JsonRpcError(
        code: -32000,
        message: 'Request failed token=private signature=0x${'1' * 130}\n at internal.frame',
      ),
    );
    expect(failure.reason, 'Request failed token=••• signature=•••');
    for (final message in ['Request failed {"secret":"private"}', 'wc:topic@2?symKey=private']) {
      expect(failureFromReown(JsonRpcError(code: -32000, message: message)).reason, isNull);
    }
    expect(failureFromReown(StateError('Request failed')).reason, 'Request failed');
  });
  test('MetaMask JSON-wrapped WalletConnect errors expose the wallet message', () {
    final failure = failureFromReown(
      JsonRpcError(
        code: 5000,
        message:
            '{"code":-32602,"message":"Invalid parameters: must provide an Ethereum address."}',
      ),
    );
    expect(failure.key, 'authWalletUnavailable');
    expect(failure.reason, 'Invalid parameters: must provide an Ethereum address.');
    for (final message in [
      '{"code":-32000,"message":"wc:topic@2?symKey=private"}',
      '{"code":-32000,"message":{"secret":"private"}}',
      '{"code":-32000}',
    ]) {
      expect(failureFromReown(JsonRpcError(code: 5000, message: message)).reason, isNull);
    }
  });
}
