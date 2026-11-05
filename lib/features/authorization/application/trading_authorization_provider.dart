import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/trading_authorization_repository.dart';
import '../domain/trading_authorization.dart';

final tradingAuthorizationClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final tradingAuthorizationRepositoryProvider = Provider<TradingAuthorizationRepository>((ref) {
  final futures = AsterAccountService(), spot = AsterSpotService();
  ref.onDispose(() {
    futures.close();
    spot.close();
  });
  return AsterTradingAuthorizationRepository(
    futures,
    spot,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(tradingAuthorizationClockProvider),
  );
});
final tradingAuthorizationProvider =
    NotifierProvider<TradingAuthorizationController, TradingAuthorizationState>(
      TradingAuthorizationController.new,
    );

class TradingAuthorizationController extends Notifier<TradingAuthorizationState> {
  int _generation = 0;
  bool _working = false;
  @override
  TradingAuthorizationState build() {
    ref.watch(tradingAuthorizationRepositoryProvider);
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
          state = const TradingAuthorizationState();
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
    if (_working || auth.busy || identity?.walletAddress == null) return;
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
    if (!_working) state = const TradingAuthorizationState();
  }

  void stop() {
    _generation++;
    state = const TradingAuthorizationState();
  }

  Future<void> confirm(TradingAuthorizationReview review) async {
    if (_working || !identical(state.review, review)) return;
    final g = ++_generation;
    if (!_current(review.identity, g)) return;
    _working = true;
    state = const TradingAuthorizationState(busy: true);
    try {
      final result = await ref
          .read(tradingAuthorizationRepositoryProvider)
          .enable(review: review, isCurrent: () => _current(review.identity, g));
      if (_current(review.identity, g)) state = TradingAuthorizationState(result: result);
    } catch (e) {
      if (_current(review.identity, g)) {
        state = TradingAuthorizationState(
          failure: e is AccountReadFailure ? e.key : 'accountReadFailed',
        );
      }
    } finally {
      _working = false;
    }
  }

  Future<void> check() async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity?.walletAddress == null) return;
    if (!identity!.signingAvailable) {
      state = const TradingAuthorizationState(failure: 'authWalletReconnect');
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
          failure: e is AccountReadFailure ? e.key : 'accountReadFailed',
        );
      }
    } finally {
      _working = false;
    }
  }
}
