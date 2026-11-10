import 'dart:async';

import '../../../core/errors/api_error_details.dart';
import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_signing_preparation.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/trading_authorization_repository.dart';
import '../domain/trading_authorization.dart';
import '../domain/trading_agent.dart';
import 'trading_agent_provider.dart';

final tradingAuthorizationClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final tradingAuthorizationRepositoryProvider = Provider<TradingAuthorizationRepository>((ref) {
  final futures = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease()),
      spot = AsterSpotService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(() {
    futures.close();
    spot.close();
  });
  final identity = ref.watch(identityRepositoryProvider);
  return AsterTradingAuthorizationRepository(
    futures,
    spot,
    identity.signWalletRequest,
    agents: ref.watch(tradingAgentStoreProvider),
    checkAuthorization: ref.watch(asterAuthorizationCheckProvider),
    signingPreparation: identity is WalletSigningPreparation
        ? identity as WalletSigningPreparation
        : null,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(tradingAuthorizationClockProvider),
  );
});
final tradingAuthorizationProvider =
    NotifierProvider<TradingAuthorizationController, TradingAuthorizationState>(
      TradingAuthorizationController.new,
    );

/// Mounted only for a fresh Privy login, never for a restored session or EOA.
final embeddedLoginTradingAuthorizationProvider = Provider.autoDispose.family<void, String>((
  ref,
  identityId,
) {
  var attempted = false;
  var scheduled = false;
  bool ready(AuthSession auth) =>
      !auth.busy &&
      auth.failure == null &&
      auth.identity?.id == identityId &&
      auth.identity?.walletKind == WalletKind.embedded &&
      auth.identity?.walletAddress != null &&
      auth.identity!.signingAvailable;
  ref.listen(authProvider, (_, next) {
    if (attempted || scheduled || !ready(next)) return;
    scheduled = true;
    // Let the login/wallet state and authorization identity guards settle first.
    scheduleMicrotask(() {
      scheduled = false;
      if (!ref.mounted || attempted || !ready(ref.read(authProvider))) return;
      attempted = true;
      unawaited(ref.read(tradingAuthorizationProvider.notifier).enableTrading());
    });
  }, fireImmediately: true);
});

class TradingAuthorizationController extends Notifier<TradingAuthorizationState> {
  int _generation = 0;
  bool _working = false;
  bool _submitting = false;
  @override
  TradingAuthorizationState build() {
    ref.watch(tradingAuthorizationRepositoryProvider);
    ref.listen(tradingAgentProvider, (previous, next) {
      if (_working || !next.hasValue || next.isLoading) return;
      final before = previous?.asData?.value;
      final agent = next.asData?.value;
      if (agent?.status == TradingAgentStatus.unknown) {
        state = TradingAuthorizationState(
          result: TradingAuthorizationResult.unknown,
          check: state.check,
        );
      } else if ((agent == null && before != null ||
              agent?.status == TradingAgentStatus.rejected) &&
          (state.result == TradingAuthorizationResult.acknowledged ||
              state.result == TradingAuthorizationResult.unknown)) {
        state = const TradingAuthorizationState();
      }
    });
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
      (a, b) {
        if (a != b) {
          _generation++;
          final sameWallet = a != null && a.$1 == b.$1 && a.$2 == b.$2 && a.$3 == b.$3;
          state = sameWallet
              ? TradingAuthorizationState(
                  result: state.result ?? (_submitting ? TradingAuthorizationResult.unknown : null),
                  check: state.check,
                )
              : const TradingAuthorizationState();
        }
      },
    );
    ref.onDispose(() => _generation++);
    return const TradingAuthorizationState();
  }

  bool _current(AuthIdentity i, int g) =>
      ref.mounted &&
      g == _generation &&
      ref.read(authProvider).identity?.id == i.id &&
      ref.read(authProvider).identity?.walletAddress == i.walletAddress;
  void prepare({bool canWithdraw = false, String ipWhitelist = ''}) {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working ||
        auth.busy ||
        identity?.walletAddress == null ||
        state.result == TradingAuthorizationResult.unknown) {
      return;
    }
    if (!identity!.signingAvailable) {
      state = const TradingAuthorizationState(failure: 'authWalletReconnect');
      return;
    }
    final whitelist = canWithdraw ? normalizeAgentIpWhitelist(ipWhitelist) : '';
    if (whitelist == null) {
      state = const TradingAuthorizationState(failure: 'authorizationIpInvalid');
      return;
    }
    final now = ref.read(tradingAuthorizationClockProvider)().toUtc();
    state = TradingAuthorizationState(
      review: TradingAuthorizationReview(
        identity: identity,
        canWithdraw: canWithdraw,
        ipWhitelist: whitelist,
        preparedAt: now,
        expiresAt: now.add(const Duration(days: 30)),
      ),
    );
  }

  void cancel() {
    if (!_working && state.result != TradingAuthorizationResult.unknown) {
      state = const TradingAuthorizationState();
    }
  }

  /// Uses the default trading-only grant for onboarding, including Privy login.
  /// An uncertain dispatched write must be checked, never submitted again.
  Future<void> enableTrading() async {
    if (_working || state.result != null) return;
    prepare();
    if (state.review case final review?) await confirm(review);
  }

  void stop() {
    _generation++;
    state = TradingAuthorizationState(
      result: state.result ?? (_submitting ? TradingAuthorizationResult.unknown : null),
      check: state.check,
    );
  }

  Future<void> confirm(TradingAuthorizationReview review) async {
    if (_working || !identical(state.review, review)) return;
    final g = ++_generation;
    if (!_current(review.identity, g)) return;
    _working = true;
    _submitting = true;
    state = const TradingAuthorizationState(busy: true);
    try {
      final result = await ref
          .read(tradingAuthorizationRepositoryProvider)
          .enable(review: review, isCurrent: () => _current(review.identity, g));
      if (_current(review.identity, g)) state = TradingAuthorizationState(result: result);
    } catch (e) {
      if (_current(review.identity, g)) {
        state = TradingAuthorizationState(
          errorDetails: errorDetailsOf(e),
          failure: e is AccountReadFailure ? e.key : 'accountReadFailed',
        );
      }
    } finally {
      if (ref.mounted) ref.invalidate(tradingAgentProvider);
      _submitting = false;
      _working = false;
    }
  }

  Future<void> check() async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity?.walletAddress == null) return;
    if (!identity!.signingAvailable) {
      state = TradingAuthorizationState(
        result: state.result,
        check: state.check,
        failure: 'authWalletReconnect',
      );
      return;
    }
    final g = ++_generation, previous = state;
    _working = true;
    state = TradingAuthorizationState(busy: true, result: previous.result, check: previous.check);
    try {
      final result = await ref
          .read(tradingAuthorizationRepositoryProvider)
          .check(address: identity.walletAddress!, isCurrent: () => _current(identity, g));
      if (_current(identity, g)) {
        state = TradingAuthorizationState(result: previous.result, check: result);
      }
    } catch (e) {
      if (_current(identity, g)) {
        state = TradingAuthorizationState(
          result: previous.result,
          check: previous.check,
          errorDetails: errorDetailsOf(e),
          failure: e is AccountReadFailure ? e.key : 'accountReadFailed',
        );
      }
    } finally {
      _working = false;
    }
  }
}
