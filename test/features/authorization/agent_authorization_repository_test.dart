import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/data/device_trading_agent_store.dart';
import 'package:vanta/features/authorization/data/trading_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_repository.dart';
import 'package:vanta/features/portfolio/data/signed_spot_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/aster_signatures.dart';
import '../../support/aster_spot_account.dart';
import '../../support/trading_agents.dart';

void main() {
  final now = DateTime.utc(2026, 11, 10);
  final review = TradingAuthorizationReview(
    identity: const AuthIdentity(id: 'login', walletAddress: fixtureMaster, signingAvailable: true),
    preparedAt: now,
    expiresAt: now.add(const Duration(days: 30)),
  );
  late MemoryTradingAgentStorage storage;
  late DeviceTradingAgentStore store;
  late AsterAccountService futures;
  late AsterSpotService spot;
  late AsterReadNonces nonces;
  late List<http.Request> requests;
  late int walletPrompts;
  late bool current, dispatched;
  Object? failure;
  Future<void> Function()? duringWallet;
  late AsterTradingAuthorizationRepository repository;

  Future<String> wallet({
    required String expectedAddress,
    required Map<String, Object?> typedData,
  }) async {
    walletPrompts++;
    expect(expectedAddress, fixtureMaster);
    expect((typedData['domain'] as Map)['chainId'], 56);
    await duringWallet?.call();
    return fixtureSign(typedData);
  }

  setUp(() {
    storage = MemoryTradingAgentStorage();
    store = storage.store(() => now);
    requests = [];
    walletPrompts = 0;
    current = true;
    dispatched = false;
    failure = null;
    duringWallet = null;
    nonces = AsterReadNonces();
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/time')) {
        return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
      }
      if (request.url.path.endsWith('/registerAndApproveAgent')) {
        dispatched = true;
        final agent = await storage.store(() => now).load('login', fixtureMaster);
        expect(agent?.status, TradingAgentStatus.unknown);
        if (failure != null) throw failure!;
        return http.Response(jsonEncode({'code': 200}), 200);
      }
      if (request.url.path.endsWith('/exchangeInfo')) {
        return http.Response(jsonEncode(contractPayload()), 200);
      }
      final params = request.url.queryParameters;
      expect(params['user'], fixtureMaster);
      expect(params['signer']?.toLowerCase(), isNot(fixtureMaster.toLowerCase()));
      final query = request.url.query.split('&signature=').first;
      expect(
        verifyAsterWalletSignature(
          params['signer']!,
          asterReadTypedData(query),
          params['signature']!,
        ),
        true,
      );
      return http.Response(
        jsonEncode(request.url.host.startsWith('sapi') ? spotPayload() : accountPayload()),
        200,
      );
    });
    futures = AsterAccountService(client: client);
    spot = AsterSpotService(client: client);
    addTearDown(client.close);
    repository = AsterTradingAuthorizationRepository(
      futures,
      spot,
      wallet,
      agents: store,
      nonces: nonces,
      now: () => now,
      checkAuthorization: (owner) => store.resolve('login', owner, allowUnknown: true),
    );
  });

  test(
    'one owner prompt grants an independent device signer; both markets still return owner data',
    () async {
      expect(
        await repository.enable(review: review, isCurrent: () => current),
        TradingAuthorizationResult.acknowledged,
      );
      final params = Uri.splitQueryString(requests.last.body);
      final agent = (await store.load('login', fixtureMaster))!;
      expect(params['user'], fixtureMaster);
      expect(params['agentAddress'], agent.address);
      expect(params['canWithdraw'], 'false');
      expect(params['canSpotTrade'], 'true');
      expect(params['canPerpTrade'], 'true');
      expect(params['expired'], '${review.expiresAt.millisecondsSinceEpoch}');
      final restored = storage.store(() => now);
      Future<AccountRequestIdentity> authorize(String owner) => restored.resolve('login', owner);
      final account = await SignedAccountRepository(
        futures,
        wallet,
        nonces: nonces,
        authorization: authorize,
      ).read(address: fixtureMaster, isCurrent: () => current, onStep: (_) {});
      final spotAccount = await SignedSpotRepository(
        spot,
        wallet,
        nonces: nonces,
        authorization: authorize,
      ).read(address: fixtureMaster, isCurrent: () => current, onStep: (_) {});
      expect(account.address, fixtureMaster);
      expect(spotAccount.address, fixtureMaster);
      expect(walletPrompts, 1);
      expect(agent.status, TradingAgentStatus.active);
      await repository.enable(review: review, isCurrent: () => current);
      expect(walletPrompts, 1);
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  test(
    'lost authorization response persists uncertainty across restart and never replays',
    () async {
      failure = TimeoutException('fixture');
      expect(
        await repository.enable(review: review, isCurrent: () => current),
        TradingAuthorizationResult.unknown,
      );
      store = storage.store(() => now);
      final restored = AsterTradingAuthorizationRepository(
        futures,
        spot,
        wallet,
        agents: store,
        nonces: nonces,
        now: () => now,
        checkAuthorization: (owner) => store.resolve('login', owner, allowUnknown: true),
      );
      expect(
        await restored.enable(review: review, isCurrent: () => current),
        TradingAuthorizationResult.unknown,
      );
      await expectLater(store.resolve('login', fixtureMaster), throwsA(isA<AccountReadFailure>()));
      final check = await restored.check(address: fixtureMaster, isCurrent: () => current);
      expect(check.futuresReadAccepted, true);
      expect(check.spotReadAccepted, true);
      expect((await store.load('login', fixtureMaster))?.status, TradingAgentStatus.unknown);
      expect(walletPrompts, 1);
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  test('key storage failure prevents owner signature and network dispatch', () async {
    storage.writeFailure = StateError('fixture');
    await expectLater(
      repository.enable(review: review, isCurrent: () => current),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(walletPrompts, 0);
    expect(requests, isEmpty);
  });

  test('scope change while approving never dispatches or activates the agent', () async {
    duringWallet = () async {
      current = false;
    };
    await expectLater(
      repository.enable(review: review, isCurrent: () => current),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(dispatched, false);
    expect((await store.load('login', fixtureMaster))?.status, TradingAgentStatus.prepared);
  });
}
