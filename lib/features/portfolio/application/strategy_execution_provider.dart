import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_strategy_execution_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/strategy_execution.dart';
import 'account_read_provider.dart';
import 'account_change_provider.dart';
import 'live_order_provider.dart';
import 'symbol_settings_activity.dart';

final strategyExecutionRepositoryProvider = Provider.autoDispose<StrategyExecutionRepository>((
  ref,
) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedStrategyExecutionRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    ref.watch(asterReadNoncesProvider),
    ref.watch(liveOrderClockProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});
final strategyExecutionProvider = NotifierProvider.autoDispose
    .family<StrategyExecutionController, StrategyExecutionState, StrategyExecutionQuery>(
      StrategyExecutionController.new,
    );

class StrategyExecutionController extends Notifier<StrategyExecutionState> {
  StrategyExecutionController(this.query);
  final StrategyExecutionQuery query;
  int _revision = 0, _events = 0;
  int? _lease;
  SymbolSettingsActivityController? _activity;
  Timer? _expiry;
  DateTime get _now => ref.read(liveOrderClockProvider)();
  @override
  StrategyExecutionState build() {
    ref.watch(strategyExecutionRepositoryProvider);
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (before, after) {
        if (before == after) return;
        _revision++;
        _expiry?.cancel();
        _release();
        state = const StrategyExecutionState();
      },
    );
    ref.listen(accountChangeProvider, (a, b) {
      if (!identical(a, b)) markStale();
    });
    ref.listen(symbolSettingsActivityProvider.select((s) => s.epoch), (a, b) {
      if (a != b) markStale();
    });
    ref.onDispose(() {
      _revision++;
      _expiry?.cancel();
      // Other providers cannot be synchronously changed during disposal.
      final lease = _lease, activity = _activity;
      _lease = null;
      _activity = null;
      if (lease != null) {
        scheduleMicrotask(() => activity?.finish(lease, unresolved: false));
      }
    });
    return const StrategyExecutionState();
  }

  void _release() {
    final lease = _lease, activity = _activity;
    _lease = null;
    _activity = null;
    if (lease != null) activity?.finish(lease, unresolved: false);
  }

  void markStale() {
    _events++;
    if (state.snapshot == null) return;
    state = StrategyExecutionState(
      snapshot: state.snapshot,
      failure: state.failure,
      step: state.step,
      sequence: state.sequence,
      stale: true,
    );
  }

  void onLifecycleChanged() {
    markStale();
  }

  void stop() {
    if (!state.busy) return;
    _revision++;
    _release();
    state = StrategyExecutionState(
      snapshot: state.snapshot,
      stale: state.snapshot != null,
      failure: const AccountReadFailure('strategyExecutionStopped'),
    );
  }

  Future<void> read() async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (state.busy ||
        auth.busy ||
        identity == null ||
        !identity.signingAvailable ||
        identity.walletAddress?.toLowerCase() != query.order.address.toLowerCase() ||
        ref.read(symbolSettingsActivityProvider).owner != null) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.recovery, checkingOnly: true);
    if (lease == null) return;
    _lease = lease;
    _activity = activity;
    final revision = ++_revision, events = _events;
    bool current() {
      if (!ref.mounted || _revision != revision) return false;
      final current = ref.read(authProvider).identity;
      return current?.id == identity.id &&
          current?.walletKind == identity.walletKind &&
          current?.signingAvailable == true &&
          current?.walletAddress?.toLowerCase() == query.order.address.toLowerCase();
    }

    final previous = state.snapshot;
    _expiry?.cancel();
    state = StrategyExecutionState(
      snapshot: previous,
      stale: previous != null,
      step: AccountReadStep.preparing,
    );
    try {
      final snapshot = await ref
          .read(strategyExecutionRepositoryProvider)
          .read(
            query,
            isCurrent: current,
            onStep: (step, sequence) {
              if (current()) {
                state = StrategyExecutionState(
                  snapshot: previous,
                  stale: previous != null,
                  step: step,
                  sequence: sequence,
                );
              }
            },
          );
      if (!current()) return;
      if (!identical(snapshot.query, query) || snapshot.strategy.strategyId != query.strategyId) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final age = _now.difference(snapshot.strategyCheckedAt);
      final stale = events != _events || age.isNegative || age >= const Duration(seconds: 30);
      state = StrategyExecutionState(snapshot: snapshot, stale: stale);
      if (!stale) {
        _expiry = Timer(const Duration(seconds: 30) - age, () {
          if (ref.mounted) markStale();
        });
      }
    } catch (error) {
      if (current()) {
        state = StrategyExecutionState(
          snapshot: previous,
          stale: previous != null,
          failure: error is AccountReadFailure
              ? error
              : const AccountReadFailure('accountReadFailed'),
        );
      }
    } finally {
      // stop() can release and a new read can start before an old future ends.
      if (_lease == lease) _release();
    }
  }
}
