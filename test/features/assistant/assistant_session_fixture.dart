import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/web3dart.dart' as evm;
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_message_signer.dart';
import 'package:vanta/features/assistant/data/assistant_auth_repository.dart';
import 'package:vanta/features/assistant/data/assistant_auth_service.dart';
import 'package:vanta/features/assistant/data/assistant_http.dart';
import 'package:vanta/features/assistant/data/assistant_secure_store.dart';
import 'package:vanta/features/assistant/data/assistant_vault.dart';
import 'package:vanta/features/assistant/domain/assistant_session.dart';

import 'assistant_protocol_test.dart' show runtimeConfiguration;

const assistantTestUser = '00000000-1111-2222-3333-444444444444';
const assistantOtherUser = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const assistantNonce = 'AbcDef123456';
final assistantTestTime = DateTime.utc(2026, 11, 4, 12);
// Public deterministic test vector, never loaded into an application wallet.
final assistantTestKey = evm.EthPrivateKey.fromHex('11' * 32);
final assistantTestAddress = assistantTestKey.address.eip55With0x;
AuthIdentity assistantIdentity({
  String id = 'privy:test',
  WalletKind kind = WalletKind.external,
  String? address,
  bool signing = true,
}) => AuthIdentity(
  id: id,
  walletAddress: address ?? assistantTestAddress,
  walletKind: kind,
  signingAvailable: signing,
);

String assistantChallengeText({String? address, String nonce = assistantNonce}) =>
    'app.vanta.exchange wants you to sign in with your Ethereum account:\n'
    '${address ?? assistantTestAddress}\n\nSign in to Vanta AI. 登录\n\n'
    'URI: https://app.vanta.exchange\nVersion: 1\nChain ID: 1\nNonce: $nonce\n'
    'Issued At: 2026-11-04T12:00:00.000Z';

Map<String, Object?> assistantCredentialResponse({
  String user = assistantTestUser,
  DateTime? expiresAt,
  String role = 'authenticated',
  String refresh = 'test-refresh-1',
}) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${part({'alg': 'HS256'})}.${part({'sub': user, 'role': role, 'exp': (expiresAt ?? assistantTestTime.add(const Duration(hours: 1))).millisecondsSinceEpoch ~/ 1000})}.ZmFrZQ',
    'refresh_token': refresh,
  };
}

String assistantTestSignature(String message) => evm.bytesToHex(
  assistantTestKey.signPersonalMessageToUint8List(Uint8List.fromList(utf8.encode(message))),
  include0x: true,
);

class AssistantTestStore implements AssistantSecureStore {
  final values = <String, String>{};
  final calls = <String>[];
  Future<void> Function(String operation, String key)? before;
  @override
  Future<String?> read(String key) async {
    calls.add('read:$key');
    await before?.call('read', key);
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    calls.add('write:$key');
    await before?.call('write', key);
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    calls.add('delete:$key');
    await before?.call('delete', key);
    values.remove(key);
  }
}

class AssistantTestSigner implements WalletMessageSigner {
  final messages = <String>[], addresses = <String>[];
  Future<String> Function(String message)? respond;
  @override
  Future<String> signPersonalMessage({
    required String expectedAddress,
    required String message,
  }) async {
    messages.add(message);
    addresses.add(expectedAddress);
    return respond == null ? assistantTestSignature(message) : respond!(message);
  }
}

class AssistantAuthHarness {
  AssistantAuthHarness() {
    vault = AssistantVault(store);
    httpService = AssistantHttp(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/config.js') return http.Response(runtimeConfiguration(), 200);
        final overridden = await respond?.call(request);
        if (overridden != null) return overridden;
        final body = request.body.isEmpty ? null : jsonDecode(request.body);
        return response(switch (request.url.path) {
          '/functions/v1/auth-nonce' => {
            'message': assistantChallengeText(address: (body as Map)['address'] as String),
            'nonce': assistantNonce,
          },
          '/functions/v1/verify-wallet' => assistantCredentialResponse(),
          '/auth/v1/token' => assistantCredentialResponse(refresh: 'test-refresh-rotated'),
          '/auth/v1/user' => {'id': assistantTestUser},
          '/rest/v1/wallet_bindings' => [
            {
              'user_id': assistantTestUser,
              'address': assistantTestAddress,
              'verified_at': '2026-11-04T11:00:00Z',
            },
          ],
          '/rest/v1/ai_daily_usage' => [
            {'user_id': assistantTestUser, 'usage_date': '2026-11-04', 'request_count': 2},
          ],
          _ => throw StateError('Unexpected synthetic path'),
        });
      }),
    );
    service = AssistantAuthService(httpService);
    repository = AssistantAuthRepository(
      service: service,
      vault: vault,
      signer: () => signer,
      now: () => time,
    );
  }
  DateTime time = assistantTestTime;
  final requests = <http.Request>[];
  final store = AssistantTestStore();
  final signer = AssistantTestSigner();
  late final AssistantVault vault;
  late final AssistantHttp httpService;
  late final AssistantAuthService service;
  late final AssistantAuthRepository repository;
  Future<http.Response?> Function(http.Request request)? respond;
  AssistantWalletScope get scope => AssistantWalletScope.fromIdentity(assistantIdentity());
  static http.Response response(Object? value, {int status = 200}) =>
      http.Response(jsonEncode(value), status, headers: {'content-type': 'application/json'});
  void close() {
    repository.close();
    httpService.close();
  }
}
