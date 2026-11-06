import '../../../core/network/network_providers.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/wallet_operation.dart';
import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_position_margin_repository.dart';
import '../data/position_margin_mapper.dart';
import '../domain/account_snapshot.dart';
import '../domain/position_margin_adjustment.dart';
import 'position_margin_storage_provider.dart';
import 'account_read_provider.dart';
import 'account_change_provider.dart';
import 'position_risk_provider.dart';
import 'symbol_settings_activity.dart';

final positionMarginClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final positionMarginReferenceProvider = Provider<String Function()>(
  (_) => () {
    final random = Random.secure();
    return 'vm_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  },
);
final positionMarginRepositoryProvider = Provider<PositionMarginRepository>((ref) {
  final service = AsterAccountService(
    client: ref.watch(backendHttpPoolProvider).lease(),
    decodeResponse: decodePositionMarginJson,
  );
  ref.onDispose(service.close);
  return SignedPositionMarginRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    ref.watch(positionMarginJournalProvider),
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(positionMarginClockProvider),
  );
});
final positionMarginProvider = NotifierProvider<PositionMarginController, PositionMarginState>(
  PositionMarginController.new,
);

class PositionMarginController extends Notifier<PositionMarginState> {
  int _revision = 0, _eventRevision = 0;
  Timer? _expiry;
  PositionMarginIntent? _prepared;
  DateTime get _now => ref.read(positionMarginClockProvider)();
  @override
  PositionMarginState build() {
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (a, b) {
        if (a == b) return;
        _revision++;
        _prepared = null;
        _expiry?.cancel();
        state = const PositionMarginState();
      },
    );
    ref.listen(accountChangeProvider, (a, b) {
      if (a != b) markStale();
    });
    ref.listen(symbolSettingsActivityProvider.select((s) => s.epoch), (a, b) {
      if (a != b) markStale();
    });
    ref.onDispose(() {
      _revision++;
      _expiry?.cancel();
    });
    return const PositionMarginState();
  }

  bool _fresh(PositionMarginContext c) =>
      !state.stale &&
      _now.difference(c.receivedAt) >= Duration.zero &&
      _now.difference(c.receivedAt) < const Duration(seconds: 30);
  void markStale() {
    _eventRevision++;
    _prepared = null;
    state = PositionMarginState(
      context: state.context,
      result: state.result,
      failure: state.failure,
      step: state.step,
      stale: true,
    );
  }

  void stop() {
    _revision++;
    _prepared = null;
    _expiry?.cancel();
    state = PositionMarginState(context: state.context, result: state.result, stale: true);
  }

  Future<void> load(String symbol, String side) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (state.busy ||
        auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress == null ||
        ref.read(currentPositionMarginsProvider).any((r) => !r.acknowledged)) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.positionMargin);
    if (lease == null) return;
    final revision = ++_revision, events = _eventRevision;
    _prepared = null;
    _expiry?.cancel();
    final old = state.context?.position.symbol == symbol && state.context?.position.side == side
        ? state.context
        : null;
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        !ref.read(authProvider).busy &&
        ref.read(authProvider).identity == identity;
    state = PositionMarginState(context: old, step: MarginAdjustmentStep.reading, stale: true);
    try {
      final c = await ref
          .read(positionMarginRepositoryProvider)
          .read(
            address: identity!.walletAddress!,
            symbol: symbol,
            side: side,
            isCurrent: current,
            onStep: (s) {
              if (current()) state = PositionMarginState(context: old, step: s, stale: true);
            },
          );
      if (!current()) return;
      if (c.account.address.toLowerCase() != identity.walletAddress!.toLowerCase() ||
          c.position.symbol != symbol ||
          c.position.side != side ||
          !c.position.isolated ||
          c.position.balanceOnly ||
          c.position.units == null) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final age = _now.difference(c.receivedAt);
      final stale =
          events != _eventRevision || age < Duration.zero || age >= const Duration(seconds: 30);
      state = PositionMarginState(context: c, stale: stale);
      if (!stale) _expiry = Timer(const Duration(seconds: 30) - age, markStale);
    } catch (e) {
      if (current()) {
        state = PositionMarginState(
          context: e is AccountReadFailure && e.key == 'marginAdjustClosed' ? null : old,
          stale: true,
          failure: _failure(e),
        );
      }
    } finally {
      activity.finish(lease, unresolved: false);
    }
  }

  PositionMarginIntent? prepare(MarginDirection direction, String input) {
    final c = state.context, auth = ref.read(authProvider);
    if (state.busy ||
        c == null ||
        !_fresh(c) ||
        auth.busy ||
        auth.identity?.signingAvailable != true ||
        auth.identity?.walletAddress?.toLowerCase() != c.account.address.toLowerCase() ||
        ref.read(symbolSettingsActivityProvider).blocks(SymbolSetting.positionMargin) ||
        ref.read(currentPositionMarginsProvider).any((r) => !r.acknowledged)) {
      return null;
    }
    final amount = c.amount(input, direction);
    if (amount == null) return null;
    if (_prepared?.context == c &&
        _prepared?.amount == amount &&
        _prepared?.direction == direction &&
        _prepared?.revision == _revision) {
      return _prepared;
    }
    return _prepared = PositionMarginIntent(
      context: c,
      direction: direction,
      amount: amount,
      reference: ref.read(positionMarginReferenceProvider)(),
      revision: _revision,
    );
  }

  Future<void> change(PositionMarginIntent intent) async {
    if (!identical(_prepared, intent) ||
        intent.revision != _revision ||
        prepare(intent.direction, intent.amount.toString()) != intent) {
      return;
    }
    await _run(intent: intent);
  }

  Future<void> check(WalletOperationRecord record) async {
    final saved = ref
        .read(currentPositionMarginsProvider)
        .where((r) => r.key == record.key)
        .singleOrNull;
    if (saved == null || saved.acknowledged) return;
    await _run(record: saved);
  }

  Future<void> _run({PositionMarginIntent? intent, WalletOperationRecord? record}) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (state.busy ||
        auth.busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress == null) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.positionMargin, checkingOnly: record != null);
    if (lease == null) return;
    final revision = ++_revision, events = _eventRevision, c = state.context;
    var checkEvents = events;
    _expiry?.cancel();
    _prepared = null;
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        !ref.read(authProvider).busy &&
        ref.read(authProvider).identity == identity;
    state = PositionMarginState(context: c, step: MarginAdjustmentStep.reading, stale: state.stale);
    try {
      void progress(MarginAdjustmentStep s) {
        if (!current()) return;
        if (s == MarginAdjustmentStep.submitting) {
          activity.submitted(lease);
          checkEvents = _eventRevision;
          _invalidate();
        }
        state = PositionMarginState(context: c, step: s, stale: state.stale);
      }

      final repo = ref.read(positionMarginRepositoryProvider);
      final result = record != null
          ? await repo.check(record: record, isCurrent: current, onStep: progress)
          : await repo.change(
              intent: intent!,
              isCurrent: current,
              canSubmit: () => current() && events == _eventRevision && _fresh(intent.context),
              onStep: progress,
            );
      if (!current()) return;
      _invalidate();
      if (result.verified && checkEvents == _eventRevision) {
        if (result.account case final account?) {
          ref.read(accountReadProvider.notifier).acceptSnapshot(account);
        }
        if (result.positions case final positions?) {
          ref.read(positionRiskProvider.notifier).acceptSnapshot(positions);
        }
      }
      final refreshed = result.context;
      final age = refreshed == null ? null : _now.difference(refreshed.receivedAt);
      final stale =
          refreshed == null ||
          age! < Duration.zero ||
          age >= const Duration(seconds: 30) ||
          checkEvents != _eventRevision;
      final closed =
          result.verified &&
          result.failure == null &&
          (result.position == null || result.position!.balanceOnly);
      state = PositionMarginState(
        context: closed ? null : refreshed ?? c,
        result: result,
        stale: stale,
      );
      if (!stale) {
        _expiry?.cancel();
        _expiry = Timer(const Duration(seconds: 30) - age, markStale);
      }
    } catch (e) {
      if (current()) state = PositionMarginState(context: c, failure: _failure(e), stale: true);
    } finally {
      activity.finish(lease, unresolved: false);
    }
  }

  void _invalidate() {
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
  }

  AccountReadFailure _failure(Object e) =>
      e is AccountReadFailure ? e : const AccountReadFailure('accountReadFailed');
}
