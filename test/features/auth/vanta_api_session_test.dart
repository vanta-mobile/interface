import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/vanta_api/vanta_api_configuration.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/data/privy_configuration.dart';
import 'package:vanta/features/auth/data/privy_identity_repository.dart';
import 'package:vanta/features/auth/data/reown_wallet_connector.dart';
import 'package:vanta/features/auth/data/vanta_api_session_repository.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/auth/data/vanta_siwe_message.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:web3dart/web3dart.dart' as evm;

import '../../support/reown_modal.dart';
import '../../support/vanta_api.dart';
import '../../support/wallet_connection.dart';

final key = vantaTestKey;
final address = vantaTestAddress;
final now = vantaTestNow;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Backend backend;
  late MemoryStore store;
  late KeySigner signer;
  late VantaApiSessionRepository repository;
  var clock = now;

  setUp(() {
    clock = now;
    backend = Backend();
    store = MemoryStore();
    signer = KeySigner();
    repository = vantaTestRepository(backend, store: store, signer: signer, now: () => clock);
  });

  test('configuration accepts only a credential-free HTTPS origin', () {
    expect(const VantaApiConfiguration(origin: 'https://api.x.io/').baseUri, Uri.https('api.x.io'));
    for (final origin in ['', 'http://api.x.io', 'https://u:p@api.x.io', 'https://api.x.io/v1']) {
      expect(VantaApiConfiguration(origin: origin).isConfigured, isFalse, reason: origin);
    }
  });

  test('EIP-4361 message carries the relying party, checksum address and nonce', () {
    final message = VantaSiweMessage(
      relyingParty: Uri.https('app.vanta.exchange'),
      address: address.toLowerCase(),
      nonce: 'abcDEF12345',
      chainId: 1,
      issuedAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    );
    expect(message.text.split('\n'), [
      'app.vanta.exchange wants you to sign in with your Ethereum account:',
      address,
      '',
      VantaSiweMessage.statement,
      '',
      'URI: https://app.vanta.exchange',
      'Version: 1',
      'Chain ID: 1',
      'Nonce: abcDEF12345',
      'Issued At: 2026-11-12T08:00:00.000Z',
      'Expiration Time: 2026-11-12T08:05:00.000Z',
    ]);
    expect(
      () => VantaSiweMessage(
        relyingParty: Uri.https('app.vanta.exchange'),
        address: address,
        nonce: 'bad nonce\nURI: https://evil.test',
        chainId: 1,
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      ),
      throwsFormatException,
    );
  });

  test('sign-in posts only the signed message and stores the issued session', () async {
    await repository.signIn(address);
    expect(backend.paths, ['GET /v1/auth/nonce', 'POST /v1/auth/siwe']);
    expect(backend.requests.first.url.queryParameters['address'], address.toLowerCase());
    final body = jsonDecode(backend.requests.last.body) as Map;
    expect(body.keys, unorderedEquals(['message', 'signature', 'platform']));
    expect(body['message'], signer.message);
    expect(signer.message, contains('Expiration Time: 2026-11-12T08:05:00.000Z'));
    expect(store.value?.accessToken, 'access-1');
    expect(store.value?.address, address.toLowerCase());
    expect(await repository.restore(address), isTrue);
  });

  test('a signature from another key is refused before it reaches the server', () async {
    signer.signature = evm.bytesToHex(
      evm.EthPrivateKey.fromHex('33' * 32).signPersonalMessageToUint8List(Uint8List(1)),
      include0x: true,
    );
    await expectLater(
      repository.signIn(address),
      throwsA(isA<AuthFailure>().having((f) => f.key, 'key', 'authWalletSignature')),
    );
    expect(backend.paths, ['GET /v1/auth/nonce']);
    expect(store.value, isNull);
  });

  for (final chain in [1, 56, 42161, 8453]) {
    test('SIWE declares the signing wallet network $chain', () async {
      signer.chainId = chain;
      await repository.signIn(address);
      final body = jsonDecode(backend.requests.last.body) as Map;
      expect((body['message'] as String).split('\n'), contains('Chain ID: $chain'));
      expect(store.value?.address, address.toLowerCase());
      expect(signer.calls, 1);
    });
  }

  test('SIWE after trading network preparation uses BNB in both message and RPC', () async {
    final modal = TestReownModal()
      ..address = address
      ..selectedChainId = '1'
      ..approvedChain = '1';
    final connection = ReownWalletConnection(modal, address, '1');
    final identity = PrivyIdentityRepository(
      const PrivyConfiguration(appId: '', clientId: ''),
      preferences: MemoryWalletPreferences(),
      create: (_) => throw TestFailure('EOA signing must not initialize Privy'),
    );
    addTearDown(() async {
      await identity.dispose();
      await connection.release();
      await modal.dispose();
    });
    modal.onRequest = (request) async {
      if (request.method == 'wallet_switchEthereumChain') {
        modal.approvedAccounts = ['eip155:1:$address', 'eip155:56:$address'];
        modal.selectedChainId = '56';
        modal.changed();
        return null;
      }
      expect(request.method, 'personal_sign');
      expect(modal.chain, 'eip155:56');
      final params = request.params as List;
      expect(params.last, address);
      final encoded = params.first as String;
      final bytes = Uint8List.fromList([
        for (var i = 2; i < encoded.length; i += 2)
          int.parse(encoded.substring(i, i + 2), radix: 16),
      ]);
      expect(utf8.decode(bytes).split('\n'), contains('Chain ID: 56'));
      return evm.bytesToHex(key.signPersonalMessageToUint8List(bytes), include0x: true);
    };
    await identity.loginWithWallet(connection);
    await identity.prepareSigning(expectedAddress: address, chainId: 56, isCurrent: () => true);
    final session = vantaTestRepository(backend, store: store, signer: identity, now: () => now);
    await session.signIn(address);
    expect(backend.paths, ['GET /v1/auth/nonce', 'POST /v1/auth/siwe']);
    expect(store.value?.address, address.toLowerCase());
    expect(modal.requests.map((r) => r.method), ['wallet_switchEthereumChain', 'personal_sign']);
  });

  test('network changes during nonce lookup prevent the signature request', () async {
    signer.chainId = 56;
    backend.routes['GET /v1/auth/nonce'] = (_) {
      signer.chainId = 1;
      return json({'nonce': 'abcDEF12345', 'expires_at': '2026-11-12T08:10:00Z'});
    };
    await expectLater(
      repository.signIn(address),
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    expect(signer.calls, 0);
    expect(backend.paths, ['GET /v1/auth/nonce']);
    expect(store.value, isNull);
  });

  test('network changes while signing prevent SIWE verification and persistence', () async {
    signer.chainId = 56;
    signer.gate = Completer<void>();
    final pending = repository.signIn(address);
    final check = expectLater(
      pending,
      throwsA(isA<AuthFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    await pumpEventQueue();
    expect(signer.message, contains('Chain ID: 56'));
    signer.chainId = 1;
    signer.gate!.complete();
    await check;
    expect(backend.paths, ['GET /v1/auth/nonce']);
    expect(store.value, isNull);
  });

  test('a wallet answer after the identity changed is discarded', () async {
    signer.gate = Completer<void>();
    var current = true;
    final signing = repository.signIn(address, isCurrent: () => current);
    await pumpEventQueue();
    current = false;
    signer.gate!.complete();
    await expectLater(signing, throwsA(isA<VantaApiFailure>()));
    expect(backend.paths, ['GET /v1/auth/nonce']);
    expect(store.value, isNull);
  });

  test('a stored session of another wallet is not used', () async {
    store.value = VantaApiCredentials(
      address: '0x${'44' * 20}',
      accessToken: 'other',
      refreshToken: 'other',
      accessExpiresAt: now.add(const Duration(hours: 1)),
    );
    expect(await repository.restore(address), isFalse);
    await expectLater(
      repository.get('/v1/portfolio/summary'),
      throwsA(isA<VantaApiFailure>().having((f) => f.requiresSignIn, 'sign in', isTrue)),
    );
    expect(backend.requests, isEmpty);
  });

  test('session_expired rotates once, persists the new token and retries once', () async {
    await repository.signIn(address);
    var reads = 0;
    backend.routes['GET /v1/portfolio/summary'] = (request) {
      reads++;
      return request.headers['Authorization'] == 'Bearer access-2'
          ? json({'ok': true})
          : json({'code': 'session_expired', 'message': 'expired'}, 401);
    };
    final refreshes = <String>[];
    backend.routes['POST /v1/auth/refresh'] = (request) {
      refreshes.add((jsonDecode(request.body) as Map)['refresh_token'] as String);
      return json(issued('access-2', 'refresh-2'));
    };
    expect(await repository.get('/v1/portfolio/summary'), {'ok': true});
    expect(reads, 2);
    expect(refreshes, ['refresh-1']);
    expect(store.value?.refreshToken, 'refresh-2');
  });

  test('concurrent reads with an expired access token share one refresh', () async {
    await repository.signIn(address);
    clock = now.add(const Duration(hours: 1));
    final gate = Completer<void>();
    var refreshes = 0;
    backend.routes['POST /v1/auth/refresh'] = (_) async {
      refreshes++;
      await gate.future;
      return json(issued('access-2', 'refresh-2'));
    };
    backend.routes['GET /v1/portfolio/curve'] = (_) => json({'ok': true});
    final reads = [repository.get('/v1/portfolio/curve'), repository.get('/v1/portfolio/curve')];
    await pumpEventQueue();
    gate.complete();
    await Future.wait(reads);
    expect(refreshes, 1);
    expect(
      backend.requests
          .where((r) => r.url.path == '/v1/portfolio/curve')
          .map((r) => r.headers['Authorization']),
      everyElement('Bearer access-2'),
    );
  });

  test('a revoked session is discarded and reported, never retried', () async {
    await repository.signIn(address);
    String? lost;
    repository.onSessionLost = (value) => lost = value;
    backend.routes['GET /v1/portfolio/summary'] = (_) =>
        json({'code': 'session_revoked', 'message': 'Session revoked'}, 401);
    final failure = await repository
        .get('/v1/portfolio/summary')
        .then<VantaApiFailure?>((_) => null, onError: (Object e) => e as VantaApiFailure);
    expect(failure?.requiresSignIn, isTrue);
    expect(failure?.details?.message, 'Session revoked');
    expect(lost, address.toLowerCase());
    expect(store.value, isNull);
    expect(backend.paths.where((p) => p.contains('summary')), hasLength(1));
  });

  test('a network failure during refresh keeps the rotated-token candidate', () async {
    await repository.signIn(address);
    clock = now.add(const Duration(hours: 1));
    backend.routes['POST /v1/auth/refresh'] = (_) => throw http.ClientException('offline');
    final failure = await repository
        .get('/v1/portfolio/summary')
        .then<VantaApiFailure?>((_) => null, onError: (Object e) => e as VantaApiFailure);
    expect(failure?.details?.cause, ApiErrorCause.connection);
    expect(store.value?.refreshToken, 'refresh-1');
  });

  test('rate limits and malformed bodies keep stable keys and server text', () async {
    await repository.signIn(address);
    backend.routes['GET /v1/portfolio/summary'] = (_) =>
        json({'code': 'rate_limited', 'message': 'Slow down'}, 429);
    await expectLater(
      repository.get('/v1/portfolio/summary'),
      throwsA(
        isA<VantaApiFailure>()
            .having((f) => f.key, 'key', vantaApiRateLimited)
            .having((f) => f.details?.message, 'message', 'Slow down'),
      ),
    );
    backend.routes['GET /v1/portfolio/summary'] = (_) => http.Response('[1]', 200);
    await expectLater(
      repository.get('/v1/portfolio/summary'),
      throwsA(isA<VantaApiFailure>().having((f) => f.key, 'key', vantaApiDataInvalid)),
    );
  });

  test('sign-out discards local tokens even if logout cannot be delivered', () async {
    await repository.signIn(address);
    backend.routes['POST /v1/auth/logout'] = (_) => throw http.ClientException('offline');
    await repository.signOut();
    expect(store.value, isNull);
    expect(backend.requests.last.headers['Authorization'], 'Bearer access-1');
    expect(await repository.restore(address), isFalse);
  });
}
