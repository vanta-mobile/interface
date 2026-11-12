import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../domain/account_snapshot.dart';
import '../domain/trading_history.dart';

/// Direct Aster tabs never depend on Vanta configuration or SIWE. Only an
/// active device grant enables passive reads; missing grants use existing UI.
class TradingHistoryAccess {
  const TradingHistoryAccess({
    this.address,
    this.ready = false,
    this.pending = false,
    this.unavailable = false,
    this.failure,
  });
  final String? address;
  final bool ready, pending, unavailable;
  final Object? failure;
}

final tradingHistoryAccessProvider = Provider.autoDispose
    .family<TradingHistoryAccess, TradingHistoryTab>((ref, tab) {
      if (!historyUsesAster(tab)) {
        final session = ref.watch(vantaApiSessionProvider);
        return TradingHistoryAccess(
          address: session.address,
          ready: session.ready,
          pending: session.pending,
          unavailable: session.status == VantaApiSessionStatus.unavailable,
          failure: session.failure,
        );
      }
      final auth = ref.watch(authProvider), identity = auth.identity;
      final agent = ref.watch(tradingAgentProvider);
      final address = identity?.walletAddress?.toLowerCase();
      if (address == null || identity?.signingAvailable != true) {
        return TradingHistoryAccess(address: address);
      }
      if (agent.isLoading || auth.busy) {
        return TradingHistoryAccess(address: address, pending: true);
      }
      final grant = agent.asData?.value;
      final valid =
          grant != null &&
          grant.status == TradingAgentStatus.active &&
          grant.identityId == identity!.id &&
          grant.owner.toLowerCase() == address &&
          grant.expiresAt.isAfter(ref.watch(tradingAgentClockProvider)());
      return TradingHistoryAccess(
        ready: valid,
        address: address,
        failure: valid ? null : agent.error ?? const AccountReadFailure('authorizationRequired'),
      );
    });

/// The UI captures this owner as well as its address before showing details.
final tradingHistoryIdentityProvider = Provider(
  (ref) => ref.watch(
    authProvider.select(
      (s) => (
        s.identity?.id,
        s.identity?.walletAddress?.toLowerCase(),
        s.identity?.walletKind,
        s.identity?.signingAvailable,
      ),
    ),
  ),
);
