import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/market_providers.dart';
import '../../market/application/selection_providers.dart';
import '../domain/account_change_stream.dart';
import '../domain/account_snapshot.dart';
import '../domain/futures_asset_mode.dart';
import 'account_change_provider.dart';
import 'account_read_provider.dart';
import 'asset_index_provider.dart';
import 'live_order_provider.dart';
import 'main_order_capacity_provider.dart';
import 'main_order_pricing_wait.dart';
import 'symbol_settings_activity.dart';

enum MainOrderRefreshStage { idle, monitoring, account, capacity, pricing }

class MainOrderRefreshState {
  const MainOrderRefreshState({this.stage = MainOrderRefreshStage.idle, this.failure});
  final MainOrderRefreshStage stage;
  final AccountReadFailure? failure;
  bool get loading => stage != MainOrderRefreshStage.idle;
}

final mainOrderRefreshProvider =
    NotifierProvider<MainOrderRefreshController, MainOrderRefreshState>(
      MainOrderRefreshController.new,
    );

/// One refresh restores all facts needed by the opening form. The authorized
/// login coordinator or an explicit refresh initiates it; quotes never do.
class MainOrderRefreshController extends Notifier<MainOrderRefreshState> {
  int _revision = 0;
  Completer<bool>? _cancel;
  MainOrderPricingWait? _pricing;

  @override
  MainOrderRefreshState build() {
    ref.listen(authProvider.select((s) => (s.identity, s.busy)), (a, b) {
      if (a != b) {
        stop();
        if (a?.$1 != b.$1) state = const MainOrderRefreshState();
      }
    });
    ref.listen(accountReadProvider, (previous, next) {
      // An explicit successful account read verifies the prerequisite again.
      // Opening funding or dispatching a deposit is never such evidence.
      if (next.account != null &&
          !next.stale &&
          next.failure == null &&
          (previous?.failure?.requiresDeposit == true ||
              state.failure?.requiresDeposit == true ||
              ref.read(liveOrderProvider).failure?.requiresDeposit == true ||
              ref.read(mainOrderCapacityProvider).failure?.requiresDeposit == true)) {
        state = const MainOrderRefreshState();
        if (ref.read(liveOrderProvider).failure?.requiresDeposit == true) {
          ref.invalidate(liveOrderProvider);
        }
        if (ref.read(mainOrderCapacityProvider).failure?.requiresDeposit == true) {
          ref.invalidate(mainOrderCapacityProvider);
        }
      }
    });
    ref.listen(symbolProvider, (a, b) {
      if (a != b) stop();
    });
    ref.onDispose(() {
      _revision++;
      _pricing?.cancel();
      if (_cancel?.isCompleted == false) _cancel!.complete(false);
    });
    return const MainOrderRefreshState();
  }

  void stop() {
    if (!state.loading) return;
    final stage = state.stage;
    _revision++;
    _pricing?.cancel();
    _pricing = null;
    if (stage == MainOrderRefreshStage.account) {
      ref.read(liveOrderProvider.notifier).stopReading();
    } else if (stage == MainOrderRefreshStage.capacity) {
      ref.read(mainOrderCapacityProvider.notifier).stop();
    }
    if (_cancel?.isCompleted == false) _cancel!.complete(false);
    state = const MainOrderRefreshState();
  }

