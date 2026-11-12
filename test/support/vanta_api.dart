import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/vanta_api/vanta_api_http.dart';
import 'package:vanta/features/auth/data/vanta_api_session_repository.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/auth/domain/wallet_message_signer.dart';
import 'package:web3dart/web3dart.dart' as evm;

final vantaTestKey = evm.EthPrivateKey.fromHex('22' * 32);
final vantaTestAddress = vantaTestKey.address.eip55With0x;
final vantaTestNow = DateTime.utc(2026, 11, 12, 8);

class KeySigner implements WalletMessageSigner {
  int calls = 0;
  Completer<void>? gate;
  String? signature;
  String? message;
  @override
  Future<String> signPersonalMessage({
    required String expectedAddress,
    required String message,
  }) async {
    calls++;
    this.message = message;
    await gate?.future;
    return signature ??
        evm.bytesToHex(
          vantaTestKey.signPersonalMessageToUint8List(Uint8List.fromList(utf8.encode(message))),
          include0x: true,
        );
  }
}

class MemoryStore implements VantaApiSessionStore {
  VantaApiCredentials? value;
  @override
  Future<VantaApiCredentials?> read() async => value;
  @override
  Future<void> write(VantaApiCredentials credentials) async => value = credentials;
  @override
  Future<void> clear() async => value = null;
}

Map<String, Object?> issued(String access, String refresh, {int expiresIn = 900}) => {
  'access_token': access,
  'refresh_token': refresh,
  'expires_in': expiresIn,
  'user': {'user_id': 7, 'wallet': vantaTestAddress.toLowerCase(), 'method': 'siwe'},
};

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

class Backend {
  final requests = <http.Request>[];
  final routes = <String, FutureOr<http.Response> Function(http.Request)>{};
  late final client = MockClient((request) async {
    requests.add(request);
    final route = routes['${request.method} ${request.url.path}'];
    return route == null ? json({'code': 'not_found', 'message': 'no route'}, 404) : route(request);
  });
  List<String> get paths => requests.map((r) => '${r.method} ${r.url.path}').toList();
}

VantaApiSessionRepository vantaTestRepository(
  Backend backend, {
  required VantaApiSessionStore store,
  required WalletMessageSigner signer,
  required DateTime Function() now,
}) {
  backend.routes['GET /v1/auth/nonce'] ??= (_) =>
      json({'nonce': 'abcDEF12345', 'expires_at': '2026-11-12T08:10:00Z'});
  backend.routes['POST /v1/auth/siwe'] ??= (_) => json(issued('access-1', 'refresh-1'));
  return VantaApiSessionRepository(
    http: VantaApiHttp(baseUri: Uri.https('api.vanta.test'), client: backend.client),
    store: store,
    signer: () => signer,
    relyingParty: Uri.https('app.vanta.exchange'),
    now: now,
    platform: 'android',
  );
}
