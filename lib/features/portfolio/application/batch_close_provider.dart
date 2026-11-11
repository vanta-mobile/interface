import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../domain/batch_close.dart';
import '../domain/live_order.dart';
import '../domain/position_margin_mode.dart';
import '../domain/position_risk.dart';
import 'account_change_provider.dart';
import 'account_read_provider.dart';
import 'live_order_provider.dart';
import 'open_orders_provider.dart';
import 'position_adl_provider.dart';
import 'position_risk_provider.dart';
import 'symbol_settings_activity.dart';

final batchCloseProvider = NotifierProvider<BatchCloseController, BatchCloseState>(
  BatchCloseController.new,
);

class BatchCloseController extends Notifier<BatchCloseState> {
  int _revision = 0;
  bool _stop = false;
  final _random = Random.secure();
  DateTime get _now => ref.read(liveOrderClockProvider)();

  @override
  BatchCloseState build() {
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
        state = BatchCloseState();
      },
    );
    ref.onDispose(() => _revision++);
    return BatchCloseState();
  }

  bool _fresh(DateTime time) {
    final age = _now.difference(time);
    return age >= Duration.zero && age < const Duration(seconds: 30);
  }

  BatchCloseIntent? prepare({String? symbol}) {
    final auth = ref.read(authProvider), risk = ref.read(positionRiskProvider);
    final snapshot = risk.account;
    if (state.busy ||
        auth.busy ||
        risk.busy ||
        risk.stale ||
        risk.failure != null ||
        snapshot == null ||
        !_fresh(snapshot.receivedAt) ||
        auth.identity?.signingAvailable != true ||
        auth.identity?.walletAddress?.toLowerCase() != snapshot.address.toLowerCase() ||
        ref.read(symbolSettingsActivityProvider).owner != null) {
      return null;
    }
    final positions =
        snapshot.positions
            .where((p) => !p.balanceOnly && (symbol == null || p.symbol == symbol))
            .toList()
          ..sort((a, b) => '${a.symbol}:${a.side}'.compareTo('${b.symbol}:${b.side}'));
    if (positions.isEmpty) return null;
    return BatchCloseIntent(
      snapshot: snapshot,
      symbol: symbol,
      revision: _revision,
      epoch: ref.read(symbolSettingsActivityProvider).epoch,
      targets: [
        for (final p in positions)
          BatchCloseTarget(
            position: p,
            clientOrderId:
                'vanta-${_now.microsecondsSinceEpoch.toRadixString(36)}-'
                '${_random.nextInt(1 << 32).toRadixString(36)}',
          ),
      ],
    );
  }

  Future<void> submit(BatchCloseIntent intent) => _run(intent, checkingOnly: false);
  Future<void> recheck() async {
    final intent = state.intent;
    if (intent != null && state.needsRecheck) await _run(intent, checkingOnly: true);
  }

  void stop() {
    if (!state.busy) return;
    _stop = true;
    _emit(state.intent!, state.items, state.step, state.currentKey, state.remainingAfter);
  }

  Future<void> _run(BatchCloseIntent intent, {required bool checkingOnly}) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (state.busy ||
        auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress?.toLowerCase() != intent.address.toLowerCase()) {
      return;
    }
    if (!checkingOnly) {
      final risk = ref.read(positionRiskProvider);
      if (intent.revision != _revision ||
          risk.busy ||
          risk.stale ||
          risk.failure != null ||
          !identical(risk.account, intent.snapshot) ||
          !_fresh(intent.snapshot.receivedAt) ||
          !intent.validTargets ||
          ref.read(symbolSettingsActivityProvider).epoch != intent.epoch) {
        return;
      }
    } else if (!identical(state.intent, intent)) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.batchClose, checkingOnly: checkingOnly);
    if (lease == null) return;
    final revision = ++_revision;
    bool current() =>
        ref.mounted &&
        _revision == revision &&
        ref.read(authProvider).identity?.id == identity?.id &&
        ref.read(authProvider).identity?.walletAddress?.toLowerCase() ==
            intent.address.toLowerCase() &&
        ref.read(authProvider).identity?.signingAvailable == true;
    final items = checkingOnly
        ? {...state.items}
        : {for (final target in intent.targets) target.key: BatchCloseItem(target: target)};
    final targets = checkingOnly
        ? items.values.where((i) => i.needsRecheck).map((i) => i.target).toList()
        : intent.targets;
    _stop = false;
    _emit(intent, items, LiveOrderStep.preparing, targets.firstOrNull?.key, null);
    try {
      for (final target in targets) {
        if (!current()) return;
        if (_stop) break;
        _emit(intent, items, LiveOrderStep.preparing, target.key, null);
        final item = await _execute(target, items[target.key]!, current, checkingOnly, (step) {
          if (current()) _emit(intent, items, step, target.key, null);
        }, () => activity.submitted(lease));
        if (!current()) return;
        items[target.key] = item;
        if (item.submitted) _markOutputsStale();
        _emit(intent, items, LiveOrderStep.checking, target.key, null);
        if (item.failure != null || item.result?.failure != null || item.needsRecheck) break;
      }
      if (!current()) return;
      final cutoff = items.values.any((i) => i.submitted) ? _now : null;
      _emit(intent, items, LiveOrderStep.checkingPosition, null, cutoff);
      // The explicit confirmation includes one final signed position read.
      // A refused/unknown order check stops prompts; recovery never resumes POSTs.
      if (!checkingOnly &&
          cutoff != null &&
          items.values.every(
            (i) => !i.needsRecheck && i.failure == null && i.result?.failure == null,
          )) {
        await ref.read(positionRiskProvider.notifier).refresh();
      }
      if (current()) _emit(intent, items, LiveOrderStep.idle, null, cutoff);
    } finally {
      activity.finish(lease, unresolved: current() && state.needsRecheck);
    }
  }

  Future<BatchCloseItem> _execute(
    BatchCloseTarget target,
    BatchCloseItem previous,
    bool Function() current,
    bool checkingOnly,
    void Function(LiveOrderStep) progress,
    void Function() submitted,
  ) async {
    final repository = ref.read(liveOrderRepositoryProvider);
    LiveOrderIntent? order = previous.order;
    var sent = previous.submitted;
    try {
      LiveOrderResult result;
      if (checkingOnly) {
        if (order == null) throw const AccountReadFailure('accountDataInvalid');
        result = await repository.recheck(intent: order, isCurrent: current, onStep: progress);
      } else {
        final epoch = ref.read(symbolSettingsActivityProvider).epoch;
        final event = ref.read(accountChangeProvider).lastEventAt;
        bool unchanged() =>
            current() &&
            !_stop &&
            ref.read(symbolSettingsActivityProvider).epoch == epoch &&
            ref.read(symbolSettingsActivityProvider).owner == SymbolSetting.batchClose &&
            ref.read(accountChangeProvider).lastEventAt == event;
        final context = await repository.read(
          address: state.intent!.address,
          symbol: target.position.symbol,
          isCurrent: current,
          onStep: progress,
          includeFunds: false,
        );
        if (!unchanged() || !_fresh(context.receivedAt)) {
          throw const AccountReadFailure('liveOrderContextExpired');
        }
        final position = target.position, checked = context.positions[position.side];
        if (context.address.toLowerCase() != state.intent!.address.toLowerCase() ||
            context.symbol != position.symbol ||
            checked == null ||
            checked.quantity != position.quantity ||
            checked.entryPrice != position.entryPrice ||
            position.leverage != null && context.leverage != position.leverage ||
            (context.marginMode == PositionMarginMode.isolated) != position.isolated ||
            position.units != null && position.units!.base != context.rules.baseAsset) {
          throw const AccountReadFailure('liveClosePositionChanged');
        }
        final draft = LiveOrderDraft(
          buy: !checked.long,
          market: true,
          quantity: position.quantity.abs().toString(),
          price: '',
          closingSide: position.side,
        );
        final invalid = context.validate(draft);
        if (invalid != null) throw AccountReadFailure(invalid);
        order = LiveOrderIntent(
          context: context,
          draft: draft,
          clientOrderId: target.clientOrderId,
          revision: _revision,
        );
        result = await repository.submit(
          intent: order,
          isCurrent: current,
          canSubmit: () => unchanged() && _fresh(context.receivedAt),
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
      return BatchCloseItem(target: target, order: order, submitted: sent, result: result);
    } catch (error) {
      return BatchCloseItem(
        target: target,
        order: order,
        submitted: sent,
        failure: error is AccountReadFailure
            ? error
            : const AccountReadFailure('accountReadFailed'),
      );
    }
  }

  void _markOutputsStale() {
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(openOrdersReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
    ref.read(positionAdlProvider.notifier).markStale();
  }

  void _emit(
    BatchCloseIntent intent,
    Map<String, BatchCloseItem> items,
    LiveOrderStep step,
    String? key,
    DateTime? cutoff,
  ) {
    state = BatchCloseState(
      intent: intent,
      items: items,
      step: step,
      currentKey: key,
      stopRequested: _stop,
      remainingAfter: cutoff,
    );
  }
}
