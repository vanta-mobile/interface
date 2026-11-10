import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_futures_position_mode_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/futures_position_mode.dart';
import 'account_change_provider.dart';
import 'account_read_provider.dart';
import 'open_orders_provider.dart';
import 'position_adl_provider.dart';
import 'position_risk_provider.dart';
import 'symbol_settings_activity.dart';

final futuresPositionModeClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final futuresPositionModeRepositoryProvider = Provider<FuturesPositionModeRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedFuturesPositionModeRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(futuresPositionModeClockProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});
final futuresPositionModeProvider =
    NotifierProvider<FuturesPositionModeController, FuturesPositionModeState>(
      FuturesPositionModeController.new,
    );

/// One account-wide position-mode operation. Navigating away never turns an unresolved
/// write into a new submit button; only an explicit signed query resolves it.
class FuturesPositionModeController extends Notifier<FuturesPositionModeState> {
  int _revision = 0, _staleRevision = 0;
  Timer? _expiry;
  DateTime get _now => ref.read(futuresPositionModeClockProvider)();
  @override
  FuturesPositionModeState build() {
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
        state = const FuturesPositionModeState();
      },
    );
    ref.listen(accountChangeProvider.select((s) => s.lastEventAt), (before, after) {
      if (before != after) markStale();
    });
    ref.listen(symbolSettingsActivityProvider.select((s) => s.epoch), (before, after) {
      if (before != after) markStale();
    });
    ref.onDispose(() {
      _revision++;
      _expiry?.cancel();
    });
    return const FuturesPositionModeState();
  }

  bool _fresh(FuturesPositionModeContext context) =>
      !state.stale &&
      _now.difference(context.receivedAt) >= Duration.zero &&
      _now.difference(context.receivedAt) < const Duration(seconds: 30);

  void markStale() {
    _staleRevision++;
    if (state.context == null || state.stale) return;
    state = FuturesPositionModeState(
      context: state.context,
      intent: state.intent,
      result: state.result,
      failure: state.failure,
      step: state.step,
      stale: true,
    );
  }

  Future<void> load() async {
    final auth = ref.read(authProvider), identity = ref.read(authProvider).identity;
    final address = identity?.walletAddress;
    if (state.busy ||
        state.needsRecheck ||
        auth.busy ||
        address == null ||
        identity?.signingAvailable != true) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.positionMode);
    if (lease == null) return;
    final revision = ++_revision, staleRevision = _staleRevision;
    final previous = state.context;
    _expiry?.cancel();
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        ref.read(authProvider).identity?.id == identity?.id &&
        ref.read(authProvider).identity?.walletKind == identity?.walletKind &&
        ref.read(authProvider).identity?.walletAddress == address &&
        ref.read(authProvider).identity?.signingAvailable == true;
    state = FuturesPositionModeState(
      context: previous,
      step: PositionModeStep.preparing,
      stale: true,
    );
    try {
      final context = await ref
          .read(futuresPositionModeRepositoryProvider)
          .read(
            address: address,
            isCurrent: current,
            onStep: (step) {
              if (current()) {
                state = FuturesPositionModeState(context: previous, step: step, stale: true);
              }
            },
          );
      if (!current()) return;
      if (context.address.toLowerCase() != address.toLowerCase() || context.openOrderCount < 0) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final age = _now.difference(context.receivedAt);
      state = FuturesPositionModeState(
        context: context,
        stale:
            staleRevision != _staleRevision ||
            age < Duration.zero ||
            age >= const Duration(seconds: 30),
      );
      if (!state.stale) _expiry = Timer(const Duration(seconds: 30) - age, markStale);
    } catch (error) {
      if (current()) {
        state = FuturesPositionModeState(context: previous, stale: true, failure: _failure(error));
      }
    } finally {
      activity.finish(lease, unresolved: false);
    }
  }

  PositionModeIntent? prepare(FuturesPositionMode target) {
    final context = state.context, auth = ref.read(authProvider);
    if (state.busy ||
        ref.read(symbolSettingsActivityProvider).blocks(SymbolSetting.positionMode) ||
        state.needsRecheck ||
        context == null ||
        !_fresh(context) ||
        context.blocked ||
        context.current == target ||
        auth.busy ||
        auth.identity?.signingAvailable != true ||
        auth.identity?.walletAddress?.toLowerCase() != context.address.toLowerCase()) {
      return null;
    }
    return PositionModeIntent(context: context, target: target, revision: _revision);
  }

  Future<void> change(PositionModeIntent intent) => _run(intent, checkingOnly: false);
  Future<void> recheck() async {
    final intent = state.intent;
    if (intent != null && state.needsRecheck) await _run(intent, checkingOnly: true);
  }

  Future<void> _run(PositionModeIntent intent, {required bool checkingOnly}) async {
    final auth = ref.read(authProvider), identity = ref.read(authProvider).identity;
    if (state.busy ||
        intent.revision != _revision ||
        auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress?.toLowerCase() != intent.context.address.toLowerCase()) {
      return;
    }
    if (!checkingOnly && (state.context != intent.context || prepare(intent.target) == null)) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.positionMode, checkingOnly: checkingOnly);
    if (lease == null) return;
    final revision = ++_revision;
    final active = PositionModeIntent(
      context: intent.context,
      target: intent.target,
      revision: revision,
    );
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        ref.read(authProvider).identity?.id == identity?.id &&
        ref.read(authProvider).identity?.walletKind == identity?.walletKind &&
        ref.read(authProvider).identity?.walletAddress == identity?.walletAddress &&
        ref.read(authProvider).identity?.signingAvailable == true;
    final context = state.context;
    state = FuturesPositionModeState(
      context: context,
      intent: active,
      step: PositionModeStep.preparing,
      stale: state.stale,
    );
    var submitted = checkingOnly;
    try {
      void progress(PositionModeStep step) {
        if (!current()) return;
        if (step == PositionModeStep.submitting) {
          submitted = true;
          activity.submitted(lease);
          _invalidate();
        }
        state = FuturesPositionModeState(
          context: context,
          intent: active,
          step: step,
          stale: state.stale,
        );
      }

      final repository = ref.read(futuresPositionModeRepositoryProvider);
      final result = checkingOnly
          ? await repository.recheck(intent: active, isCurrent: current, onStep: progress)
          : await repository.change(
              intent: active,
              isCurrent: current,
              canSubmit: () => current() && _fresh(intent.context),
              onStep: progress,
            );
      if (!current()) return;
      _invalidate();
      state = FuturesPositionModeState(
        context: context,
        intent: active,
        result: result,
        stale: true,
      );
    } catch (error) {
      if (!current()) return;
      if (submitted) _invalidate();
      state = FuturesPositionModeState(
        context: context,
        intent: active,
        stale: true,
        result: submitted ? PositionModeResult(failure: _failure(error)) : null,
        failure: submitted ? null : _failure(error),
      );
    } finally {
      activity.finish(lease, unresolved: current() && state.needsRecheck);
    }
  }

  void _invalidate() {
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
    ref.read(positionAdlProvider.notifier).markStale();
    ref.read(openOrdersReadProvider.notifier).markStale();
  }

  AccountReadFailure _failure(Object error) =>
      error is AccountReadFailure ? error : const AccountReadFailure('accountReadFailed');
}
