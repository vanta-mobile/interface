import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/application/builder_authorization_provider.dart';
import '../../authorization/domain/builder_authorization.dart';
import '../../authorization/application/trading_authorization_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../authorization/domain/trading_authorization.dart';
import '../domain/auth_session.dart';
import 'auth_provider.dart';
import 'vanta_api_session_provider.dart';

String? onboardingIdentityKey(AuthIdentity? identity) => identity == null
    ? null
    : '${identity.walletKind.name}:${identity.id}:${identity.walletAddress?.toLowerCase()}';

class WalletOnboardingStatus {
  const WalletOnboardingStatus({
    this.checking = false,
    this.tradingReady = false,
    this.verified = false,
    this.agentFailure,
    this.unknown = false,
  });
  final bool checking, tradingReady, verified, unknown;
  final Object? agentFailure;
  bool get complete => !checking && !unknown && agentFailure == null && tradingReady && verified;
}

final walletOnboardingStatusProvider = Provider<WalletOnboardingStatus>((ref) {
  final auth = ref.watch(authProvider);
  final identity = auth.identity;
  if (identity?.walletAddress == null || !identity!.signingAvailable) {
    return WalletOnboardingStatus(checking: auth.busy);
  }
  final agent = ref.watch(tradingAgentProvider);
  final builder = ref.watch(builderApprovalProvider);
  final authorization = ref.watch(tradingAuthorizationProvider);
  final session = ref.watch(vantaApiSessionProvider);
  final address = identity.walletAddress!.toLowerCase();
  final sessionMatches = session.address == address;
  final builderReady =
      builder.asData?.value?.status == BuilderApprovalStatus.approved &&
          builder.asData!.value!.maxFeeRate >= VantaBuilder.approvalCap ||
      authorization.result == TradingAuthorizationResult.acknowledged &&
          authorization.builderAuthorized;
  return WalletOnboardingStatus(
    checking:
        auth.busy ||
        agent.isLoading ||
        builder.isLoading ||
        session.status == VantaApiSessionStatus.restoring ||
        (session.status != VantaApiSessionStatus.unavailable && !sessionMatches),
    tradingReady:
        (agent.asData?.value?.status == TradingAgentStatus.active ||
            authorization.result == TradingAuthorizationResult.acknowledged) &&
        builderReady,
    verified: sessionMatches && session.ready,
    agentFailure: agent.error ?? builder.error,
    unknown:
        agent.asData?.value?.status == TradingAgentStatus.unknown ||
        builder.asData?.value?.status == BuilderApprovalStatus.unknown ||
        authorization.result == TradingAuthorizationResult.unknown,
  );
});

class WalletOnboardingProgress {
  const WalletOnboardingProgress({this.busy = false, this.automaticKey});
  final bool busy;

  /// Set before the one automatic attempt; failures require an explicit retry.
  final String? automaticKey;
}

final walletOnboardingProvider =
    NotifierProvider<WalletOnboardingController, WalletOnboardingProgress>(
      WalletOnboardingController.new,
    );

/// Coordinates the existing grant and SIWE controllers. No wallet-specific RPCs.
class WalletOnboardingController extends Notifier<WalletOnboardingProgress> {
  int _generation = 0;
  String? _automaticRequested;

  @override
  WalletOnboardingProgress build() {
    ref.listen(authProvider.select((s) => onboardingIdentityKey(s.identity)), (_, _) {
      _generation++;
      _automaticRequested = null;
      state = const WalletOnboardingProgress();
    });
    ref.listen(walletOnboardingStatusProvider, (_, _) => _scheduleAutomatic());
    ref.onDispose(() => _generation++);
    return const WalletOnboardingProgress();
  }

  void startAutomatic(String identityKey) {
    if (_automaticRequested == identityKey) return;
    _automaticRequested = identityKey;
    _scheduleAutomatic();
  }

  void stopAutomatic(String identityKey) {
    if (_automaticRequested == identityKey) _automaticRequested = null;
  }

  void _scheduleAutomatic() {
    scheduleMicrotask(() {
      if (!ref.mounted || state.busy) return;
      final auth = ref.read(authProvider), identity = auth.identity;
      final key = onboardingIdentityKey(identity);
      final status = ref.read(walletOnboardingStatusProvider);
      if (key != _automaticRequested ||
          key == null ||
          state.automaticKey == key ||
          identity?.walletKind != WalletKind.embedded ||
          auth.busy ||
          status.checking) {
        return;
      }
      state = WalletOnboardingProgress(automaticKey: key);
      if (auth.failure == null && identity?.signingAvailable == true && !status.unknown) {
        unawaited(continueSigning(completeAll: true, retryPendingBuilder: false));
      }
    });
  }

  Future<void> continueSigning({bool completeAll = false, bool retryPendingBuilder = true}) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (state.busy || auth.busy || identity?.signingAvailable != true) return;
    final generation = _generation;
    final key = onboardingIdentityKey(identity);
    bool current() =>
        ref.mounted &&
        generation == _generation &&
        key == onboardingIdentityKey(ref.read(authProvider).identity);
    final automaticKey = state.automaticKey;
    final automaticOwner = _automaticRequested == key;
    state = WalletOnboardingProgress(busy: true, automaticKey: automaticKey);
    try {
      var status = ref.read(walletOnboardingStatusProvider);
      if (status.checking) return;
      if (status.agentFailure != null) {
        ref.invalidate(tradingAgentProvider);
        ref.invalidate(builderApprovalProvider);
        try {
          await Future.wait([
            ref.read(tradingAgentProvider.future),
            ref.read(builderApprovalProvider.future),
          ]);
        } catch (_) {
          return;
        }
        if (!current()) return;
        status = ref.read(walletOnboardingStatusProvider);
      }
      var resumePendingBuilder = false;
      if (status.unknown) {
        await ref.read(tradingAuthorizationProvider.notifier).check();
        if (!current()) return;
        if (!retryPendingBuilder ||
            ref.read(tradingAuthorizationProvider).check?.canResumeBuilder != true) {
          return;
        }
        // A renewed user request may resume only the verified missing Builder.
        // Read-back after a dispatched attempt below never enters this path.
        resumePendingBuilder = true;
      }
      if (!status.tradingReady || resumePendingBuilder) {
        await ref
            .read(tradingAuthorizationProvider.notifier)
            .enableTrading(retryPendingBuilder: resumePendingBuilder);
        if (!current()) return;
        if (ref.read(tradingAuthorizationProvider).result == TradingAuthorizationResult.unknown) {
          // The user already requested authorization. Reconcile with reads in
          // the same action; never turn a lost reply into another signed write.
          await ref.read(tradingAuthorizationProvider.notifier).check();
          return;
        }
        if (!completeAll) return;
        if (ref.read(tradingAuthorizationProvider).result !=
            TradingAuthorizationResult.acknowledged) {
          return;
        }
      }
      if (!current() || automaticOwner && _automaticRequested != key) return;
      await ref.read(vantaApiSessionProvider.notifier).ensure();
    } finally {
      if (current()) state = WalletOnboardingProgress(automaticKey: automaticKey);
    }
  }
}
