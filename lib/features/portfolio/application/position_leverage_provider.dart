import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_position_leverage_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/position_leverage.dart';
import 'account_change_provider.dart';
import 'account_read_provider.dart';
import 'open_orders_provider.dart';
import 'position_risk_provider.dart';
import 'symbol_settings_activity.dart';

final positionLeverageClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final positionLeverageRepositoryProvider = Provider<PositionLeverageRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedPositionLeverageRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(positionLeverageClockProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});
final positionLeverageProvider =
    NotifierProvider<PositionLeverageController, PositionLeverageState>(
      PositionLeverageController.new,
    );

/// One operation across symbols. Navigating away never turns an unresolved
/// write into a new submit button; only an explicit signed query resolves it.
class PositionLeverageController extends Notifier<PositionLeverageState> {
  int _revision = 0, _staleRevision = 0;
  Timer? _expiry;
  DateTime get _now => ref.read(positionLeverageClockProvider)();
  @override
  PositionLeverageState build() {
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
        state = const PositionLeverageState();
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
    return const PositionLeverageState();
  }

  bool _fresh(PositionLeverageContext context) =>
      !state.stale &&
      _now.difference(context.receivedAt) >= Duration.zero &&
      _now.difference(context.receivedAt) < const Duration(seconds: 30);

  void markStale() {
    _staleRevision++;
    if (state.context == null || state.stale) return;
    state = PositionLeverageState(
      context: state.context,
      intent: state.intent,
      result: state.result,
      failure: state.failure,
      step: state.step,
      stale: true,
    );
  }

  Future<void> load(String symbol) async {
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
    final lease = activity.acquire(SymbolSetting.leverage);
    if (lease == null) return;
    final revision = ++_revision, staleRevision = _staleRevision;
    final previous = state.context?.symbol == symbol ? state.context : null;
    _expiry?.cancel();
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        ref.read(authProvider).identity?.id == identity?.id &&
        ref.read(authProvider).identity?.walletKind == identity?.walletKind &&
        ref.read(authProvider).identity?.walletAddress == address &&
        ref.read(authProvider).identity?.signingAvailable == true;
    state = PositionLeverageState(context: previous, step: LeverageStep.preparing, stale: true);
    try {
      final context = await ref
          .read(positionLeverageRepositoryProvider)
          .read(
            address: address,
            symbol: symbol,
            isCurrent: current,
            onStep: (step) {
              if (current()) {
                state = PositionLeverageState(context: previous, step: step, stale: true);
              }
            },
          );
      if (!current()) return;
      if (context.address.toLowerCase() != address.toLowerCase() ||
          context.symbol != symbol ||
          context.brackets.isEmpty ||
          context.maximum < 1 ||
          context.current < 1) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final age = _now.difference(context.receivedAt);
      state = PositionLeverageState(
        context: context,
        stale:
            staleRevision != _staleRevision ||
            age < Duration.zero ||
            age >= const Duration(seconds: 30),
      );
      if (!state.stale) _expiry = Timer(const Duration(seconds: 30) - age, markStale);
    } catch (error) {
      if (current()) {
        state = PositionLeverageState(context: previous, stale: true, failure: _failure(error));
      }
    } finally {
      activity.finish(lease, unresolved: false);
    }
  }

  LeverageIntent? prepare(String symbol, String input) {
    final context = state.context, auth = ref.read(authProvider);
    if (state.busy ||
        ref.read(symbolSettingsActivityProvider).blocks(SymbolSetting.leverage) ||
        state.needsRecheck ||
        context == null ||
        !_fresh(context) ||
        context.symbol != symbol ||
        auth.busy ||
        auth.identity?.signingAvailable != true ||
        auth.identity?.walletAddress?.toLowerCase() != context.address.toLowerCase()) {
      return null;
    }
    final target = context.target(input);
    return target == null
        ? null
        : LeverageIntent(context: context, target: target, revision: _revision);
  }

  Future<void> change(LeverageIntent intent) => _run(intent, checkingOnly: false);
  Future<void> recheck() async {
    final intent = state.intent;
    if (intent != null && state.needsRecheck) await _run(intent, checkingOnly: true);
  }

  Future<void> _run(LeverageIntent intent, {required bool checkingOnly}) async {
    final auth = ref.read(authProvider), identity = ref.read(authProvider).identity;
    if (state.busy ||
        intent.revision != _revision ||
        auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress?.toLowerCase() != intent.context.address.toLowerCase()) {
      return;
    }
    if (!checkingOnly &&
        (state.context != intent.context ||
            prepare(intent.context.symbol, '${intent.target}') == null)) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.leverage, checkingOnly: checkingOnly);
    if (lease == null) return;
    final revision = ++_revision;
    final active = LeverageIntent(
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
    state = PositionLeverageState(
      context: context,
      intent: active,
      step: LeverageStep.preparing,
      stale: state.stale,
    );
    var submitted = checkingOnly;
    try {
      void progress(LeverageStep step) {
        if (!current()) return;
        if (step == LeverageStep.submitting) {
          submitted = true;
          activity.submitted(lease);
          _invalidate();
        }
        state = PositionLeverageState(
          context: context,
          intent: active,
          step: step,
          stale: state.stale,
        );
      }

      final repository = ref.read(positionLeverageRepositoryProvider);
      final result = checkingOnly
          ? await repository.recheck(intent: active, isCurrent: current, onStep: progress)
          : await repository.change(
              intent: active,
              isCurrent: current,
              canSubmit: () => current() && _fresh(intent.context),
              onStep: progress,
            );
      if (!current()) return;
      if (result.observed != null && (result.observed! < 1 || result.observed! > 9999)) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      _invalidate();
      state = PositionLeverageState(context: context, intent: active, result: result, stale: true);
    } catch (error) {
      if (!current()) return;
      if (submitted) _invalidate();
      state = PositionLeverageState(
        context: context,
        intent: active,
        stale: true,
        result: submitted ? LeverageResult(failure: _failure(error)) : null,
        failure: submitted ? null : _failure(error),
      );
    } finally {
      activity.finish(lease, unresolved: current() && state.needsRecheck);
    }
  }

  void _invalidate() {
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
    ref.read(openOrdersReadProvider.notifier).markStale();
  }

  AccountReadFailure _failure(Object error) =>
      error is AccountReadFailure ? error : const AccountReadFailure('accountReadFailed');
}
