import '../../../core/network/refresh_batch.dart';
import '../../../core/network/request_scope.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../market/application/market_providers.dart';
import '../data/points_repository.dart';
import '../domain/points.dart';

final pointsClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final pointsRepositoryProvider = Provider.autoDispose<PointsRepository>((ref) {
  final service = PointsService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return PublicPointsRepository(service, now: ref.watch(pointsClockProvider));
});
final currentPointsCampaignProvider =
    NotifierProvider.autoDispose<CurrentPointsCampaignController, PointsLoadState<PointsCampaign?>>(
      CurrentPointsCampaignController.new,
    );
final pointsCampaignsProvider =
    NotifierProvider.autoDispose<PointsCampaignsController, PointsLoadState<List<PointsCampaign>>>(
      PointsCampaignsController.new,
    );
final pointsLeaderboardProvider = NotifierProvider.autoDispose
    .family<PointsLeaderboardController, PointsLoadState<PointsLeaderboard>, int?>(
      PointsLeaderboardController.new,
    );
final walletPointsProvider =
    NotifierProvider.autoDispose<WalletPointsController, PointsLoadState<WalletPoints>>(
      WalletPointsController.new,
    );
final walletPointsHistoryProvider =
    NotifierProvider.autoDispose<
      WalletPointsHistoryController,
      PointsLoadState<WalletPointsHistory>
    >(WalletPointsHistoryController.new);

typedef _WalletScope = ({String id, String address, WalletKind kind});
_WalletScope? _scope(AuthIdentity? identity) {
  final address = identity?.walletAddress;
  if (identity == null || address == null || !isPointsEvmAddress(address)) return null;
  return (id: identity.id, address: address.toLowerCase(), kind: identity.walletKind);
}

/// Feature-local common lifecycle for the points and event readers. Public data
/// loads on display. Address-bearing data needs an explicit refresh unless the
/// reader opts into [autoLoadWallet], which reads for the signed-in EVM wallet
/// and reloads when that identity changes. Reads are unsigned public GETs.
abstract class PointsLoadController<T> extends Notifier<PointsLoadState<T>> {
  Timer? _expiry;
  int _generation = 0;
  bool get walletScoped => false;
  bool get autoLoadWallet => false;
  bool get _active => ref.read(quoteUpdatesActiveProvider);
  bool get _autoLoad =>
      !walletScoped || autoLoadWallet && _scope(ref.read(authProvider).identity) != null;
  DateTime get _now => ref.read(pointsClockProvider)().toUtc();
  Future<PointsSnapshot<T>> read(PointsRepository repository, String? address);
  @override
  PointsLoadState<T> build() {
    ref.watch(pointsRepositoryProvider);
    if (walletScoped) {
      ref.listen(authProvider.select((s) => _scope(s.identity)), (_, scope) {
        _generation++;
        _expiry?.cancel();
        state = PointsLoadState(active: _active);
        Future.microtask(() {
          if (ref.mounted && autoLoadWallet && scope != null && _active) unawaited(refresh());
        });
      });
    }
    ref.listen(quoteUpdatesActiveProvider, (_, active) {
      _generation++;
      _expiry?.cancel();
      state = PointsLoadState(
        snapshot: state.snapshot,
        stale: state.snapshot != null,
        active: active,
        failureKey: state.failureKey,
        errorDetails: state.errorDetails,
      );
      if (active && _autoLoad) unawaited(refresh());
    });
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    Future.microtask(() {
      if (ref.mounted && _active && _autoLoad) unawaited(refresh());
    });
    return PointsLoadState(active: _active);
  }

  Future<void>? _refreshTask;
  Future<void> refresh() {
    if (state.loading && _refreshTask != null) return _refreshTask!;
    final task = _refresh();
    _refreshTask = task;
    return task.whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
  }

  Future<void> _refresh() async {
    if (!ref.mounted || !_active || state.loading) return;
    final scope = walletScoped ? _scope(ref.read(authProvider).identity) : null;
    if (walletScoped && scope == null) {
      state = PointsLoadState(failureKey: 'pointsWalletRequired');
      return;
    }
    final generation = ++_generation;
    state = PointsLoadState(
      snapshot: state.snapshot,
      loading: true,
      stale: state.stale,
      failureKey: state.failureKey,
      errorDetails: state.errorDetails,
    );
    bool current() =>
        ref.mounted &&
        _active &&
        generation == _generation &&
        (!walletScoped || scope == _scope(ref.read(authProvider).identity));
    try {
      final snapshot = await RequestScope.run(
        current,
        () => read(ref.read(pointsRepositoryProvider), scope?.address),
      );
      if (!current()) return;
      if (snapshot.receivedAt.isAfter(_now.add(const Duration(seconds: 30)))) {
        throw const PointsFailure('pointsDataInvalid');
      }
      final stale = !_now.isBefore(snapshot.receivedAt.add(const Duration(minutes: 5)));
      state = PointsLoadState(snapshot: snapshot, stale: stale);
      _expiry?.cancel();
      if (!stale) {
        _expiry = Timer(snapshot.receivedAt.add(const Duration(minutes: 5)).difference(_now), () {
          if (ref.mounted && identical(state.snapshot, snapshot)) {
            state = PointsLoadState(
              snapshot: state.snapshot,
              loading: state.loading,
              stale: true,
              active: state.active,
              failureKey: state.failureKey,
              errorDetails: state.errorDetails,
            );
          }
        });
      }
    } catch (error) {
      if (!current()) return;
      final key = error is PointsFailure ? error.key : null;
      state = PointsLoadState(
        snapshot: state.snapshot,
        stale: state.snapshot != null,
        errorDetails: error is PointsFailure ? error.details : null,
        failureKey: switch (key) {
          'pointsDataInvalid' || 'pointsNetwork' || 'pointsRateLimited' => key,
          _ => 'pointsUnavailable',
        },
      );
    }
  }

