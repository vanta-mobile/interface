import '../domain/assistant.dart';
import '../domain/assistant_session.dart';
import 'assistant_http.dart';

class AssistantAuthService {
  const AssistantAuthService(this.http);
  final AssistantHttp http;

  Future<AssistantChallenge> challenge(
    AssistantWalletScope scope,
    DateTime now,
    AssistantCancellation cancellation, {
    void Function()? guard,
  }) async => AssistantChallenge.fromResponse(
    await http.json(
      'POST',
      '/functions/v1/auth-nonce',
      cancellation: cancellation,
      guard: guard,
      body: {
        'address': scope.address, 'chain': 'evm',
        'domain': AssistantChallenge.relyingParty.host,
        'uri': AssistantChallenge.relyingParty.origin,
        // chainId is optional in the public source. Personal signing does not
        // switch chain or send an on-chain transaction.
      },
    ),
    scope,
    now,
  );

  Future<AssistantCredentials> verify(
    AssistantChallenge challenge,
    String signature,
    AssistantCancellation cancellation, {
    void Function()? guard,
  }) async => AssistantCredentials.fromResponse(
    await http.json(
      'POST',
      '/functions/v1/verify-wallet',
      cancellation: cancellation,
      guard: guard,
      body: {
        'address': challenge.scope.address,
        'chain': 'evm',
        'nonce': challenge.nonce,
        'message': challenge.message,
        'signature': signature,
        'signature_encoding': 'hex',
      },
    ),
  );

  Future<AssistantCredentials> refresh(
    AssistantCredentials credentials,
    AssistantCancellation cancellation, {
    void Function()? guard,
  }) async {
    final result = AssistantCredentials.fromResponse(
      await http.json(
        'POST',
        '/auth/v1/token',
        query: {'grant_type': 'refresh_token'},
        cancellation: cancellation,
        guard: guard,
        body: {'refresh_token': credentials.refreshToken},
      ),
    );
    if (result.userId != credentials.userId) throw const AssistantFailure('assistantAuthorization');
    return result;
  }

  Future<void> verifyBinding(
    AssistantWalletScope scope,
    AssistantCredentials credentials,
    DateTime now,
    AssistantCancellation cancellation, {
    void Function()? guard,
  }) async {
    final user = await http.json(
      'GET',
      '/auth/v1/user',
      cancellation: cancellation,
      guard: guard,
      token: credentials.accessToken,
    );
    cancellation.check();
    if (user is! Map<String, Object?> ||
        user['id'] is! String ||
        (user['id'] as String).toLowerCase() != credentials.userId) {
      throw const AssistantFailure('assistantAuthorization');
    }
    final rows = await http.json(
      'GET',
      '/rest/v1/wallet_bindings',
      cancellation: cancellation,
      guard: guard,
      token: credentials.accessToken,
      headers: {'Accept-Profile': 'vanta'},
      query: {
        'select': 'user_id,address,verified_at',
        'user_id': 'eq.${credentials.userId}',
        'order': 'created_at.asc',
        'limit': '101',
      },
    );
    cancellation.check();
    if (rows is! List) throw const AssistantFailure('assistantBinding');
    // Same rule as the website: this user has a verified binding for the
    // current address. Other or duplicate bindings do not invalidate it.
    final matched = rows.any(
      (row) =>
          row is Map<String, Object?> &&
          row['user_id'] is String &&
          (row['user_id'] as String).toLowerCase() == credentials.userId &&
          row['address'] is String &&
          (row['address'] as String).trim().toLowerCase() == scope.address &&
          row['verified_at'] is String &&
          (row['verified_at'] as String).isNotEmpty,
    );
    if (!matched) throw const AssistantFailure('assistantBinding');
  }

  Future<AssistantQuota> usage(
    AssistantSession session,
    DateTime now,
    AssistantCancellation cancellation, {
    void Function()? guard,
  }) async {
    final day = now.toUtc().toIso8601String().substring(0, 10);
    final rows = await http.json(
      'GET',
      '/rest/v1/ai_daily_usage',
      cancellation: cancellation,
      guard: guard,
      token: session.credentials.accessToken,
      headers: {'Accept-Profile': 'vanta'},
      query: {
        'select': 'user_id,usage_date,request_count',
        'user_id': 'eq.${session.userId}',
        'usage_date': 'eq.$day',
        'limit': '2',
      },
    );
    if (rows is! List || rows.length > 1) throw const AssistantFailure('assistantInvalidResponse');
    if (rows.isEmpty) return AssistantQuota(day: day, used: 0);
    final row = rows.single;
    if (row is! Map<String, Object?> ||
        row['user_id'] != session.userId ||
        row['usage_date'] != day ||
        row['request_count'] is! int ||
        (row['request_count'] as int) < 0 ||
        (row['request_count'] as int) > 1000000000) {
      throw const AssistantFailure('assistantInvalidResponse');
    }
    return AssistantQuota(day: day, used: row['request_count'] as int);
  }
}
