import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/assistant/domain/assistant_session.dart';

import 'assistant_protocol_test.dart' show failure;
import 'assistant_session_fixture.dart';

void main() {
  late AssistantAuthHarness h;
  setUp(() {
    h = AssistantAuthHarness();
  });
  tearDown(() => h.close());
  Future<AssistantChallenge> prepare({bool Function()? current}) => h.repository.prepare(
    assistantIdentity(),
    cancellation: AssistantCancellation(),
    isCurrent: current ?? () => true,
  );
  Future<AssistantSession> authorize({bool Function()? current}) async => h.repository.confirm(
    await prepare(),
    cancellation: AssistantCancellation(),
    isCurrent: current ?? () => true,
  );

  test(
    'explicit restore checks server user and wallet binding without another signature',
    () async {
      final original = await authorize();
      final count = h.requests.length;
      final session = await h.repository.restore(
        h.scope,
        cancellation: AssistantCancellation(),
        isCurrent: () => true,
      );
      expect(session!.credentials.accessToken, original.credentials.accessToken);
      expect(h.requests.skip(count).map((r) => r.url.path), [
        '/auth/v1/user',
        '/rest/v1/wallet_bindings',
      ]);
      expect(h.signer.messages, hasLength(1));
    },
  );

  test('expired token rotates before server confirmation and saves new refresh token', () async {
    await h.vault.saveCredentials(
      h.scope,
      AssistantCredentials.fromResponse(
        assistantCredentialResponse(expiresAt: h.time.subtract(const Duration(seconds: 1))),
      ),
      isCurrent: () => true,
    );
    final session = await h.repository.restore(
      h.scope,
      cancellation: AssistantCancellation(),
      isCurrent: () => true,
    );
    expect(session!.credentials.refreshToken, 'test-refresh-rotated');
    expect((await h.vault.credentials(h.scope))!.refreshToken, 'test-refresh-rotated');
    final refresh = h.requests.singleWhere((r) => r.url.path == '/auth/v1/token');
    expect(refresh.url.queryParameters, {'grant_type': 'refresh_token'});
    expect(jsonDecode(refresh.body), {'refresh_token': 'test-refresh-1'});
    expect(h.signer.messages, isEmpty);
  });

  test('rotated credential remains recoverable if later binding read fails', () async {
    await h.vault.saveCredentials(
      h.scope,
      AssistantCredentials.fromResponse(
        assistantCredentialResponse(expiresAt: h.time.subtract(const Duration(seconds: 1))),
      ),
      isCurrent: () => true,
    );
    h.respond = (request) async => request.url.path == '/rest/v1/wallet_bindings'
        ? AssistantAuthHarness.response({'error': 'private'}, status: 503)
        : null;
    await expectLater(
      h.repository.restore(h.scope, cancellation: AssistantCancellation(), isCurrent: () => true),
      throwsA(failure('assistantUnavailable')),
    );
    expect((await h.vault.credentials(h.scope))!.refreshToken, 'test-refresh-rotated');
    h.respond = null;
    await h.repository.restore(
      h.scope,
      cancellation: AssistantCancellation(),
      isCurrent: () => true,
    );
    expect(h.requests.where((r) => r.url.path == '/auth/v1/token'), hasLength(1));
  });

  test('refresh cannot change subject or silently replace saved account', () async {
    await h.vault.saveCredentials(
      h.scope,
      AssistantCredentials.fromResponse(
        assistantCredentialResponse(expiresAt: h.time.subtract(const Duration(seconds: 1))),
      ),
      isCurrent: () => true,
    );
    h.respond = (request) async => request.url.path == '/auth/v1/token'
        ? AssistantAuthHarness.response(assistantCredentialResponse(user: assistantOtherUser))
        : null;
    await expectLater(
      h.repository.restore(h.scope, cancellation: AssistantCancellation(), isCurrent: () => true),
      throwsA(failure('assistantAuthorization')),
    );
    expect((await h.vault.credentials(h.scope))!.refreshToken, 'test-refresh-1');
    expect(h.requests.where((r) => r.url.path == '/auth/v1/user'), isEmpty);
  });

  test('scope changes after credential write do not grant a session for another wallet', () async {
    var current = true;
    h.store.before = (operation, _) async {
      if (operation == 'write') current = false;
    };
    await expectLater(
      authorize(current: () => current),
      throwsA(failure('assistantSessionChanged')),
    );
    expect((await h.vault.credentials(h.scope))!.userId, assistantTestUser);
    expect(h.scope.matches(assistantIdentity(id: 'different')), isFalse);
  });

  test('close invalidates prepared challenge and rejects later operations', () async {
    final challenge = await prepare();
    h.repository.close();
    await expectLater(
      h.repository.confirm(challenge, cancellation: AssistantCancellation(), isCurrent: () => true),
      throwsA(failure('assistantSessionChanged')),
    );
    expect(h.signer.messages, isEmpty);
  });
}
