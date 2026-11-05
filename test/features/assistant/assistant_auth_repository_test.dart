import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
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

  test('constructors and missing saved credentials disclose no identity to network', () async {
    expect(h.requests, isEmpty);
    expect(
      await h.repository.restore(
        h.scope,
        cancellation: AssistantCancellation(),
        isCurrent: () => true,
      ),
      isNull,
    );
    expect(h.requests, isEmpty);
    expect(h.signer.messages, isEmpty);
  });

  test('prepare has no signature, confirmation signs exact current-wallet message then verifies server binding', () async {
    final challenge = await prepare();
    expect(h.signer.messages, isEmpty);
    expect(h.requests.map((r) => r.url.path), ['/config.js', '/functions/v1/auth-nonce']);
    expect(jsonDecode(h.requests.last.body), {
      'address': h.scope.address,
      'chain': 'evm',
      'domain': 'app.vanta.exchange',
      'uri': 'https://app.vanta.exchange',
    });
    final session = await h.repository.confirm(
      challenge,
      cancellation: AssistantCancellation(),
      isCurrent: () => true,
    );
    expect(session.userId, assistantTestUser);
    expect(h.signer.addresses, [h.scope.address]);
    expect(h.signer.messages, [challenge.message]);
    final verify = h.requests.singleWhere((r) => r.url.path == '/functions/v1/verify-wallet');
    expect(jsonDecode(verify.body), {
      'address': h.scope.address,
      'chain': 'evm',
      'message': challenge.message,
      'nonce': assistantNonce,
      'signature': assistantTestSignature(challenge.message),
      'signature_encoding': 'hex',
    });
    final binding = h.requests.last;
    expect(binding.url.path, '/rest/v1/wallet_bindings');
    expect(binding.headers['accept-profile'], 'vanta');
    expect(binding.url.queryParameters['user_id'], 'eq.$assistantTestUser');
    expect(binding.url.queryParameters['limit'], '101');
    expect(binding.headers['authorization'], 'Bearer ${session.credentials.accessToken}');
    expect((await h.vault.credentials(h.scope))!.refreshToken, session.credentials.refreshToken);
  });

  for (final failureStage in ['nonce', 'signature', 'verify', 'user', 'binding', 'storage']) {
    test('$failureStage failure never grants a session or automatically re-signs', () async {
      if (failureStage == 'signature') {
        h.signer.respond = (_) async => throw const AuthFailure('authWalletCancelled');
      }
      if (failureStage == 'storage') {
        h.store.before = (op, _) async {
          if (op == 'write') throw StateError('private storage trace');
        };
      }
      h.respond = (request) async {
        final stage = switch (request.url.path) {
          '/functions/v1/auth-nonce' => 'nonce',
          '/functions/v1/verify-wallet' => 'verify',
          '/auth/v1/user' => 'user',
          '/rest/v1/wallet_bindings' => 'binding',
          _ => '',
        };
        return stage == failureStage
            ? AssistantAuthHarness.response({'error': 'raw token secret'}, status: 503)
            : null;
      };
      await expectLater(authorize(), throwsA(anyOf(isA<AssistantFailure>(), isA<AuthFailure>())));
      expect(h.signer.messages.length, lessThanOrEqualTo(1));
      expect(h.store.values, isEmpty);
      expect(
        h.requests.where((r) => r.url.path == '/functions/v1/verify-wallet').length,
        lessThanOrEqualTo(1),
      );
    });
  }

  test('wallet rejection consumes challenge; a fresh explicit prepare is required', () async {
    final challenge = await prepare();
    h.signer.respond = (_) async => throw const AuthFailure('authWalletCancelled');
    await expectLater(
      h.repository.confirm(challenge, cancellation: AssistantCancellation(), isCurrent: () => true),
      throwsA(isA<AuthFailure>()),
    );
    h.signer.respond = null;
    await expectLater(
      h.repository.confirm(challenge, cancellation: AssistantCancellation(), isCurrent: () => true),
      throwsA(failure('assistantChallengeExpired')),
    );
    expect(h.signer.messages, hasLength(1));
    expect(h.requests.where((r) => r.url.path == '/functions/v1/verify-wallet'), isEmpty);
    await authorize();
    expect(h.signer.messages, hasLength(2));
  });

  for (final scenario in [
    'before-sign',
    'after-sign',
    'clock-rollback',
    'expiry-before',
    'expiry-after',
  ]) {
    test('$scenario stops verification and preserves wallet scope', () async {
      var current = true;
      final challenge = await prepare();
      if (scenario == 'before-sign') current = false;
      if (scenario == 'expiry-before') h.time = h.time.add(const Duration(minutes: 5));
      if (scenario == 'clock-rollback') h.time = h.time.subtract(const Duration(milliseconds: 1));
      h.signer.respond = (message) async {
        if (scenario == 'after-sign') current = false;
        if (scenario == 'expiry-after') h.time = h.time.add(const Duration(minutes: 5));
        return assistantTestSignature(message);
      };
      await expectLater(
        h.repository.confirm(
          challenge,
          cancellation: AssistantCancellation(),
          isCurrent: () => current,
        ),
        throwsA(isA<AssistantFailure>()),
      );
      expect(h.requests.where((r) => r.url.path == '/functions/v1/verify-wallet'), isEmpty);
      expect(h.store.values, isEmpty);
    });
  }

  test('nonce result after identity change cannot become a prepared approval', () async {
    var current = true;
    h.respond = (request) async {
      if (request.url.path == '/functions/v1/auth-nonce') current = false;
      return null;
    };
    await expectLater(prepare(current: () => current), throwsA(failure('assistantSessionChanged')));
    expect(h.signer.messages, isEmpty);
  });

  for (final path in ['/functions/v1/verify-wallet', '/auth/v1/user', '/rest/v1/wallet_bindings']) {
    test('scope guard stops following private requests after $path returns', () async {
      var current = true;
      h.respond = (request) async {
        if (request.url.path == path) current = false;
        return null;
      };
      await expectLater(
        authorize(current: () => current),
        throwsA(failure('assistantSessionChanged')),
      );
      expect(h.requests.last.url.path, path);
      expect(h.store.values, isEmpty);
    });
  }

  test('cancel while wallet prompt is pending stops waiting; late signature never posts', () async {
    final challenge = await prepare();
    final signature = Completer<String>(), entered = Completer<void>();
    h.signer.respond = (_) {
      entered.complete();
      return signature.future;
    };
    final cancellation = AssistantCancellation();
    final pending = h.repository.confirm(
      challenge,
      cancellation: cancellation,
      isCurrent: () => true,
    );
    final check = expectLater(pending, throwsA(failure('assistantCancelled')));
    await entered.future;
    await expectLater(prepare(), throwsA(failure('assistantBusy')));
    cancellation.cancel();
    await check;
    signature.complete(assistantTestSignature(challenge.message));
    await Future<void>.delayed(Duration.zero);
    expect(h.requests.where((r) => r.url.path == '/functions/v1/verify-wallet'), isEmpty);
    expect(h.store.values, isEmpty);
  });

  test('wrong wallet signature never reaches verify endpoint', () async {
    h.signer.respond = (message) async => assistantTestSignature('$message changed');
    await expectLater(
      authorize(),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletSignature')),
    );
    expect(h.requests.where((r) => r.url.path == '/functions/v1/verify-wallet'), isEmpty);
  });

  for (final outcome in ['resume', 'cancel', 'expired']) {
    test('external-wallet handoff waits for foreground: $outcome', () async {
      final challenge = await prepare();
      final resumed = Completer<void>(), waiting = Completer<void>();
      final cancellation = AssistantCancellation();
      final pending = h.repository.confirm(
        challenge,
        cancellation: cancellation,
        isCurrent: () => true,
        awaitForeground: () {
          waiting.complete();
          return resumed.future;
        },
      );
      final check = outcome == 'resume'
          ? expectLater(pending, completes)
          : expectLater(
              pending,
              throwsA(
                failure(outcome == 'cancel' ? 'assistantCancelled' : 'assistantChallengeExpired'),
              ),
            );
      await waiting.future;
      expect(h.requests.where((r) => r.url.path == '/functions/v1/verify-wallet'), isEmpty);
      if (outcome == 'cancel') cancellation.cancel();
      if (outcome == 'expired') h.time = h.time.add(const Duration(minutes: 5));
      resumed.complete();
      await check;
      expect(
        h.requests.where((r) => r.url.path == '/functions/v1/verify-wallet').length,
        outcome == 'resume' ? 1 : 0,
      );
    });
  }

  test('pending wallet prompt cannot hold the repository past challenge deadline', () async {
    final challenge = await prepare();
    h.time = h.time.add(const Duration(minutes: 5) - const Duration(milliseconds: 1));
    final signature = Completer<String>();
    h.signer.respond = (_) => signature.future;
    await expectLater(
      h.repository.confirm(challenge, cancellation: AssistantCancellation(), isCurrent: () => true),
      throwsA(failure('assistantChallengeExpired')),
    );
    signature.complete(assistantTestSignature(challenge.message));
    expect(h.requests.where((r) => r.url.path == '/functions/v1/verify-wallet'), isEmpty);
  });

  test('unavailable signer is not replaced with a generated wallet', () async {
    await expectLater(
      h.repository.prepare(
        assistantIdentity(signing: false),
        cancellation: AssistantCancellation(),
        isCurrent: () => true,
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect(h.requests, isEmpty);
    expect(h.signer.messages, isEmpty);
  });

  test('locally decoded JWT is insufficient: server user mismatch prevents binding lookup and persistence', () async {
    h.respond = (request) async => request.url.path == '/auth/v1/user'
        ? AssistantAuthHarness.response({'id': assistantOtherUser})
        : null;
    await expectLater(authorize(), throwsA(failure('assistantAuthorization')));
    expect(h.requests.where((r) => r.url.path == '/rest/v1/wallet_bindings'), isEmpty);
    expect(h.store.values, isEmpty);
  });

  final invalidBindings = <Object?>[
    null,
    [],
    {},
    [null],
    [
      {
        'user_id': assistantOtherUser,
        'address': assistantTestAddress,
        'verified_at': '2026-11-04T11:00:00Z',
      },
    ],
    [
      {
        'user_id': assistantTestUser,
        'address': '0x${'22' * 20}',
        'verified_at': '2026-11-04T11:00:00Z',
      },
    ],
    [
      {'user_id': assistantTestUser, 'address': assistantTestAddress, 'verified_at': null},
    ],
    [
      {'user_id': assistantTestUser, 'address': assistantTestAddress, 'verified_at': ''},
    ],
    [
      {
        'user_id': assistantTestUser,
        'address': assistantTestAddress,
        'verified_at': '2026-11-04T13:00:00Z',
      },
    ],
    List.generate(
      2,
      (_) => {
        'user_id': assistantTestUser,
        'address': assistantTestAddress,
        'verified_at': '2026-11-04T11:00:00Z',
      },
    ),
    List.generate(
      101,
      (_) => {'user_id': assistantTestUser, 'address': assistantTestAddress, 'verified_at': null},
    ),
  ];
  for (final (index, bindings) in invalidBindings.indexed) {
    test('unverified, wrong, duplicate or excessive binding $index never grants session', () async {
      h.respond = (request) async => request.url.path == '/rest/v1/wallet_bindings'
          ? AssistantAuthHarness.response(bindings)
          : null;
      await expectLater(authorize(), throwsA(failure('assistantBinding')));
      expect(h.store.values, isEmpty);
    });
  }
}
