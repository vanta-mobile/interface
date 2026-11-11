import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/automatic_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

const identity = AuthIdentity(id: 'one', walletAddress: '0xabc', signingAvailable: true);

class Auth extends AuthController {
  @override
  AuthSession build() => const AuthSession();
  void set(AuthIdentity? value) => state = AuthSession(identity: value, phase: AuthPhase.signedIn);
}

class Activity extends SymbolSettingsActivityController {
  @override
  SymbolSettingsActivity build() => const SymbolSettingsActivity();
}

class Refresh extends MainOrderRefreshController {
  final calls = <String>[];
  @override
  MainOrderRefreshState build() => const MainOrderRefreshState();
  @override
  Future<bool> refresh(String symbol) async {
    calls.add(symbol);
    state = const MainOrderRefreshState(failure: AccountReadFailure('accountNetwork'));
    return false;
  }
}

void main() {
  test(
    'wait for login/grant; read once per symbol, no retry loop; logout resets attempt',
    () async {
      TradingAgent? current;
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(Auth.new),
          symbolSettingsActivityProvider.overrideWith(Activity.new),
          tradingAgentProvider.overrideWith((ref) async => current),
          mainOrderRefreshProvider.overrideWith(Refresh.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(automaticOrderRefreshProvider, (_, _) {});
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      final refresh = container.read(mainOrderRefreshProvider.notifier) as Refresh;
      await settle();
      expect(refresh.calls, isEmpty);
      (container.read(authProvider.notifier) as Auth).set(identity);
      await settle();
      expect(refresh.calls, isEmpty);
      current = TradingAgent(
        identityId: identity.id,
        owner: identity.walletAddress!,
        address: 'agent',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        status: TradingAgentStatus.active,
      );
      container.invalidate(tradingAgentProvider);
      await settle();
      expect(refresh.calls, ['BTCUSDT']);
      container.invalidate(tradingAgentProvider);
      await settle();
      expect(refresh.calls, ['BTCUSDT']);
      container.read(symbolProvider.notifier).select('ETHUSDT');
      await settle();
      expect(refresh.calls, ['BTCUSDT', 'ETHUSDT']);
      (container.read(authProvider.notifier) as Auth).set(null);
      await settle();
      (container.read(authProvider.notifier) as Auth).set(identity);
      await settle();
      expect(refresh.calls, ['BTCUSDT', 'ETHUSDT', 'ETHUSDT']);
    },
  );
}
