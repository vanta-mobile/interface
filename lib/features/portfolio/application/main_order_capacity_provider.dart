import '../../../core/network/network_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/selection_providers.dart';
import '../data/aster_account_service.dart';
import '../data/position_margin_mapper.dart';
import '../data/signed_main_order_capacity_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/main_order_capacity.dart';
import 'account_read_provider.dart';
import 'live_order_provider.dart';
import 'symbol_settings_activity.dart';

final mainOrderCapacityRepositoryProvider = Provider<MainOrderCapacityRepository>((ref) {
  final service = AsterAccountService(
    client: ref.watch(backendHttpPoolProvider).lease(),
    decodeResponse: decodePositionMarginJson,
  );
  ref.onDispose(service.close);
  return SignedMainOrderCapacityRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(liveOrderClockProvider),
  );
});

final mainOrderCapacityProvider =
    NotifierProvider<MainOrderCapacityController, MainOrderCapacityState>(
      MainOrderCapacityController.new,
    );

/// Facts only. Form quantities and ratios belong to their independent draft;
/// merely watching this provider never starts HTTP or opens a wallet prompt.
class MainOrderCapacityController extends Notifier<MainOrderCapacityState> {
  int _revision = 0;
  int? _lease;
  @override
  MainOrderCapacityState build() {
    void reset() {
      _revision++;
      _releaseRead();
      state = const MainOrderCapacityState();
    }

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
        if (a != b) reset();
      },
    );
    ref.listen(symbolProvider, (a, b) {
      if (a != b) reset();
    });
    ref.listen(liveOrderProvider, (before, after) {
      if (before?.context != after.context) {
        reset();
      } else if (after.stale && before?.stale != true) {
        _revision++;
        _releaseRead();
        state = MainOrderCapacityState(snapshot: state.snapshot, stale: true);
      }
    });
    ref.onDispose(() => _revision++);
    return const MainOrderCapacityState();
  }

  MainOrderCapacitySnapshot? get current {
    if (!ref.mounted || state.loading || state.stale) return null;
    final data = state.snapshot, live = ref.read(liveOrderProvider), auth = ref.read(authProvider);
    final activity = ref.read(symbolSettingsActivityProvider);
    if (data == null ||
        data.context != live.context ||
        data.context.symbol != ref.read(symbolProvider) ||
        live.busy ||
        live.needsRecheck ||
        live.stale ||
        activity.busy ||
        activity.owner != null ||
        activity.unresolved ||
        activity.recoveryBlocked ||
        auth.busy ||
        auth.identity?.signingAvailable != true ||
        auth.identity?.walletAddress?.toLowerCase() != data.context.address.toLowerCase()) {
      return null;
    }
    final now = ref.read(liveOrderClockProvider)();
    final age = now.difference(data.context.receivedAt);
    return age.isNegative || age >= const Duration(seconds: 30) || data.receivedAt.isAfter(now)
        ? null
        : data;
  }

  void stop() {
    if (!state.loading) return;
    _revision++;
    _releaseRead();
    state = MainOrderCapacityState(snapshot: state.snapshot, stale: true);
  }

  void _releaseRead() {
    if (_lease case final lease?) {
      ref.read(symbolSettingsActivityProvider.notifier).finish(lease, unresolved: false);
      _lease = null;
    }
  }

  Future<void> load(String symbol) async {
    final live = ref.read(liveOrderProvider), data = live.context, auth = ref.read(authProvider);
    if (state.loading ||
        live.busy ||
        live.needsRecheck ||
        auth.busy ||
        data == null ||
        data.symbol != symbol ||
        symbol != ref.read(symbolProvider) ||
        live.stale ||
        auth.identity?.signingAvailable != true ||
        auth.identity?.walletAddress?.toLowerCase() != data.address.toLowerCase()) {
      return;
    }
    final age = ref.read(liveOrderClockProvider)().difference(data.receivedAt);
    if (age.isNegative || age >= const Duration(seconds: 30)) {
      state = MainOrderCapacityState(
        snapshot: state.snapshot,
        stale: true,
        failure: const AccountReadFailure('liveOrderContextExpired'),
      );
      return;
    }
    final activity = ref.read(symbolSettingsActivityProvider.notifier);
    final lease = activity.acquire(SymbolSetting.order);
    if (lease == null) {
      state = MainOrderCapacityState(
        snapshot: state.snapshot,
        stale: true,
        failure: const AccountReadFailure('liveOrderSettingsBusy'),
      );
      return;
    }
    _lease = lease;
    final epoch = ref.read(symbolSettingsActivityProvider).epoch;
    final revision = ++_revision, previous = state.snapshot;
    bool scoped() => ref.mounted && revision == _revision;
    bool fresh() {
      if (!scoped()) return false;
      final state = ref.read(liveOrderProvider), identity = ref.read(authProvider);
      final operation = ref.read(symbolSettingsActivityProvider);
      final elapsed = ref.read(liveOrderClockProvider)().difference(data.receivedAt);
      return state.context == data &&
          data.symbol == ref.read(symbolProvider) &&
          !state.busy &&
          !state.needsRecheck &&
          !state.stale &&
          operation.epoch == epoch &&
          operation.owner == SymbolSetting.order &&
          operation.busy &&
          !operation.unresolved &&
          !operation.recoveryBlocked &&
          !identity.busy &&
          identity.identity?.id == auth.identity?.id &&
          identity.identity?.walletKind == auth.identity?.walletKind &&
          identity.identity?.signingAvailable == true &&
          identity.identity?.walletAddress?.toLowerCase() == data.address.toLowerCase() &&
          !elapsed.isNegative &&
          elapsed < const Duration(seconds: 30);
    }

    state = MainOrderCapacityState(snapshot: previous, loading: true, stale: true);
    try {
      final snapshot = await ref
          .read(mainOrderCapacityRepositoryProvider)
          .read(
            context: data,
            isCurrent: fresh,
            onStep: (_) {
              if (!fresh()) throw const AccountReadFailure('liveOrderContextExpired');
            },
          );
      if (!fresh()) throw const AccountReadFailure('liveOrderContextExpired');
      final now = ref.read(liveOrderClockProvider)();
      if (snapshot.context != data ||
          snapshot.account.address.toLowerCase() != data.address.toLowerCase() ||
          snapshot.account.receivedAt.isBefore(data.receivedAt) ||
          snapshot.account.receivedAt.isAfter(snapshot.receivedAt) ||
          snapshot.receivedAt.isAfter(now) ||
          snapshot.receivedAt.isBefore(data.receivedAt)) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      state = MainOrderCapacityState(snapshot: snapshot);
    } catch (error) {
      if (scoped()) {
        state = MainOrderCapacityState(
          snapshot: previous,
          stale: true,
          failure: error is AccountReadFailure
              ? error
              : const AccountReadFailure('accountReadFailed'),
        );
      }
    } finally {
      activity.finish(lease, unresolved: false);
      if (_lease == lease) _lease = null;
    }
  }
}
