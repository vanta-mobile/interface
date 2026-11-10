import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_live_order_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import 'account_change_provider.dart';
import 'account_read_provider.dart';
import 'open_orders_provider.dart';
import 'position_risk_provider.dart';
import 'symbol_settings_activity.dart';
import 'order_recovery_provider.dart';

final liveOrderClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final liveOrderRepositoryProvider = Provider<LiveOrderRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedLiveOrderRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(liveOrderClockProvider),
    journal: ref.watch(orderRecoveryJournalProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});

final liveOrderProvider = NotifierProvider<LiveOrderController, LiveOrderState>(
  LiveOrderController.new,
);

class LiveOrderController extends Notifier<LiveOrderState> {
  int _revision = 0, _staleRevision = 0;
  Timer? _expiry;
  int? _readLease;
  final Random _random = Random.secure();
  DateTime get _now => ref.read(liveOrderClockProvider)();

  @override
  LiveOrderState build() {
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
        state = const LiveOrderState();
      },
    );
    ref.listen(symbolSettingsActivityProvider.select((s) => s.epoch), (before, after) {
      if (before != after) markStale();
    });
    ref.listen(accountChangeProvider, (before, after) {
      if (!identical(before, after)) markStale();
    });
    ref.onDispose(() {
      _revision++;
      _expiry?.cancel();
    });
    return const LiveOrderState();
  }

  bool _fresh(LiveOrderContext context) {
    final age = _now.difference(context.receivedAt);
    return !state.stale && age >= Duration.zero && age < const Duration(seconds: 30);
  }

  void markStale() {
    _staleRevision++;
    if (state.context == null || state.stale) return;
    state = LiveOrderState(
      context: state.context,
      intent: state.intent,
      result: state.result,
      failure: state.failure,
      step: state.step,
      stale: true,
    );
  }

  /// Opening an external wallet backgrounds this app as part of signing.
  /// Active prompts retain their 30-second deadline and identity checks.
  void onLifecycleChanged() {
    final activity = ref.read(symbolSettingsActivityProvider);
    // Capacity and quick-sizing reads hold the order lease while prompting the
    // wallet. Preserve their original deadline across the expected app switch.
    if (!state.busy && !(activity.busy && activity.owner == SymbolSetting.order)) markStale();
  }

  bool _identityCurrent(String id, String address, int revision) {
    if (!ref.mounted) return false;
    final identity = ref.read(authProvider).identity;
    return _revision == revision &&
        identity?.id == id &&
        identity?.walletAddress == address &&
        identity?.signingAvailable == true;
  }

  Future<void> load(String symbol, {bool includeFunds = true}) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    final address = identity?.walletAddress;
    if (state.busy ||
        state.needsRecheck ||
        auth.busy ||
        address == null ||
        identity?.signingAvailable != true) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order);
    if (lease == null) return;
    _readLease = lease;
    final revision = ++_revision, staleRevision = _staleRevision;
    final previous = state.context;
    _expiry?.cancel();
    bool current() => _identityCurrent(identity!.id, address, revision);
    state = LiveOrderState(context: previous, step: LiveOrderStep.preparing, stale: true);
    try {
      final context = await ref
          .read(liveOrderRepositoryProvider)
          .read(
            address: address,
            symbol: symbol,
            isCurrent: current,
            onStep: (step) {
              if (current()) state = LiveOrderState(context: previous, step: step, stale: true);
            },
            includeFunds: includeFunds,
          );
      if (!current()) return;
      if (context.address.toLowerCase() != address.toLowerCase() || context.symbol != symbol) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      if (context.funds?.account.receivedAt.isAfter(_now) == true) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final age = _now.difference(context.receivedAt);
      final stale =
          staleRevision != _staleRevision ||
          age < Duration.zero ||
          age >= const Duration(seconds: 30);
      state = LiveOrderState(context: context, stale: stale);
      if (!stale) _expiry = Timer(const Duration(seconds: 30) - age, markStale);
    } catch (error) {
      if (current()) {
        state = LiveOrderState(context: previous, failure: _failure(error), stale: true);
      }
    } finally {
      activity.finish(lease, unresolved: false);
      if (_readLease == lease) _readLease = null;
    }
  }

  /// Cancels only a context read; an attempted order must use its own recovery.
  void stopReading() {
    if (!state.busy || state.intent != null || _readLease == null) return;
    _revision++;
    _expiry?.cancel();
    ref.read(symbolSettingsActivityProvider.notifier).finish(_readLease!, unresolved: false);
    _readLease = null;
    state = LiveOrderState(context: state.context, stale: true);
  }

  LiveOrderIntent? prepare(
    String symbol,
    LiveOrderDraft draft, {
    LiveOrderContext? pricingContext,
  }) {
    final context = state.context, auth = ref.read(authProvider);
    if (context == null ||
        context.symbol != symbol ||
        !_fresh(context) ||
        state.busy ||
        state.needsRecheck ||
        auth.busy ||
        ref.read(symbolSettingsActivityProvider).owner != null ||
        ref.read(symbolSettingsActivityProvider).recoveryBlocked ||
        auth.identity?.signingAvailable != true ||
        auth.identity?.walletAddress?.toLowerCase() != context.address.toLowerCase() ||
        pricingContext != null && !context.sameAccountAnchor(pricingContext) ||
        (pricingContext ?? context).validate(draft) != null) {
      return null;
    }
    final id =
        'vanta-${_now.microsecondsSinceEpoch.toRadixString(36)}-'
        '${_random.nextInt(1 << 32).toRadixString(36)}';
    return LiveOrderIntent(
      context: context,
      draft: draft,
      clientOrderId: id,
      revision: _revision,
      pricingContext: pricingContext,
    );
  }

  Future<void> submit(LiveOrderIntent intent, {bool Function()? submitGuard}) =>
      _run(intent, checkingOnly: false, submitGuard: submitGuard);
  Future<void> recheck() async {
    final intent = state.intent;
    if (intent != null && (state.needsRecheck || state.result?.strategy != null)) {
      await _run(intent, checkingOnly: true);
    }
  }

  Future<void> _run(
    LiveOrderIntent intent, {
    required bool checkingOnly,
    bool Function()? submitGuard,
  }) async {
    bool allowed() {
      try {
        return submitGuard?.call() ?? true;
      } catch (_) {
        return false;
      }
    }

    final auth = ref.read(authProvider), identity = auth.identity;
    if (state.busy ||
        intent.revision != _revision ||
        auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress?.toLowerCase() != intent.context.address.toLowerCase()) {
      return;
    }
    if (!checkingOnly &&
        (!allowed() ||
            state.context != intent.context ||
            intent.executionContext.validate(intent.draft) != null ||
            !_fresh(intent.context))) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order, checkingOnly: checkingOnly);
    if (lease == null) return;
    final revision = ++_revision;
    final active = LiveOrderIntent(
      context: intent.context,
      draft: intent.draft,
      clientOrderId: intent.clientOrderId,
      revision: revision,
      pricingContext: intent.pricingContext,
    );
    bool current() => _identityCurrent(identity!.id, active.context.address, revision);
    final epoch = ref.read(symbolSettingsActivityProvider).epoch;
    final staleRevision = _staleRevision;
    bool canSubmit() =>
        current() &&
        allowed() &&
        !state.stale &&
        staleRevision == _staleRevision &&
        ref.read(symbolSettingsActivityProvider).epoch == epoch &&
        ref.read(symbolSettingsActivityProvider).owner == SymbolSetting.order &&
        _now.difference(active.context.receivedAt) >= Duration.zero &&
        _now.difference(active.context.receivedAt) < const Duration(seconds: 30);
    state = LiveOrderState(context: intent.context, intent: active, step: LiveOrderStep.preparing);
    var unresolved = false, submitted = false;
    try {
      final repository = ref.read(liveOrderRepositoryProvider);
      final result = checkingOnly
          ? await repository.recheck(
              intent: active,
              isCurrent: current,
              onStep: (step) {
                if (current()) {
                  state = LiveOrderState(
                    context: intent.context,
                    intent: active,
                    step: step,
                    stale: true,
                  );
                }
              },
            )
          : await repository.submit(
              intent: active,
              isCurrent: current,
              canSubmit: canSubmit,
              onStep: (step) {
                if (current()) {
                  if (step == LiveOrderStep.submitting) {
                    submitted = true;
                    activity.submitted(lease);
                  }
                  state = LiveOrderState(
                    context: intent.context,
                    intent: active,
                    step: step,
                    stale:
                        state.stale ||
                        step == LiveOrderStep.checkSigning ||
                        step == LiveOrderStep.checking,
                  );
                }
              },
            );
      if (!current()) return;
      unresolved = result.needsRecheck;
      _markAccountOutputsStale();
      state = LiveOrderState(context: intent.context, intent: active, result: result, stale: true);
    } catch (error) {
      if (current()) {
        unresolved = submitted || checkingOnly;
        if (unresolved) _markAccountOutputsStale();
        state = unresolved
            ? LiveOrderState(
                context: intent.context,
                intent: active,
                stale: true,
                result: LiveOrderResult(failure: _failure(error)),
              )
            : LiveOrderState(context: intent.context, stale: true, failure: _failure(error));
      }
    } finally {
      activity.finish(lease, unresolved: unresolved);
    }
  }

  void _markAccountOutputsStale() {
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
    ref.read(openOrdersReadProvider.notifier).markStale();
  }

  AccountReadFailure _failure(Object error) =>
      error is AccountReadFailure ? error : const AccountReadFailure('accountReadFailed');
}