  void stop() {
    _generation++;
    _expiry?.cancel();
    state = PointsLoadState(
      snapshot: state.snapshot,
      stale: state.snapshot != null,
      active: _active,
    );
  }
}

class CurrentPointsCampaignController extends PointsLoadController<PointsCampaign?> {
  @override
  Future<PointsSnapshot<PointsCampaign?>> read(PointsRepository repository, String? address) =>
      repository.currentCampaign();
}

class PointsCampaignsController extends PointsLoadController<List<PointsCampaign>> {
  @override
  Future<PointsSnapshot<List<PointsCampaign>>> read(PointsRepository repository, String? address) =>
      repository.campaigns();
}

class PointsLeaderboardController extends PointsLoadController<PointsLeaderboard> {
  PointsLeaderboardController(this.campaign);
  final int? campaign;
  @override
  Future<PointsSnapshot<PointsLeaderboard>> read(
    PointsRepository repository,
    String? address,
  ) async {
    final snapshot = await repository.leaderboard(campaign);
    if (snapshot.value.campaign != campaign) throw const PointsFailure('pointsDataInvalid');
    return snapshot;
  }
}

class WalletPointsController extends PointsLoadController<WalletPoints> {
  @override
  bool get walletScoped => true;
  @override
  bool get autoLoadWallet => true;
  @override
  Future<PointsSnapshot<WalletPoints>> read(PointsRepository repository, String? address) async {
    final snapshot = await repository.wallet(address!);
    if (pointsAddressKey(snapshot.value.address) != address) {
      throw const PointsFailure('pointsDataInvalid');
    }
    return snapshot;
  }
}

class WalletPointsHistoryController extends PointsLoadController<WalletPointsHistory> {
  @override
  bool get walletScoped => true;
  @override
  bool get autoLoadWallet => true;
  @override
  Future<PointsSnapshot<WalletPointsHistory>> read(
    PointsRepository repository,
    String? address,
  ) async {
    final snapshot = await repository.walletHistory(address!);
    if (pointsAddressKey(snapshot.value.address) != address) {
      throw const PointsFailure('pointsDataInvalid');
    }
    return snapshot;
  }
}

/// The user's explicit period choice; null follows the default period.
final selectedPointsCampaignProvider = NotifierProvider.autoDispose<SelectedPointsCampaign, int?>(
  SelectedPointsCampaign.new,
);

class SelectedPointsCampaign extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? campaign) => state = campaign;
}

/// Period shown by "Points by period": the explicit choice, else the current
/// campaign, else the latest published one. Null until either list is read.
final pointsPeriodProvider = Provider.autoDispose<int?>((ref) {
  final selected = ref.watch(selectedPointsCampaignProvider);
  if (selected != null) return selected;
  final current = ref.watch(currentPointsCampaignProvider.select((s) => s.snapshot?.value?.number));
  if (current != null) return current;
  final campaigns = ref.watch(pointsCampaignsProvider.select((s) => s.snapshot?.value));
  if (campaigns == null || campaigns.isEmpty) return null;
  return campaigns.map((c) => c.number).reduce((a, b) => a > b ? a : b);
});

bool _walletReadable(Ref ref) => _scope(ref.read(authProvider).identity) != null;

/// Pull-to-refresh for the Points page: every section it shows.
final pointsPageRefreshProvider = Provider.autoDispose<Future<void> Function()>((ref) {
  final batch = RefreshBatch();
  return () {
    final period = ref.read(pointsPeriodProvider);
    return batch.run([
      ref.read(currentPointsCampaignProvider.notifier).refresh,
      ref.read(pointsCampaignsProvider.notifier).refresh,
      ref.read(pointsLeaderboardProvider(null).notifier).refresh,
      if (period != null) ref.read(pointsLeaderboardProvider(period).notifier).refresh,
      if (_walletReadable(ref)) ...[
        ref.read(walletPointsProvider.notifier).refresh,
        ref.read(walletPointsHistoryProvider.notifier).refresh,
      ],
    ]);
  };
});

/// The summary card's refresh: the wallet's points and its total rank only.
final pointsSummaryRefreshProvider = Provider.autoDispose<Future<void> Function()>((ref) {
  final batch = RefreshBatch();
  return () => batch.run([
    ref.read(pointsLeaderboardProvider(null).notifier).refresh,
    if (_walletReadable(ref)) ...[
      ref.read(walletPointsProvider.notifier).refresh,
      ref.read(walletPointsHistoryProvider.notifier).refresh,
    ],
  ]);
});

/// Pull-to-refresh for the total leaderboard page.
final pointsTotalRefreshProvider = Provider.autoDispose<Future<void> Function()>((ref) {
  final batch = RefreshBatch();
  return () => batch.run([
    ref.read(pointsLeaderboardProvider(null).notifier).refresh,
    if (_walletReadable(ref)) ref.read(walletPointsProvider.notifier).refresh,
  ]);
});
