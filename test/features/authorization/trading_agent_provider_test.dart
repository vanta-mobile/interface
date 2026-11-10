import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
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
}
