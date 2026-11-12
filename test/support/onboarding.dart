import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';

/// Existing authorization-only tests start with an already verified API session.
/// Full missing-session/signature behavior is covered by wallet_onboarding_test.
class VerifiedVantaSession extends VantaApiSessionController {
  @override
  VantaApiSessionState build() => VantaApiSessionState(
    VantaApiSessionStatus.ready,
    address: ref.watch(authProvider).identity?.walletAddress?.toLowerCase(),
  );
}
