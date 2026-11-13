import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';

/// Existing authorization-only tests start with an already verified API session.
/// Full missing-session/signature behavior is covered by wallet_onboarding_test.
class VerifiedVantaSession extends VantaApiSessionController {
  @override
  VantaApiSessionState build() {
    final address = ref.watch(authProvider).identity?.walletAddress?.toLowerCase();
    // Like the real controller, a signed-out wallet has no ready session.
    return address == null
        ? const VantaApiSessionState(VantaApiSessionStatus.signedOut)
        : VantaApiSessionState(VantaApiSessionStatus.ready, address: address);
  }
}
