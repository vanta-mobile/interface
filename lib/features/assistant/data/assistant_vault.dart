import 'dart:async';
import 'dart:convert';

import 'package:web3dart/web3dart.dart' as evm;

import '../domain/assistant.dart';
import '../domain/assistant_history.dart';
import '../domain/assistant_session.dart';
import 'assistant_history_codec.dart';
import 'assistant_secure_store.dart';

/// Serializes operations so a delayed save cannot race an explicit clear.
/// Keys and payload envelopes bind both the app identity and selected wallet.
class AssistantVault {
  AssistantVault(this.store);
  final AssistantSecureStore store;
  Future<void> _tail = Future.value();
  static String _scopeKey(AssistantWalletScope scope) =>
      evm.bytesToHex(evm.keccakUtf8(scope.storageIdentity));
  static String _sessionKey(AssistantWalletScope scope) =>
      'vanta.ai.session.v1.${_scopeKey(scope)}';
  static String _historyKey(AssistantWalletScope scope, String user) {
    if (!assistantUuid(user)) throw const AssistantFailure('assistantStorage');
    return 'vanta.ai.history.v1.${_scopeKey(scope)}.${user.toLowerCase()}';
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final next = _tail.then((_) async {
      try {
        return await operation();
      } on AssistantFailure {
        rethrow;
      } catch (_) {
        throw const AssistantFailure('assistantStorage');
      }
    });
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<AssistantCredentials?> credentials(AssistantWalletScope scope) => _serialized(() async {
    final source = await store.read(_sessionKey(scope));
    if (source == null) return null;
    try {
      if (source.length > 32768) throw const FormatException();
      final value = jsonDecode(source);
      if (value is! Map<String, Object?> ||
          value['version'] != 1 ||
          value['scope'] != scope.storageIdentity) {
        throw const FormatException();
      }
      return AssistantCredentials.fromResponse(value['credentials']);
    } catch (_) {
      throw const AssistantFailure('assistantStorage');
    }
  });

  Future<void> saveCredentials(
    AssistantWalletScope scope,
    AssistantCredentials credentials, {
    required bool Function() isCurrent,
  }) => _serialized(() async {
    if (!isCurrent()) throw const AssistantFailure('assistantSessionChanged');
    final value = jsonEncode({
      'version': 1,
      'scope': scope.storageIdentity,
      'credentials': {
        'access_token': credentials.accessToken,
        'refresh_token': credentials.refreshToken,
      },
    });
    if (value.length > 32768) throw const AssistantFailure('assistantStorage');
    await store.write(_sessionKey(scope), value);
  });

  Future<void> forgetCredentials(AssistantWalletScope scope) =>
      _serialized(() => store.delete(_sessionKey(scope)));

  Future<AssistantHistory> history(AssistantWalletScope scope, String userId) =>
      _serialized(() async {
        final source = await store.read(_historyKey(scope, userId));
        return source == null
            ? AssistantHistory()
            : AssistantHistoryCodec.decode(scope, userId, source);
      });

  Future<void> saveHistory(
    AssistantWalletScope scope,
    String userId,
    AssistantHistory history, {
    required bool Function() isCurrent,
  }) => _serialized(() async {
    if (!isCurrent()) throw const AssistantFailure('assistantSessionChanged');
    final source = AssistantHistoryCodec.encode(scope, userId, history);
    await store.write(_historyKey(scope, userId), source);
  });

  Future<void> clearHistory(AssistantWalletScope scope, String userId) =>
      _serialized(() => store.delete(_historyKey(scope, userId)));
}
