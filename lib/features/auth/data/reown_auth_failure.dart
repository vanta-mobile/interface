import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../../../core/errors/api_error_parser.dart';
import '../domain/auth_session.dart';
import 'wallet_error_message.dart';

AuthFailure failureFromReown(Object error) {
  if (error is AuthFailure) return error;
  final (code, message) = switch (error) {
    JsonRpcError(:final code, :final message) => (code?.toString(), message),
    ReownSignError(:final code, :final message) => ('$code', message),
    ReownCoreError(:final code, :final message) => ('$code', message),
    PlatformException(:final code, :final message, :final details) => (
      code,
      message ?? apiErrorDetails(details).message,
    ),
    ReownAppKitModalException(:final message) => (
      null,
      message is String ? message : apiErrorDetails(message).message,
    ),
    TimeoutException(:final message) => (null, message),
    SocketException(:final message) => (null, message),
    WebSocketException(:final message) => (null, message),
    FormatException(:final message) => (null, message),
    StateError(:final message) => (null, message),
    String() => (null, error),
    Map() => (null, apiErrorDetails(error).message),
    Exception() => (null, error.toString()),
    _ => (null, null),
  };
  final rejected =
      code == '4001' ||
      code == '5002' ||
      RegExp(r'\breject(?:ed)?\b', caseSensitive: false).hasMatch(message ?? '');
  // Dart's default timeout text describes its Future, not a wallet response.
  // Keep the known localized timeout cause; retain provider-specific detail.
  final reason = error is TimeoutException && message?.trim() == 'Future not completed'
      ? null
      : walletReason(message);
  return AuthFailure(
    rejected
        ? 'authWalletRejected'
        : error is TimeoutException || error is SocketException || error is WebSocketException
        ? 'authWalletConnectionTimeout'
        : 'authWalletUnavailable',
    reason: reason,
  );
}