  Future<bool> refresh(String symbol) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    final live = ref.read(liveOrderProvider), activity = ref.read(symbolSettingsActivityProvider);
    if (state.failure?.requiresDeposit == true ||
        ref.read(accountReadProvider).failure?.requiresDeposit == true ||
        live.failure?.requiresDeposit == true ||
        ref.read(mainOrderCapacityProvider).failure?.requiresDeposit == true ||
        state.loading ||
        live.busy ||
        live.needsRecheck ||
        auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress == null ||
        activity.owner != null ||
        activity.recoveryBlocked ||
        activity.unresolved ||
        symbol != ref.read(symbolProvider) ||
        !ref.read(quoteUpdatesActiveProvider)) {
      return false;
    }
    final revision = ++_revision;
    final cancel = _cancel = Completer<bool>();
    final started = ref.read(liveOrderClockProvider)();
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        ref.read(authProvider).identity == identity &&
        !ref.read(authProvider).busy &&
        ref.read(symbolProvider) == symbol;
    state = const MainOrderRefreshState(stage: MainOrderRefreshStage.monitoring);
    return Future.any([_refresh(symbol, started, current), cancel.future]);
  }

  Future<bool> _refresh(String symbol, DateTime started, bool Function() current) async {
    void check() {
      if (!current()) throw const AccountReadFailure('authWalletChanged');
    }

    try {
      await _resumeMonitoring(current);
      check();
      // Public reconnection and private re-reads are separate. New receipts,
      // including a newly enlarged symbol scope, must satisfy the final wait.
      ref.read(quoteReconnectProvider.notifier).reconnect();
      state = const MainOrderRefreshState(stage: MainOrderRefreshStage.account);
      await ref.read(liveOrderProvider.notifier).load(symbol);
      check();
      final live = ref.read(liveOrderProvider);
      if (live.context?.symbol != symbol || live.stale || live.failure != null) {
        throw live.failure ?? const AccountReadFailure('liveOrderContextExpired');
      }
      state = const MainOrderRefreshState(stage: MainOrderRefreshStage.capacity);
      await ref.read(mainOrderCapacityProvider.notifier).load(symbol);
      check();
      final snapshot = ref.read(mainOrderCapacityProvider.notifier).current;
      if (snapshot == null) {
        throw ref.read(mainOrderCapacityProvider).failure ??
            const AccountReadFailure('liveCapacityStale');
      }
      state = const MainOrderRefreshState(stage: MainOrderRefreshStage.pricing);
      if (snapshot.assetMode == FuturesAssetMode.multi) {
        await ref.read(assetIndexProvider.notifier).refresh();
        check();
      }
      final waiting = MainOrderPricingWait(ref, snapshot, current, notBefore: started);
      _pricing = waiting;
      waiting.start();
      await waiting.future;
      check();
      _pricing = null;
      state = const MainOrderRefreshState();
      return true;
    } catch (error) {
      if (current()) {
        _pricing = null;
        state = MainOrderRefreshState(
          failure: error is AccountReadFailure
              ? error
              : const AccountReadFailure('accountReadFailed'),
        );
      }
      return false;
    }
  }

  Future<void> _resumeMonitoring(bool Function() current) async {
    final initial = ref.read(accountChangeProvider);
    if (initial.step != AccountReadStep.idle) {
      throw const AccountReadFailure('liveOrderSettingsBusy');
    }
    // A stopped/expired lease is not silently authorized. Explicit reads still
    // work with the existing bounded preflight, without claiming live coverage.
    if ({
      AccountChangeConnection.stopped,
      AccountChangeConnection.expired,
    }.contains(initial.connection)) {
      return;
    }
    if (initial.connection == AccountChangeConnection.connected) return;
    ref.read(accountChangeProvider.notifier).reconnect();
    final completed = Completer<void>();
    void inspect(AccountChangeState s) {
      if (completed.isCompleted) return;
      if (!current()) {
        completed.completeError(const AccountReadFailure('authWalletChanged'));
      } else if (s.connection == AccountChangeConnection.connected) {
        completed.complete();
      } else if ({
        AccountChangeConnection.disconnected,
        AccountChangeConnection.expired,
        AccountChangeConnection.paused,
        AccountChangeConnection.stopped,
      }.contains(s.connection)) {
        completed.completeError(s.failure ?? const AccountReadFailure('accountNetwork'));
      }
    }

    final subscription = ref.listen(accountChangeProvider, (_, next) => inspect(next));
    final timer = Timer(const Duration(seconds: 12), () {
      if (!completed.isCompleted) {
        completed.completeError(const AccountReadFailure('accountNetwork'));
      }
    });
    final cancellation = _cancel!.future.then((_) {
      if (!completed.isCompleted) {
        completed.completeError(const AccountReadFailure('authWalletChanged'));
      }
    });
    try {
      inspect(ref.read(accountChangeProvider));
      await completed.future;
    } finally {
      subscription.close();
      timer.cancel();
      // Keep the cancellation continuation observed; it owns no timer/socket.
      unawaited(cancellation);
    }
  }
}
