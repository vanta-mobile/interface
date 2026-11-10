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
  final reason =
      message != null &&
          !RegExp(r'wc:|symKey|sessionTopic|requestId=', caseSensitive: false).hasMatch(message)
      ? safeApiMessage(message)
      : null;
  return AuthFailure(
    rejected
        ? 'authWalletRejected'
        : error is TimeoutException
        ? 'authWalletConnectionTimeout'
        : 'authWalletUnavailable',
    reason: reason,
  );
}
