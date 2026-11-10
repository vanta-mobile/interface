import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:vanta/features/auth/data/reown_auth_failure.dart';

void main() {
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
}
