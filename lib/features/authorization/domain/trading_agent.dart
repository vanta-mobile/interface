import '../../portfolio/domain/account_request_signing.dart';

enum TradingAgentStatus { prepared, unknown, active, rejected }

/// Public metadata only. Private keys never enter providers or UI state.
class TradingAgent {
  const TradingAgent({
    required this.identityId,
    required this.owner,
    required this.address,
    required this.expiresAt,
    required this.status,
  });
  final String identityId, owner, address;
  final DateTime expiresAt;
  final TradingAgentStatus status;
}

abstract interface class TradingAgentStore {
  Future<TradingAgent?> load(String identityId, String owner);
  Future<TradingAgent> prepare(String identityId, String owner, DateTime expiresAt);
  Future<void> setStatus(TradingAgent agent, TradingAgentStatus status);
  Future<AccountRequestIdentity> resolve(
    String identityId,
    String owner, {
    bool allowUnknown = false,
  });
}
