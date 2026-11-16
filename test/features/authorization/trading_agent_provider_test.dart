import 'package:vanta/features/authorization/application/builder_authorization_provider.dart';

import '../../support/builder.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_signatures.dart';
import '../../support/identity_repository.dart';
import '../../support/trading_agents.dart';

void main() {
  const identity = AuthIdentity(
    id: 'login',
    walletAddress: fixtureMaster,
    walletKind: WalletKind.external,
    signingAvailable: true,
  );
  final now = DateTime.utc(2026, 11, 10);
  late TestIdentityRepository identities;
  late ProviderContainer container;
  late TradingAgent agent;
  setUp(() async {
    final store = MemoryTradingAgentStorage().store(() => now);
    agent = await store.prepare(identity.id, fixtureMaster, now.add(const Duration(days: 30)));
    await store.setStatus(agent, TradingAgentStatus.unknown);
    await store.setStatus(agent, TradingAgentStatus.active);
    identities = TestIdentityRepository()..restored = identity;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identities),
        builderApprovalJournalProvider.overrideWithValue(
          MemoryBuilderApprovalJournal(approvedByDefault: true),
        ),
        tradingAgentStoreProvider.overrideWithValue(store),
        tradingAgentClockProvider.overrideWithValue(() => now),
      ],
    );
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    container.dispose();
    await identities.dispose();
  });

  test('logout invalidates an already resolved automatic signer', () async {
    final signing = await container.read(asterRequestAuthorizationProvider)(fixtureMaster);
    await container.read(authProvider.notifier).logout();
    await expectLater(
      signing.sign(
        expectedAddress: agent.address,
        typedData: asterReadTypedData('user=$fixtureMaster&signer=${agent.address}&nonce=1'),
      ),
      throwsA(isA<AccountReadFailure>()),
    );
  });

  test('switching away and back cannot revive an old signer', () async {
    final authorize = container.read(asterRequestAuthorizationProvider);
    final signing = await authorize(fixtureMaster);
    identities.events.add(
      const AuthIdentity(id: 'other', walletAddress: fixtureChild, signingAvailable: true),
    );
    await expectLater(authorize(fixtureMaster), throwsA(isA<AccountReadFailure>()));
    identities.events.add(identity);
    await expectLater(
      signing.sign(
        expectedAddress: agent.address,
        typedData: asterReadTypedData('user=$fixtureMaster&signer=${agent.address}&nonce=1'),
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    expect((await authorize(fixtureMaster)).address, agent.address);
  });

  test('server authorization refusal disables the local grant without retrying', () async {
    var dispatches = 0;
    final request = SignedAccountRequest(
      serverTime: () async => now.millisecondsSinceEpoch,
      sign: fixtureWalletSign,
      authorization: container.read(asterRequestAuthorizationProvider),
      send: ({required query, required signature}) async {
        dispatches++;
        throw const AccountReadFailure('accountPermissionRequired');
      },
    );
    await expectLater(
      request.read(address: fixtureMaster, isCurrent: () => true, onStep: (_) {}),
      throwsA(isA<AccountReadFailure>()),
    );
    final stored = await container.read(tradingAgentStoreProvider).load(identity.id, fixtureMaster);
    expect(stored?.status, TradingAgentStatus.rejected);
    await expectLater(
      container.read(asterRequestAuthorizationProvider)(fixtureMaster),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(dispatches, 1);
  });

  for (final status in [200, 400]) {
    test(
      'missing-agent read $status invalidates the grant and blocks further signed requests',
      () async {
        final paths = <String>[];
        final service = AsterAccountService(
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/time')) {
              return http.Response('{"serverTime":${now.millisecondsSinceEpoch}}', 200);
            }
            expect(request.url.queryParameters['user'], fixtureMaster);
            expect(request.url.queryParameters['signer'], agent.address);
            return http.Response('{"code":-1000,"msg":"No agent found"}', status);
          }),
        );
        addTearDown(service.close);
        final request = SignedAccountRequest(
          serverTime: service.serverTime,
          sign: fixtureWalletSign,
          authorization: container.read(asterRequestAuthorizationProvider),
          send: service.positionMode,
        );
        Future<Object?> read() =>
            request.read(address: fixtureMaster, isCurrent: () => true, onStep: (_) {});
        await expectLater(
          read(),
          throwsA(
            isA<AccountReadFailure>()
                .having((e) => e.key, 'key', 'accountPermissionRequired')
                .having((e) => e.code, 'code', -1000)
                .having((e) => e.details?.message, 'server reason', 'No agent found'),
          ),
        );
        final store = container.read(tradingAgentStoreProvider);
        expect((await store.load(identity.id, fixtureMaster))?.status, TradingAgentStatus.rejected);
        await expectLater(
          read(),
          throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authorizationRequired')),
        );
        expect(paths, ['/fapi/v3/time', '/fapi/v3/positionSide/dual']);
        expect((await store.load(identity.id, fixtureMaster))?.address, agent.address);
        final replacement = await store.prepare(
          identity.id,
          fixtureMaster,
          now.add(const Duration(days: 30)),
        );
        expect(replacement.address, isNot(agent.address));
      },
    );
  }
}
