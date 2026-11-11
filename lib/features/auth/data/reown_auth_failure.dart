import 'dart:async';

import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../../../core/errors/api_error_parser.dart';
import '../domain/auth_session.dart';

AuthFailure failureFromReown(Object error) {
  if (error is AuthFailure) return error;
  final (code, message) = switch (error) {
    JsonRpcError(:final code, :final message) => (code?.toString(), message),
    ReownSignError(:final code, :final message) => ('$code', message),
    PlatformException(:final code, :final message) => (code, message),
    ReownAppKitModalException(:final message) => (null, message is String ? message : null),
    StateError(:final message) => (null, message),
    _ => (null, null),
  };
  final rejected =
      code == '4001' ||
      code == '5002' ||
      RegExp(r'\breject(?:ed)?\b', caseSensitive: false).hasMatch(message ?? '');
  final reason = walletReason(message);
  return AuthFailure(
    rejected
        ? 'authWalletRejected'
        : error is TimeoutException
        ? 'authWalletConnectionTimeout'
        : 'authWalletUnavailable',
    reason: reason,
  );
}

/// The wallet's own explanation, shown so users can tell a wallet refusal from
/// an app fault. WalletConnect peers may wrap the JSON-RPC error as JSON text,
/// e.g. MetaMask's `{"code":-32602,"message":"..."}`; unwrap it before the
/// shared sanitizer. Session identifiers never reach the UI.
String? walletReason(String? message) {
  var text = message?.trim();
  for (var depth = 0; text != null && depth < 3 && text.startsWith('{'); depth++) {
    final payload = decodeErrorPayload(text);
    final inner = payload is Map ? payload['message'] : null;
    text = inner is String ? inner.trim() : null;
  }
  if (text == null ||
      RegExp(r'wc:|symKey|sessionTopic|requestId=', caseSensitive: false).hasMatch(text)) {
    return null;
  }
  return safeApiMessage(text);
}
