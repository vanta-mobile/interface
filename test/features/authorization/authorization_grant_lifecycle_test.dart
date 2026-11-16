import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/wallet_onboarding_provider.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/application/trading_authorization_provider.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';

import '../../support/vanta_api.dart';
import '../auth/wallet_onboarding_fixture.dart';

void main() {
  for (final expired in [false, true]) {
    test(
      'a prior acknowledgement does not outlive a ${expired ? 'expired' : 'removed'} Agent',
      () async {
        final h = OnboardingHarness(verified: true);
        await h.grant();
        h.container.read(authProvider);
        await Future<void>.delayed(Duration.zero);
        final controller = h.container.read(tradingAuthorizationProvider.notifier);
        await h.container.read(tradingAgentProvider.future);
        await controller.enableTrading();
        expect(
          h.container.read(tradingAuthorizationProvider).result,
          TradingAuthorizationResult.acknowledged,
        );
        expect(h.container.read(walletOnboardingStatusProvider).tradingReady, true);
        if (expired) {
          h.agents.values.updateAll(
            (_, raw) => jsonEncode({
              ...jsonDecode(raw) as Map<String, dynamic>,
              'expiresAt': vantaTestNow.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
            }),
          );
        } else {
          h.agents.values.clear();
        }
        h.container.invalidate(tradingAgentProvider);
        expect(await h.container.read(tradingAgentProvider.future), isNull);
        expect(h.container.read(tradingAuthorizationProvider).result, isNull);
        expect(h.container.read(walletOnboardingStatusProvider).tradingReady, false);
        await controller.enableTrading();
        expect(h.authorization.enables, 2);
      },
    );
  }
}
