import '../../../core/errors/api_error_details.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/application/account_change_provider.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/application/spot_account_provider.dart';
import '../../portfolio/application/spot_account_change_provider.dart';
import '../../portfolio/application/position_risk_provider.dart';
import '../../portfolio/application/futures_asset_mode_provider.dart';
import '../../portfolio/application/symbol_settings_activity.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../data/signed_internal_transfer_repository.dart';
import '../domain/internal_transfer.dart';
import 'internal_transfer_storage_provider.dart';
import 'withdraw_info_provider.dart';

final internalTransferClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final internalTransferRepositoryProvider = Provider<InternalTransferRepository>((ref) {
  final futures = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease()),
      spot = AsterSpotService(client: ref.watch(backendHttpPoolProvider).lease()),
      catalog = InternalTransferCatalogService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(() {
    futures.close();
    spot.close();
    catalog.close();
  });
  return SignedInternalTransferRepository(
    futures,
    spot,
    catalog,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(internalTransferClockProvider),
  );
});
final internalTransferProvider =
    NotifierProvider<InternalTransferController, InternalTransferState>(
      InternalTransferController.new,
    );

class InternalTransferController extends Notifier<InternalTransferState> {
  int _generation = 0, _epoch = 0;
  bool _working = false;
  Timer? _expiry;
  final _random = Random.secure();
  DateTime get _now => ref.read(internalTransferClockProvider)().toUtc();
  @override
  InternalTransferState build() {
    ref.watch(internalTransferRepositoryProvider);
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
          state = const InternalTransferState();
        }
      },
    );
    ref.listen(accountChangeProvider, (a, b) {
      if (!identical(a, b)) markStale();
    });
    ref.listen(spotAccountChangeProvider, (a, b) {
      if (!identical(a, b)) markStale();
    });
    ref.listen(symbolSettingsActivityProvider.select((s) => s.epoch), (a, b) {
      if (a != b) markStale();
    });
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    return const InternalTransferState();
  }

  void _publish({
    InternalTransferContext? context,
    InternalTransferReview? review,
    InternalTransferRecord? record,
    String? failure,
    ApiErrorDetails? errorDetails,
    InternalTransferStep step = InternalTransferStep.idle,
    bool stale = true,
    String? amount,
    String? asset,
    InternalTransferDirection? direction,
  }) {
    state = InternalTransferState(
      asset: asset ?? state.asset,
      direction: direction ?? state.direction,
      amount: amount ?? state.amount,
      context: context,
      review: review,
      record: record ?? state.record,
      failure: failure,
      errorDetails: errorDetails,
      step: step,
      stale: stale,
    );
  }

  bool _current(AuthIdentity i, int generation) =>
      ref.mounted &&
      _generation == generation &&
      ref.read(authProvider).identity?.id == i.id &&
      ref.read(authProvider).identity?.walletAddress?.toLowerCase() ==
          i.walletAddress?.toLowerCase() &&
      ref.read(authProvider).identity?.walletKind == i.walletKind &&
      ref.read(authProvider).identity?.signingAvailable == true &&
      !ref.read(authProvider).busy;
  bool _fresh(InternalTransferContext c) {
    final age = _now.difference(c.receivedAt);
    return age >= Duration.zero &&
        age < const Duration(seconds: 30) &&
        !c.spot.receivedAt.isAfter(_now) &&
        !c.futures.receivedAt.isAfter(_now) &&
        !c.spot.receivedAt.isBefore(c.receivedAt) &&
        !c.futures.receivedAt.isBefore(c.receivedAt);
  }

  String _failure(Object error) => switch (error) {
    AccountReadFailure(:final key) || AuthFailure(:final key) => key,
    _ => 'accountReadFailed',
  };
  void markStale() {
    _epoch++;
    if (ref.mounted) {
      _publish(
        context: state.context,
        step: state.busy ? state.step : InternalTransferStep.idle,
        failure: state.failure,
      );
    }
  }

  void stop() {
    _generation++;
    _expiry?.cancel();
    if (ref.mounted) _publish(context: state.context);
  }

  void setAmount(String amount) {
    if (_working || state.busy) return;
    _publish(context: state.context, amount: amount, stale: state.stale);
  }

  void max() {
    if (state.stale || state.context == null || !_fresh(state.context!)) return;
    if (state.context?.maxInput case final value?) setAmount(value.toString());
  }

  Future<void> select({String? asset, InternalTransferDirection? direction}) async {
    if (_working || state.busy) return;
    _generation++;
    _expiry?.cancel();
    _publish(context: state.context, asset: asset, direction: direction, amount: '');
    await load();
  }

  void _validate(InternalTransferContext c, String address) {
    if (c.address.toLowerCase() != address.toLowerCase() ||
        c.spot.address.toLowerCase() != address.toLowerCase() ||
        c.futures.address.toLowerCase() != address.toLowerCase() ||
        c.assetName != state.asset ||
        c.direction != state.direction ||
        !_fresh(c)) {
      throw const AccountReadFailure('internalTransferChanged');
    }
  }

  void _arm(InternalTransferContext c) {
    _expiry?.cancel();
    if (!state.stale) {
      _expiry = Timer(const Duration(seconds: 30) - _now.difference(c.receivedAt), markStale);
    }
  }

  Future<void> load() async {
    final auth = ref.read(authProvider), i = auth.identity;
    if (_working || auth.busy || i?.walletAddress == null) return;
    if (!i!.signingAvailable) {
      _publish(context: state.context, failure: 'authWalletReconnect');
      return;
    }
    final generation = ++_generation, epoch = _epoch;
    bool current() => _current(i, generation);
    final previous = state.context,
        repository = ref.read(internalTransferRepositoryProvider),
        journal = ref.read(internalTransferJournalProvider);
    _working = true;
    _expiry?.cancel();
    _publish(context: previous, step: InternalTransferStep.reading);
    try {
      final c = await repository.read(
        address: i.walletAddress!,
        asset: state.asset,
        direction: state.direction,
        isCurrent: current,
      );
      if (!current()) return;
      _validate(c, i.walletAddress!);
      final pending = journal.snapshot.records
          .where((r) => r.address.toLowerCase() == c.address.toLowerCase())
          .singleOrNull;
      if (pending?.reply != null && journal.snapshot.ready && !journal.snapshot.failure) {
        await journal.complete(pending!.key);
        final activity = ref.read(symbolSettingsActivityProvider.notifier),
            lease = activity.acquire(SymbolSetting.internalTransfer, checkingOnly: true);
        if (lease != null) activity.finish(lease, unresolved: false);
      }
      if (!current()) return;
      _acceptBalances(c);
      _publish(
        context: c,
        record: pending,
        stale: epoch != _epoch,
        amount: pending?.reply != null ? '' : null,
      );
      _arm(c);
    } catch (error) {
      if (current()) {
        _publish(context: previous, errorDetails: errorDetailsOf(error), failure: _failure(error));
      }
    } finally {
      _working = false;
    }
  }

  InternalTransferReview? prepare() {
    final c = state.context,
        auth = ref.read(authProvider),
        storage = ref.read(internalTransferStorageProvider);
    if (_working ||
        state.busy ||
        auth.busy ||
        auth.identity?.signingAvailable != true ||
        c == null ||
        state.stale ||
        !_fresh(c) ||
        c.validate(state.amount) != null ||
        !storage.ready ||
        storage.failure ||
        ref.read(pendingInternalTransfersProvider).isNotEmpty ||
        ref.read(symbolSettingsActivityProvider).blocks(SymbolSetting.internalTransfer)) {
      return null;
    }
    final review = InternalTransferReview(
      context: c,
      amount: state.amount,
      clientId:
          'vanta-transfer-${_now.microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(1 << 32).toRadixString(36)}',
    );
    _publish(context: c, review: review, step: InternalTransferStep.reviewing, stale: false);
    return review;
  }

  void cancel(InternalTransferReview review) {
    if (!_working && identical(state.review, review)) {
      _publish(context: state.context, stale: state.stale);
    }
  }

  void _invalidate() {
    ref.read(accountReadProvider.notifier).markStale();
    ref.read(spotAccountReadProvider.notifier).markStale();
    ref.read(positionRiskProvider.notifier).markStale();
    ref.read(futuresAssetModeProvider.notifier).markStale();
    ref.read(withdrawInfoProvider.notifier).markStale();
  }

  void _acceptBalances(InternalTransferContext context) {
    ref.read(accountReadProvider.notifier).acceptSnapshot(context.futures);
    ref.read(spotAccountReadProvider.notifier).acceptSnapshot(context.spot);
  }

  Future<void> confirm(InternalTransferReview review) async {
    final auth = ref.read(authProvider), i = auth.identity;
    if (_working ||
        !identical(state.review, review) ||
        i?.walletAddress == null ||
        auth.busy ||
        i?.signingAvailable != true ||
        state.stale ||
        !_fresh(review.context)) {
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier),
        lease = activity.acquire(SymbolSetting.internalTransfer);
    if (lease == null) return;
    final generation = _generation, epoch = _epoch;
    bool current() => _current(i!, generation);
    bool canSubmit() => current() && epoch == _epoch && _fresh(review.context);
    final journal = ref.read(internalTransferJournalProvider),
        repository = ref.read(internalTransferRepositoryProvider),
        clock = ref.read(internalTransferClockProvider);
    InternalTransferRecord? record;
    var prepared = false, dispatched = false;
    _working = true;
    _expiry?.cancel();
    _publish(context: review.context, step: InternalTransferStep.signing);
    try {
      final reply = await repository.submit(
        review: review,
        canSubmit: canSubmit,
        beforeSend: (nonce) async {
          if (!canSubmit()) throw const AccountReadFailure('internalTransferChanged');
          record = InternalTransferRecord(
            address: review.context.address,
            asset: review.context.assetName,
            amount: review.amount,
            direction: review.context.direction,
            clientId: review.clientId,
            nonce: nonce,
            preparedAt: clock().toUtc(),
          );
          await journal.prepare(record!);
          prepared = true;
          if (!canSubmit()) throw const AccountReadFailure('internalTransferChanged');
        },
        onDispatch: () {
          if (!prepared || !canSubmit()) throw const AccountReadFailure('internalTransferChanged');
          dispatched = true;
          activity.submitted(lease);
          _invalidate();
          if (current()) _publish(context: review.context, step: InternalTransferStep.submitting);
        },
      );
      if (!dispatched || record == null) throw const AccountReadFailure('accountDataInvalid');
      await journal.report(record!.key, reply);
      if (!current()) return;
      final reported = record!.reported(reply);
      _publish(context: review.context, record: reported, step: InternalTransferStep.checking);
      final checkedEpoch = _epoch;
      final checked = await repository.read(
        address: review.context.address,
        asset: review.context.assetName,
        direction: review.context.direction,
        isCurrent: current,
      );
      if (!current()) return;
      _validate(checked, review.context.address);
      await journal.complete(record!.key);
      if (current()) {
        _invalidate();
        _acceptBalances(checked);
        _publish(context: checked, record: reported, stale: checkedEpoch != _epoch, amount: '');
        _arm(checked);
      }
    } catch (error) {
      var failure = _failure(error);
      if (prepared && !dispatched && record != null) {
        try {
          await journal.complete(record!.key);
        } catch (_) {
          failure = 'internalTransferStorage';
        }
      }
      if (current()) {
        _publish(context: state.context, errorDetails: errorDetailsOf(error), failure: failure);
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
