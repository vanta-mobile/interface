import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';

import '../../support/identity_repository.dart';
import '../../support/trading_authorization.dart';

const _identity = AuthIdentity(
  id: 'signed-user',
  walletAddress: '0x1111111111111111111111111111111111111111',
  signingAvailable: true,
);

void main() {
  late TestIdentityRepository identity;
  late TestTradingAuthorizationRepository repository;
  late ProviderContainer container;
  late TradingAuthorizationController controller;
  setUp(() async {
    identity = TestIdentityRepository()..restored = _identity;
    repository = TestTradingAuthorizationRepository();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        tradingAuthorizationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    controller = container.read(tradingAuthorizationProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await identity.dispose();
  });

  test('wallet switch invalidates an in-flight grant and ignores its late result', () async {
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    expect(repository.isCurrent!(), true);
    identity.events.add(
      const AuthIdentity(
        id: 'other-user',
        walletAddress: '0x2222222222222222222222222222222222222222',
        signingAvailable: true,
      ),
    );
    expect(repository.isCurrent!(), false);
    repository.enableGate!.complete();
    await pending;
    expect(container.read(tradingAuthorizationProvider).result, isNull);
    expect(container.read(tradingAuthorizationProvider).busy, false);
    expect(repository.enables, 1);
  });

  test('logout invalidates signing and a late acknowledgement cannot restore it', () async {
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    await container.read(authProvider.notifier).logout();
    expect(repository.isCurrent!(), false);
    repository.enableGate!.complete();
    await pending;
    expect(container.read(authProvider).identity, isNull);
    expect(container.read(tradingAuthorizationProvider).result, isNull);
  });

  test('disposing the owner invalidates the request guard', () async {
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    container.dispose();
    expect(repository.isCurrent!(), false);
    repository.enableGate!.complete();
    await pending;
  });

  test('stopping an in-flight grant retains uncertainty and blocks resubmission', () async {
    repository.enableGate = Completer<void>();
    final pending = controller.enableTrading();
    controller.stop();
    expect(repository.isCurrent!(), false);
    repository.enableGate!.complete();
    await pending;
    controller.cancel();
    controller.prepare();
    await controller.enableTrading();
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    expect(repository.enables, 1);
  });

  test('signer reconnection for the same wallet preserves an unknown grant', () async {
    repository.result = TradingAuthorizationResult.unknown;
    await controller.enableTrading();
    identity.events.add(
      AuthIdentity(
        id: _identity.id,
        walletAddress: _identity.walletAddress,
        signingAvailable: false,
      ),
    );
    await controller.check();
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    identity.events.add(_identity);
    expect(container.read(tradingAuthorizationProvider).result, TradingAuthorizationResult.unknown);
    await controller.enableTrading();
    expect(repository.enables, 1);
  });

  test('known acknowledgement prevents another onboarding grant', () async {
    await controller.enableTrading();
    await controller.enableTrading();
    expect(repository.enables, 1);
    expect(
      container.read(tradingAuthorizationProvider).result,
      TradingAuthorizationResult.acknowledged,
    );
  });
}
