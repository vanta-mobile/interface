import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../funding/application/withdraw_info_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_rebalance_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/asset_rebalance.dart';
import 'account_change_provider.dart';
import 'account_read_provider.dart';
import 'futures_asset_mode_provider.dart';
import 'position_risk_provider.dart';
import 'rebalance_storage_provider.dart';
import 'symbol_settings_activity.dart';

final rebalanceClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final rebalanceRepositoryProvider = Provider<RebalanceRepository>((ref) {
  final service = AsterAccountService();
  ref.onDispose(service.close);
  return SignedRebalanceRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(rebalanceClockProvider),
  );
});
final rebalanceProvider = NotifierProvider<RebalanceController, RebalanceState>(
  RebalanceController.new,
);

class RebalanceController extends Notifier<RebalanceState> {
  int _generation = 0, _staleEpoch = 0;
  bool _working = false;
  Timer? _expiry;
  DateTime get _now => ref.read(rebalanceClockProvider)().toUtc();
  @override
  RebalanceState build() {
    ref.watch(rebalanceRepositoryProvider);
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
          _expiry?.cancel();
          state = const RebalanceState();
        }
      },
    );
    ref.listen(accountChangeProvider, (a, b) {
      if (!identical(a, b)) markStale();
    });
    ref.listen(symbolSettingsActivityProvider.select((s) => s.epoch), (a, b) {
      if (a != b) markStale();
    });
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    return const RebalanceState();
  }

  bool _current(AuthIdentity identity, int generation) =>
      ref.mounted &&
      _generation == generation &&
      ref.read(authProvider).identity?.id == identity.id &&
      ref.read(authProvider).identity?.walletAddress?.toLowerCase() ==
          identity.walletAddress?.toLowerCase() &&
      ref.read(authProvider).identity?.walletKind == identity.walletKind &&
      ref.read(authProvider).identity?.signingAvailable == true &&
      !ref.read(authProvider).busy;
  String _failure(Object error) => switch (error) {
    AccountReadFailure(:final key) || AuthFailure(:final key) => key,
    _ => 'accountReadFailed',
  };
  bool _fresh(RebalanceContext context) {
    final age = _now.difference(context.receivedAt);
    return age >= Duration.zero &&
        age < const Duration(seconds: 30) &&
        !context.account.receivedAt.isBefore(context.receivedAt) &&
        !context.account.receivedAt.isAfter(_now);
  }

  void markStale() {
    _staleEpoch++;
    if (!ref.mounted) return;
    state = RebalanceState(
      context: state.context,
      reply: state.reply,
      failure: state.failure,
      step: state.busy ? state.step : RebalanceStep.idle,
    );
  }

  void stop() {
    _generation++;
    _expiry?.cancel();
    if (ref.mounted) state = RebalanceState(context: state.context);
  }

  void _validate(RebalanceContext c, String address) {
    if (c.address.toLowerCase() != address.toLowerCase() || !_fresh(c)) {
      throw const AccountReadFailure('rebalanceChanged');
    }
  }

  Future<void> load() async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity?.walletAddress == null) return;
    if (!identity!.signingAvailable) {
      state = const RebalanceState(failure: 'authWalletReconnect');
      return;
    }
    final generation = ++_generation, epoch = _staleEpoch;
    bool current() => _current(identity, generation);
    final previous = state.context,
        repository = ref.read(rebalanceRepositoryProvider),
        journal = ref.read(rebalanceJournalProvider);
    _working = true;
    _expiry?.cancel();
    state = RebalanceState(context: previous, step: RebalanceStep.reading);
    try {
      final c = await repository.read(address: identity.walletAddress!, isCurrent: current);
      if (!current()) return;
      _validate(c, identity.walletAddress!);
      final pending = journal.snapshot.records
          .where((r) => r.address.toLowerCase() == c.address.toLowerCase())
          .singleOrNull;
      if (pending?.reply != null && journal.snapshot.ready && !journal.snapshot.failure) {
        await journal.complete(pending!.key);
        final activity = ref.read(symbolSettingsActivityProvider.notifier);
        final lease = activity.acquire(SymbolSetting.rebalance, checkingOnly: true);
        if (lease != null) activity.finish(lease, unresolved: false);
      }
      if (!current()) return;
      state = RebalanceState(context: c, reply: pending?.reply, stale: epoch != _staleEpoch);
      if (!state.stale) {
        _expiry = Timer(const Duration(seconds: 30) - _now.difference(c.receivedAt), markStale);
      }
    } catch (error) {
      if (current()) state = RebalanceState(context: previous, failure: _failure(error));
    } finally {
      _working = false;
    }
  }

  RebalanceReview? prepare() {
    final c = state.context,
        auth = ref.read(authProvider),
        storage = ref.read(rebalanceStorageProvider);
    if (_working ||
        state.busy ||
        auth.busy ||
        auth.identity?.signingAvailable != true ||
        c == null ||
        state.stale ||
        !_fresh(c) ||
        !c.needed ||
        !storage.ready ||
        storage.failure ||
        ref.read(pendingRebalancesProvider).isNotEmpty ||
        ref.read(symbolSettingsActivityProvider).blocks(SymbolSetting.rebalance)) {
      return null;
    }
    final review = RebalanceReview(c);
    state = RebalanceState(context: c, review: review, step: RebalanceStep.reviewing, stale: false);
    return review;
  }

  void cancel(RebalanceReview review) {
    if (!_working && identical(state.review, review)) {
      state = RebalanceState(context: state.context, stale: state.stale);
    }
  }

  void _invalidate() {
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
    ref.read(futuresAssetModeProvider.notifier).markStale();
    ref.read(withdrawInfoProvider.notifier).markStale();
  }

  Future<void> confirm(RebalanceReview review) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working ||
        !identical(state.review, review) ||
        identity?.walletAddress == null ||
        auth.busy ||
        identity?.signingAvailable != true ||
        state.stale ||
        !_fresh(review.context)) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier),
        lease = activity.acquire(SymbolSetting.rebalance);
    if (lease == null) return;
    final generation = _generation, epoch = _staleEpoch;
    bool current() => _current(identity!, generation);
    bool canSubmit() => current() && epoch == _staleEpoch && _fresh(review.context);
    final journal = ref.read(rebalanceJournalProvider),
        repository = ref.read(rebalanceRepositoryProvider),
        clock = ref.read(rebalanceClockProvider);
    RebalanceRecord? record;
    var prepared = false, dispatched = false;
    _working = true;
    _expiry?.cancel();
    state = RebalanceState(context: review.context, step: RebalanceStep.signing);
    try {
      final reply = await repository.submit(
        context: review.context,
        canSubmit: canSubmit,
        beforeSend: (nonce) async {
          if (!canSubmit()) throw const AccountReadFailure('rebalanceChanged');
          record = RebalanceRecord(
            address: review.context.address,
            nonce: nonce,
            preparedAt: clock().toUtc(),
            previousUsdt: review.context.usdt!,
          );
          await journal.prepare(record!);
          prepared = true;
          if (!canSubmit()) throw const AccountReadFailure('rebalanceChanged');
        },
        onDispatch: () {
          if (!prepared || !canSubmit()) throw const AccountReadFailure('rebalanceChanged');
          dispatched = true;
          activity.submitted(lease);
          _invalidate();
          if (current()) {
            state = RebalanceState(context: review.context, step: RebalanceStep.submitting);
          }
        },
      );
      if (!dispatched || record == null) throw const AccountReadFailure('accountDataInvalid');
      // Never drop a server response on account/route/provider invalidation.
      await journal.report(record!.key, reply);
      if (!current()) return;
      state = RebalanceState(context: review.context, reply: reply, step: RebalanceStep.checking);
      final checkedEpoch = _staleEpoch;
      final checked = await repository.read(address: review.context.address, isCurrent: current);
      if (!current()) return;
      _validate(checked, review.context.address);
      await journal.complete(record!.key);
      if (current()) {
        _invalidate();
        state = RebalanceState(context: checked, reply: reply, stale: checkedEpoch != _staleEpoch);
        if (!state.stale) {
          _expiry = Timer(
            const Duration(seconds: 30) - _now.difference(checked.receivedAt),
            markStale,
          );
        }
      }
    } catch (error) {
      var failure = _failure(error);
      if (prepared && !dispatched && record != null) {
        try {
          await journal.complete(record!.key);
        } catch (_) {
          failure = 'rebalanceStorage';
        }
      }
      if (current()) {
        state = RebalanceState(context: state.context, reply: state.reply, failure: failure);
      }
    } finally {
      _working = false;
      activity.finish(
        lease,
        unresolved:
            current() &&
            journal.snapshot.records.any(
              (r) => r.address.toLowerCase() == review.context.address.toLowerCase(),
            ),
      );
    }
  }
}
