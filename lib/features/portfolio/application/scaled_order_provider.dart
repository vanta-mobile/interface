import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/scaled_order.dart';
import 'account_change_provider.dart';
import 'account_read_provider.dart';
import 'live_order_provider.dart';
import 'open_orders_provider.dart';
import 'position_risk_provider.dart';
import 'position_adl_provider.dart';
import 'symbol_settings_activity.dart';

final scaledOrderProvider = NotifierProvider<ScaledOrderController, ScaledOrderState>(
  ScaledOrderController.new,
);

class ScaledOrderController extends Notifier<ScaledOrderState> {
  int _revision = 0;
  bool _stop = false;
  final _random = Random.secure();
  DateTime get _now => ref.read(liveOrderClockProvider)();
  int createRandomSeed() => _random.nextInt(1 << 32);
  @override
  ScaledOrderState build() {
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
        state = ScaledOrderState();
      },
    );
    ref.listen(accountChangeProvider, (before, after) {
      if (before != after) ref.read(liveOrderProvider.notifier).markStale();
    });
    ref.onDispose(() => _revision++);
    return ScaledOrderState();
  }

  bool _fresh(LiveOrderContext data) {
    final age = _now.difference(data.receivedAt);
    return age >= Duration.zero && age < const Duration(seconds: 30);
  }

  ScaledOrderIntent? prepare(String symbol, ScaledOrderDraft draft) {
    final live = ref.read(liveOrderProvider), auth = ref.read(authProvider);
    final data = live.context, activity = ref.read(symbolSettingsActivityProvider);
    if (state.busy ||
        auth.busy ||
        live.busy ||
        live.stale ||
        data == null ||
        data.symbol != symbol ||
        !_fresh(data) ||
        activity.owner != null ||
        activity.recoveryBlocked ||
        auth.identity?.signingAvailable != true ||
        auth.identity?.walletAddress?.toLowerCase() != data.address.toLowerCase()) {
      return null;
    }
    try {
      final plan = planScaledOrder(data, draft);
      final prefix =
          'vs-${_now.microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(1 << 32).toRadixString(36)}';
      return ScaledOrderIntent(
        context: data,
        plan: plan,
        clientIds: List.generate(plan.orders.length, (i) => '$prefix-${i + 1}'),
        revision: _revision,
        epoch: activity.epoch,
      );
    } on AccountReadFailure {
      return null;
    }
  }

  void stop() {
    if (!ref.mounted || !state.busy) return;
    _stop = true;
    _emit(state.intent!, state.items, state.step, state.currentIndex);
  }

  Future<void> submit(ScaledOrderIntent intent) => _run(intent, checkingOnly: false);
  Future<void> recheck() async {
    if (state.intent case final intent? when state.needsRecheck && !state.busy) {
      await _run(intent, checkingOnly: true);
    }
  }

  Future<void> _run(ScaledOrderIntent intent, {required bool checkingOnly}) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (state.busy ||
        auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress?.toLowerCase() != intent.address.toLowerCase()) {
      return;
    }
    if (checkingOnly) {
      if (!identical(state.intent, intent)) return;
    } else {
      final live = ref.read(liveOrderProvider), activity = ref.read(symbolSettingsActivityProvider);
      if (intent.revision != _revision ||
          live.busy ||
          live.stale ||
          !identical(live.context, intent.context) ||
          !_fresh(intent.context) ||
          activity.epoch != intent.epoch ||
          !intent.valid) {
        return;
      }
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.scaled, checkingOnly: checkingOnly);
    if (lease == null) return;
    final revision = ++_revision;
    bool current() =>
        ref.mounted &&
        _revision == revision &&
        ref.read(authProvider).identity?.id == identity?.id &&
        ref.read(authProvider).identity?.walletKind == identity?.walletKind &&
        ref.read(authProvider).identity?.walletAddress?.toLowerCase() ==
            intent.address.toLowerCase() &&
        ref.read(authProvider).identity?.signingAvailable == true;
    final items = checkingOnly
        ? [...state.items]
        : List.generate(
            intent.plan.orders.length,
            (i) => ScaledOrderItem(
              index: i,
              draft: intent.plan.orders[i],
              clientId: intent.clientIds[i],
            ),
          );
    _stop = false;
    _emit(intent, items, LiveOrderStep.preparing, null);
    try {
      for (var i = 0; i < items.length; i++) {
        if (!current()) return;
        if (_stop) break;
        if (checkingOnly && !items[i].needsRecheck) continue;
        void progress(LiveOrderStep step) {
          if (current()) _emit(intent, items, step, i);
        }

        progress(LiveOrderStep.preparing);
        final item = await _execute(
          intent,
          items[i],
          current,
          checkingOnly,
          progress,
          () => activity.submitted(lease),
        );
        if (!current()) return;
        items[i] = item;
        if (item.submitted) _markStale();
        _emit(intent, items, LiveOrderStep.checking, i);
        if (item.failure != null ||
            item.result?.failure != null ||
            item.needsRecheck ||
            {'REJECTED', 'EXPIRED', 'EXPIRED_IN_MATCH', 'CANCELED'}.contains(item.result?.status)) {
          break;
        }
      }
      if (current()) _emit(intent, items, LiveOrderStep.idle, null);
    } finally {
      activity.finish(lease, unresolved: current() && state.needsRecheck);
    }
  }

  Future<ScaledOrderItem> _execute(
    ScaledOrderIntent intent,
    ScaledOrderItem previous,
    bool Function() current,
    bool checkingOnly,
    void Function(LiveOrderStep) progress,
    void Function() submitted,
  ) async {
    final repository = ref.read(liveOrderRepositoryProvider);
    var sent = previous.submitted;
    LiveOrderIntent? order = previous.order;
    try {
      LiveOrderResult result;
      if (checkingOnly) {
        if (order == null) throw const AccountReadFailure('accountDataInvalid');
        result = await repository.recheck(intent: order, isCurrent: current, onStep: progress);
      } else {
        final epoch = ref.read(symbolSettingsActivityProvider).epoch;
        final event = ref.read(accountChangeProvider);
        bool unchanged() =>
            current() &&
            !_stop &&
            ref.read(symbolSettingsActivityProvider).owner == SymbolSetting.scaled &&
            ref.read(symbolSettingsActivityProvider).epoch == epoch &&
            identical(ref.read(accountChangeProvider), event);
        final data = await repository.read(
          address: intent.address,
          symbol: intent.context.symbol,
          isCurrent: () => current() && !_stop,
          onStep: progress,
        );
        if (data.funds?.account.receivedAt.isAfter(_now) == true) {
          throw const AccountReadFailure('accountDataInvalid');
        }
        if (!unchanged() || !_fresh(data)) {
          throw const AccountReadFailure('liveOrderContextExpired');
        }
        if (data.fundsFailure case final failure?) throw failure;
        if (data.funds == null) throw const AccountReadFailure('liveOrderReadFunds');
        if (!sameScaledConfiguration(intent.context, data)) {
          throw const AccountReadFailure('scaledConfigurationChanged');
        }
        final invalid = data.validate(previous.draft);
        if (invalid != null) throw AccountReadFailure(invalid);
        order = LiveOrderIntent(
          context: data,
          draft: previous.draft,
          clientOrderId: previous.clientId,
          revision: _revision,
        );
        result = await repository.submit(
          intent: order,
          isCurrent: current,
          canSubmit: () => unchanged() && _fresh(data),
          onStep: (step) {
            if (step == LiveOrderStep.submitting) {
              sent = true;
              submitted();
            }
            progress(step);
          },
        );
      }
      if (!sent) throw const AccountReadFailure('accountDataInvalid');
      return ScaledOrderItem(
        index: previous.index,
        draft: previous.draft,
        clientId: previous.clientId,
        order: order,
        submitted: sent,
        result: result,
      );
    } catch (error) {
      return ScaledOrderItem(
        index: previous.index,
        draft: previous.draft,
        clientId: previous.clientId,
        order: order,
        submitted: sent,
        failure: error is AccountReadFailure
            ? error
            : const AccountReadFailure('accountReadFailed'),
      );
    }
  }

  void _markStale() {
    ref.read(liveOrderProvider.notifier).markStale();
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(openOrdersReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
    ref.read(positionAdlProvider.notifier).markStale();
  }

  void _emit(
    ScaledOrderIntent intent,
    List<ScaledOrderItem> items,
    LiveOrderStep step,
    int? index,
  ) {
    state = ScaledOrderState(
      intent: intent,
      items: items,
      step: step,
      currentIndex: index,
      stopRequested: _stop,
    );
  }
}
