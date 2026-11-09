import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/identity_repository.dart';
import '../../support/trading_authorization.dart';

const _identity = AuthIdentity(
  id: 'user-1',
  walletAddress: '0x1111111111111111111111111111111111111111',
  signingAvailable: true,
);

class _IdentityRepository extends TestIdentityRepository {
  @override
  Future<AuthIdentity> ensureWallet() async {
    await super.ensureWallet();
    return _identity;
  }
}

void main() {
  late _IdentityRepository identity;
  late TestTradingAuthorizationRepository repository;
  late ProviderContainer container;

  setUp(() async {
    identity = _IdentityRepository();
    repository = TestTradingAuthorizationRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        tradingAuthorizationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  ProviderSubscription<void> mount([String id = 'user-1']) =>
      container.listen(embeddedLoginTradingAuthorizationProvider(id), (_, _) {});

  test('waits for wallet creation, signs once, and disables duplicate submission', () async {
    identity.walletGate = Completer<void>();
    repository.enableGate = Completer<void>();
    final owner = mount();
    final login = container.read(authProvider.notifier).loginWithSocial(SocialLoginProvider.google);
    await Future<void>.delayed(Duration.zero);
    expect(identity.wallets, 1);
    expect(repository.enables, 0);
    identity.walletGate!.complete();
    await login;
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 1);
    expect(container.read(tradingAuthorizationProvider).busy, true);
    await container.read(tradingAuthorizationProvider.notifier).enableTrading();
    identity.events.add(_identity);
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 1);
    repository.enableGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(tradingAuthorizationProvider).result,
      TradingAuthorizationResult.acknowledged,
    );
    owner.close();
  });

  test('leaving before wallet creation finishes cancels the automatic intent', () async {
    identity.walletGate = Completer<void>();
    final owner = mount();
    final login = container.read(authProvider.notifier).loginWithSocial(SocialLoginProvider.google);
    await Future<void>.delayed(Duration.zero);
    owner.close();
    await container.pump();
    identity.walletGate!.complete();
    await login;
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 0);
  });

  test('rejects a different login identity and an external signer', () async {
    final owner = mount('another-user');
    await container.read(authProvider.notifier).loginWithSocial(SocialLoginProvider.google);
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 0);
    identity.events.add(
      AuthIdentity(
        id: 'another-user',
        walletAddress: _identity.walletAddress,
        walletKind: WalletKind.external,
        signingAvailable: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 0);
    owner.close();
  });

  test('signature failure never automatically retries after auth updates', () async {
    repository.failure = const AccountReadFailure('authWalletRejected');
    final owner = mount();
    await container.read(authProvider.notifier).loginWithSocial(SocialLoginProvider.google);
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 1);
    expect(container.read(tradingAuthorizationProvider).failure, 'authWalletRejected');
    identity.events.add(
      AuthIdentity(
        id: _identity.id,
        walletAddress: _identity.walletAddress,
        signingAvailable: false,
      ),
    );
    identity.events.add(_identity);
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 1);
    repository.failure = null;
    await container.read(tradingAuthorizationProvider.notifier).enableTrading();
    expect(repository.enables, 2);
    owner.close();
  });

  test('unknown outcome survives remounting and prevents automatic replay', () async {
    repository.result = TradingAuthorizationResult.unknown;
    final owner = mount();
    await container.read(authProvider.notifier).loginWithSocial(SocialLoginProvider.google);
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 1);
    owner.close();
    await container.pump();
    final reopened = mount();
    await Future<void>.delayed(Duration.zero);
    expect(repository.enables, 1);
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    reopened.close();
  });
}
