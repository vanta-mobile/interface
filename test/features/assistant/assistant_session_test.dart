import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/assistant/domain/assistant.dart';
import 'package:vanta/features/assistant/domain/assistant_session.dart';
import 'package:vanta/features/assistant/data/assistant_personal_signature.dart';

import 'assistant_protocol_test.dart' show failure;
import 'assistant_session_fixture.dart';

void main() {
  group('wallet scope', () {
    test('case normalizes address but isolates app identity and wallet type', () {
      final scope = AssistantWalletScope.fromIdentity(assistantIdentity());
      expect(scope.matches(assistantIdentity(address: assistantTestAddress.toLowerCase())), isTrue);
      expect(scope.matches(assistantIdentity(id: 'other')), isFalse);
      expect(scope.matches(assistantIdentity(kind: WalletKind.embedded)), isFalse);
      expect(scope.matches(assistantIdentity(address: '0x${'22' * 20}')), isFalse);
      expect(scope.matches(null), isFalse);
    });
    for (final identity in [
      const AuthIdentity(id: 'id'),
      assistantIdentity(id: ''),
      assistantIdentity(id: 'x' * 257),
      assistantIdentity(id: 'id\n'),
      assistantIdentity(address: 'not-address'),
    ]) {
      test('rejects invalid scope ${identity.id.length}/${identity.walletAddress?.length}', () {
        expect(
          () => AssistantWalletScope.fromIdentity(identity),
          throwsA(failure('assistantWalletRequired')),
        );
      });
    }
  });

  group('public challenge', () {
    final scope = AssistantWalletScope.fromIdentity(assistantIdentity());
    AssistantChallenge parse(Object? value) =>
        AssistantChallenge.fromResponse(value, scope, assistantTestTime);
    test('retains exact message bytes and accepts CRLF without normalization', () {
      for (final message in [
        assistantChallengeText(),
        assistantChallengeText().replaceAll('\n', '\r\n'),
      ]) {
        final challenge = parse({'message': message, 'nonce': assistantNonce});
        expect(challenge.message, message);
        expect(challenge.scope, same(scope));
      }
    });
    final invalid = <Object?>[
      null,
      {},
      {'message': 1, 'nonce': assistantNonce},
      {'message': assistantChallengeText(), 'nonce': 'short'},
      {'message': assistantChallengeText(), 'nonce': assistantNonce.toUpperCase()},
      {'message': assistantChallengeText(), 'nonce': '${assistantNonce}_extra'},
      {'message': assistantChallengeText(address: '0x${'22' * 20}'), 'nonce': assistantNonce},
      {
        'message': assistantChallengeText().replaceAll(
          'app.vanta.exchange',
          'app.vanta.exchange.evil.invalid',
        ),
        'nonce': assistantNonce,
      },
      {
        'message': assistantChallengeText().replaceAll(
          'URI: https://app.vanta.exchange',
          'URI: https://evil.invalid',
        ),
        'nonce': assistantNonce,
      },
      {
        'message': '${assistantChallengeText()}\nURI: https://app.vanta.exchange',
        'nonce': assistantNonce,
      },
      {'message': '${assistantChallengeText()}\x00', 'nonce': assistantNonce},
      {'message': '${assistantChallengeText()}${'x' * 8192}', 'nonce': assistantNonce},
    ];
    for (final (index, value) in invalid.indexed) {
      test('rejects malformed or unbound challenge $index', () {
        expect(() => parse(value), throwsA(failure('assistantChallengeInvalid')));
      });
    }
    for (final (milliseconds, fresh) in [(-1, false), (0, true), (299999, true), (300000, false)]) {
      test('freshness at $milliseconds ms', () {
        final challenge = parse({'message': assistantChallengeText(), 'nonce': assistantNonce});
        expect(
          challenge.freshAt(assistantTestTime.add(Duration(milliseconds: milliseconds))),
          fresh,
        );
      });
    }
    test('does not invent a backend message grammar; requires explicit review', () {
      const text = 'Vanta login\nDomain: app.vanta.exchange\n';
      final message = '$text${scope.address}\nNonce: $assistantNonce';
      expect(parse({'message': message, 'nonce': assistantNonce}).message, message);
    });
  });

  group('credential data is not authentication proof', () {
    test('extracts exp/sub only with redacted string representation', () {
      final credentials = AssistantCredentials.fromResponse(assistantCredentialResponse());
      expect(credentials.userId, assistantTestUser);
      expect(credentials.expiresAt, assistantTestTime.add(const Duration(hours: 1)));
      expect(credentials.toString(), 'AssistantCredentials(redacted)');
      expect(
        AssistantSession(
          scope: AssistantWalletScope.fromIdentity(assistantIdentity()),
          credentials: credentials,
          verifiedAt: assistantTestTime,
        ).toString(),
        'AssistantSession(redacted)',
      );
    });
    for (final value in <Object?>[
      null,
      {},
      {'access_token': 'not-jwt', 'refresh_token': 'fake'},
      {...assistantCredentialResponse(), 'refresh_token': ''},
      {...assistantCredentialResponse(), 'refresh_token': 'line\nbreak'},
      {...assistantCredentialResponse(), 'access_token': 'a' * 16385},
      assistantCredentialResponse(user: 'not-uuid'),
      assistantCredentialResponse(role: 'anon'),
      assistantCredentialResponse(expiresAt: DateTime.utc(1969)),
    ]) {
      test('rejects malformed credential ${jsonEncode(value).length}', () {
        expect(
          () => AssistantCredentials.fromResponse(value),
          throwsA(failure('assistantAuthorization')),
        );
      });
    }
    test('refresh scheduling reserves thirty seconds', () {
      final credentials = AssistantCredentials.fromResponse(assistantCredentialResponse());
      expect(
        credentials.needsRefresh(credentials.expiresAt.subtract(const Duration(seconds: 31))),
        isFalse,
      );
      expect(
        credentials.needsRefresh(credentials.expiresAt.subtract(const Duration(seconds: 30))),
        isTrue,
      );
    });
  });

  group('EIP191 local verification', () {
    test('verifies UTF8 byte length and checksummed address with v27/28 or0/1', () {
      final message = assistantChallengeText();
      final signature = assistantTestSignature(message);
      expect(verifyAssistantPersonalSignature(assistantTestAddress, message, signature), isTrue);
      final v = int.parse(signature.substring(130), radix: 16) - 27;
      expect(
        verifyAssistantPersonalSignature(
          assistantTestAddress,
          message,
          '${signature.substring(0, 130)}${v.toRadixString(16).padLeft(2, '0')}',
        ),
        isTrue,
      );
      expect(
        verifyAssistantPersonalSignature(assistantTestAddress, '$message ', signature),
        isFalse,
      );
      expect(verifyAssistantPersonalSignature('0x${'22' * 20}', message, signature), isFalse);
    });
    for (final signature in ['', '0x${'00' * 65}', '0x${'ff' * 65}', 'private stack trace']) {
      test('rejects malformed signature ${signature.length}', () {
        expect(
          verifyAssistantPersonalSignature(assistantTestAddress, 'message', signature),
          isFalse,
        );
      });
    }
    test('safe failures do not include credential or server diagnostics', () {
      expect(
        const AssistantFailure('assistantAuthorization').toString(),
        'AssistantFailure(assistantAuthorization)',
      );
    });
  });
}
