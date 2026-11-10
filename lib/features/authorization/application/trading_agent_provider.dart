import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../portfolio/domain/account_request_signing.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/device_trading_agent_store.dart';
import '../domain/trading_agent.dart';

final tradingAgentClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final tradingAgentStoreProvider = Provider<TradingAgentStore>((ref) {
  return DeviceTradingAgentStore(now: ref.watch(tradingAgentClockProvider));
});

final tradingAgentProvider = FutureProvider<TradingAgent?>((ref) async {
  final identity = ref.watch(authProvider.select((s) => s.identity));
  if (identity?.walletAddress == null || !identity!.signingAvailable) return null;
  final agent = await ref
      .watch(tradingAgentStoreProvider)
      .load(identity.id, identity.walletAddress!);
  if (!ref.mounted || agent == null) return null;
  final lifetime = agent.expiresAt.difference(ref.read(tradingAgentClockProvider)());
  if (lifetime <= Duration.zero) return null;
  final timer = Timer(lifetime, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return agent;
});

final asterRequestAuthorizationProvider = Provider<AccountRequestAuthorization>(
  (ref) => _authorization(ref, allowUnknown: false),
);

/// Only the explicit read-only authorization check may test an uncertain grant.
final asterAuthorizationCheckProvider = Provider<AccountRequestAuthorization>(
  (ref) => _authorization(ref, allowUnknown: true),
);

AccountRequestAuthorization _authorization(Ref ref, {required bool allowUnknown}) {
  var revision = 0;
  ref.listen(
    authProvider.select(
      (s) => (
        s.identity?.id,
        s.identity?.walletAddress,
        s.identity?.walletKind,
        s.identity?.signingAvailable,
        s.busy,
      ),
    ),
    (_, _) => revision++,
  );
  final store = ref.watch(tradingAgentStoreProvider);
  return (owner) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    final generation = revision;
    void current() {
      if (!ref.mounted ||
          generation != revision ||
          auth.busy ||
          identity == null ||
          !identity.signingAvailable ||
          identity.walletAddress?.toLowerCase() != owner.toLowerCase()) {
        throw const AccountReadFailure('authWalletChanged');
      }
    }

    current();
    final signing = await store.resolve(identity!.id, owner, allowUnknown: allowUnknown);
    current();
    return AccountRequestIdentity(
      address: signing.address,
      onRejected: allowUnknown
          ? null
          : () async {
              current();
              final agent = await store.load(identity.id, owner);
              current();
              if (agent?.address == signing.address && agent?.status == TradingAgentStatus.active) {
                await store.setStatus(agent!, TradingAgentStatus.rejected);
                if (ref.mounted) ref.invalidate(tradingAgentProvider);
              }
            },
      sign: ({required expectedAddress, required typedData}) async {
        current();
        final signature = await signing.sign(
          expectedAddress: expectedAddress,
          typedData: typedData,
        );
        current();
        return signature;
      },
    );
  };
}
