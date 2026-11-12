import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/application/wallet_onboarding_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';

import '../../support/identity_repository.dart';
import '../../support/onboarding.dart';
import '../../support/trading_agents.dart';
import '../../support/trading_authorization.dart';

class _CountingSession extends VantaApiSessionController {
  int signatures = 0;
  @override
  VantaApiSessionState build() => VantaApiSessionState(
    VantaApiSessionStatus.signedOut,
    address: ref.watch(authProvider).identity?.walletAddress?.toLowerCase(),
  );
  @override
  Future<void> ensure() async {
    signatures++;
  }
}

void main() {
  test(
    'leaving onboarding lets the dispatched grant settle and stops the next signature',
    () async {
      final identity = TestIdentityRepository()
        ..restored = const AuthIdentity(
          id: 'user',
          walletAddress: '0x1111111111111111111111111111111111111111',
          signingAvailable: true,
        );
      final repository = TestTradingAuthorizationRepository()..enableGate = Completer<void>();
      final session = _CountingSession();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          vantaApiSessionProvider.overrideWith(() => session),
          tradingAgentStoreProvider.overrideWithValue(
            MemoryTradingAgentStorage().store(DateTime.now),
          ),
          tradingAuthorizationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.dispose();
      });
      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      final owner = container.listen(walletOnboardingProvider, (_, _) {});
      addTearDown(owner.close);
      final controller = container.read(walletOnboardingProvider.notifier);
      final key = onboardingIdentityKey(identity.restored)!;
      controller.startAutomatic(key);
      await container.read(tradingAgentProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(repository.enables, 1);
      controller.stopAutomatic(key);
      repository.enableGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(session.signatures, 0);
      expect(container.read(walletOnboardingProvider).busy, false);
      expect(
        container.read(tradingAuthorizationProvider).result,
        TradingAuthorizationResult.acknowledged,
      );
    },
  );

  for (final kind in WalletKind.values) {
    test('automatic onboarding runs only for the requested embedded wallet: $kind', () async {
      final identity = TestIdentityRepository()
        ..restored = AuthIdentity(
          id: 'user',
          walletAddress: '0x1111111111111111111111111111111111111111',
          signingAvailable: true,
          walletKind: kind,
        );
      final repository = TestTradingAuthorizationRepository()..enableGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          vantaApiSessionProvider.overrideWith(VerifiedVantaSession.new),
          tradingAgentStoreProvider.overrideWithValue(
            MemoryTradingAgentStorage().store(DateTime.now),
          ),
          tradingAuthorizationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await identity.dispose();
      });
      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      final subscription = container.listen(walletOnboardingProvider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(walletOnboardingProvider.notifier);
      final key = onboardingIdentityKey(identity.restored)!;
      controller.startAutomatic(key);
      await container.read(tradingAgentProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(repository.enables, kind == WalletKind.embedded ? 1 : 0);
      controller.startAutomatic(key);
      if (kind == WalletKind.embedded) await controller.continueSigning();
      expect(repository.enables, kind == WalletKind.embedded ? 1 : 0);
      repository.enableGate!.complete();
      await Future<void>.delayed(Duration.zero);
      if (kind == WalletKind.embedded) {
        expect(
          container.read(tradingAuthorizationProvider).result,
          TradingAuthorizationResult.acknowledged,
        );
      }
    });
  }
}
