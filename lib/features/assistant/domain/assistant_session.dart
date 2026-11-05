import 'dart:convert';

import '../../auth/domain/auth_session.dart';
import 'assistant.dart';

bool assistantUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);

class AssistantWalletScope {
  const AssistantWalletScope._(this.identityId, this.kind, this.address);
  factory AssistantWalletScope.fromIdentity(AuthIdentity identity) {
    final address = identity.walletAddress;
    if (identity.id.isEmpty ||
        identity.id.length > 256 ||
        identity.id.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        address == null ||
        !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address)) {
      throw const AssistantFailure('assistantWalletRequired');
    }
    return AssistantWalletScope._(identity.id, identity.walletKind, address.toLowerCase());
  }
  final String identityId, address;
  final WalletKind kind;
  String get storageIdentity => jsonEncode([identityId, kind.name, address]);
  bool matches(AuthIdentity? identity) =>
      identity != null &&
      identity.id == identityId &&
      identity.walletKind == kind &&
      identity.walletAddress?.toLowerCase() == address;
}

/// This is data awaiting explicit review, not a signed approval or a session.
class AssistantChallenge {
  const AssistantChallenge._(this.scope, this.message, this.nonce, this.receivedAt);
  static final relyingParty = Uri.https('app.vanta.exchange');
  factory AssistantChallenge.fromResponse(Object? value, AssistantWalletScope scope, DateTime now) {
    if (value is! Map<String, Object?>) throw const AssistantFailure('assistantChallengeInvalid');
    final message = value['message'], nonce = value['nonce'];
    if (message is! String ||
        nonce is! String ||
        message.isEmpty ||
        message.length > 8192 ||
        message.contains(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]')) ||
        !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(nonce)) {
      throw const AssistantFailure('assistantChallengeInvalid');
    }
    bool token(String text, String token, {bool sensitive = false}) => RegExp(
      '(^|[^a-zA-Z0-9_.-])${RegExp.escape(token)}(?=\$|[^a-zA-Z0-9_.-])',
      caseSensitive: sensitive,
    ).hasMatch(text);
    // The public frontend does not disclose the function's exact message
    // grammar. Require an exact address, nonce and relying-party token, retain
    // all original bytes, and require a separate explicit message review.
    if (!token(message, scope.address) ||
        !token(message, nonce, sensitive: true) ||
        !token(message, relyingParty.host)) {
      throw const AssistantFailure('assistantChallengeInvalid');
    }
    final uris = RegExp(r'^URI:\s*(\S+)\s*$', multiLine: true).allMatches(message).toList();
    if (uris.length > 1 || (uris.isNotEmpty && uris.single[1] != relyingParty.origin)) {
      throw const AssistantFailure('assistantChallengeInvalid');
    }
    return AssistantChallenge._(scope, message, nonce, now.toUtc());
  }
  final AssistantWalletScope scope;
  final String message, nonce;
  final DateTime receivedAt;
  bool freshAt(DateTime now) {
    final age = now.toUtc().difference(receivedAt);
    return !age.isNegative && age < const Duration(minutes: 5);
  }
}

/// Claims below only schedule refresh and identify the expected subject.
/// Server /auth/v1/user and verified wallet_bindings must still confirm them.
class AssistantCredentials {
  const AssistantCredentials._(this.accessToken, this.refreshToken, this.userId, this.expiresAt);
  factory AssistantCredentials.fromResponse(Object? value) {
    try {
      if (value is! Map<String, Object?>) throw const FormatException();
      final access = value['access_token'], refresh = value['refresh_token'];
      bool token(Object? value, int max) =>
          value is String &&
          value.isNotEmpty &&
          value.length <= max &&
          !value.contains(RegExp(r'[\x00-\x20\x7f]'));
      if (!token(access, 16384) || !token(refresh, 8192)) throw const FormatException();
      final parts = (access as String).split('.');
      if (parts.length != 3 || parts.any((p) => !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(p))) {
        throw const FormatException();
      }
      final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (claims is! Map<String, Object?> ||
          claims['sub'] is! String ||
          !assistantUuid(claims['sub'] as String) ||
          claims['role'] != 'authenticated' ||
          claims['exp'] is! int ||
          (claims['exp'] as int) <= 0 ||
          (claims['exp'] as int) > 253402300799) {
        throw const FormatException();
      }
      return AssistantCredentials._(
        access,
        refresh as String,
        (claims['sub'] as String).toLowerCase(),
        DateTime.fromMillisecondsSinceEpoch((claims['exp'] as int) * 1000, isUtc: true),
      );
    } catch (_) {
      throw const AssistantFailure('assistantAuthorization');
    }
  }
  final String accessToken, refreshToken, userId;
  final DateTime expiresAt;
  bool needsRefresh(DateTime now) =>
      !now.toUtc().add(const Duration(seconds: 30)).isBefore(expiresAt);
  @override
  String toString() => 'AssistantCredentials(redacted)';
}

class AssistantSession {
  const AssistantSession({
    required this.scope,
    required this.credentials,
    required this.verifiedAt,
  });
  final AssistantWalletScope scope;
  final AssistantCredentials credentials;
  final DateTime verifiedAt;
  String get userId => credentials.userId;
  @override
  String toString() => 'AssistantSession(redacted)';
}
