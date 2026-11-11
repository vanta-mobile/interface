import '../../../core/network/request_scope.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_providers.dart';
import '../data/aster_account_service.dart';
import '../data/asset_index_repository.dart';
import '../domain/asset_valuation.dart';

final assetIndexClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final assetIndexRepositoryProvider = Provider.autoDispose<AssetIndexRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return AsterAssetIndexRepository(service, now: ref.watch(assetIndexClockProvider));
});
final assetIndexProvider = NotifierProvider.autoDispose<AssetIndexController, AssetIndexState>(
  AssetIndexController.new,
);

/// Public prices only, shared by displayed Spot/Futures balances. No wallet
/// signatures. Cancel timers and discard in-flight results on pause/disposal.
class AssetIndexController extends Notifier<AssetIndexState> {
  Timer? _refreshTimer, _expiry, _release;
  int _generation = 0;
  DateTime get _now => ref.read(assetIndexClockProvider)().toUtc();
  bool get _active => ref.read(quoteUpdatesActiveProvider);
  @override
  AssetIndexState build() {
    ref.watch(assetIndexRepositoryProvider);
    ref.listen(quoteUpdatesActiveProvider, (_, active) {
      _generation++;
      _refreshTimer?.cancel();
      _expiry?.cancel();
      state = AssetIndexState(checkedAt: _now, snapshot: state.snapshot, active: active);
      if (active) unawaited(refresh());
    });
    // Keep shared public rates briefly across gaps between page consumers;
    // a returning consumer can reuse still-fresh data without a cold fetch.
    final link = ref.keepAlive();
    ref.onCancel(() => _release = Timer(const Duration(seconds: 60), link.close));
    ref.onResume(() => _release?.cancel());
    ref.onDispose(() {
      _generation++;
      _refreshTimer?.cancel();
      _expiry?.cancel();
      _release?.cancel();
    });
    Future.microtask(() {
      if (ref.mounted && _active) unawaited(refresh());
    });
    return AssetIndexState(checkedAt: _now, active: _active);
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
    final generation = ++_generation;
    _refreshTimer?.cancel();
    state = AssetIndexState(
      checkedAt: _now,
      snapshot: state.snapshot,
      loading: true,
      failed: state.failed,
      active: state.active,
    );
    bool current() => ref.mounted && generation == _generation && _active;
    try {
      final snapshot = await RequestScope.runOwned(
        current,
        () => ref.read(assetIndexRepositoryProvider).read(),
      );
      if (!current()) return;
      state = AssetIndexState(checkedAt: _now, snapshot: snapshot);
    } catch (_) {
      if (!current()) return;
      state = AssetIndexState(checkedAt: _now, snapshot: state.snapshot, failed: true);
    }
    if (!current()) return;
    _scheduleExpiry();
    // A failed read retries soon; the previous snapshot stays usable until its
    // own freshness limits expire.
    _refreshTimer = Timer(Duration(seconds: state.failed ? 5 : 30), () => unawaited(refresh()));
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    final deadlines = [
      snapshot.receivedAt.add(const Duration(seconds: 60)),
      snapshot.receivedAt.subtract(const Duration(seconds: 30)),
      for (final quote in snapshot.indices.values) quote.time.add(const Duration(seconds: 90)),
      for (final quote in snapshot.indices.values) quote.time.subtract(const Duration(seconds: 30)),
    ].where((time) => time.isAfter(_now)).toList()..sort();
    if (deadlines.isEmpty) return;
    _expiry = Timer(deadlines.first.difference(_now), () {
      if (!ref.mounted) return;
      state = AssetIndexState(
        checkedAt: _now,
        snapshot: state.snapshot,
        loading: state.loading,
        failed: state.failed,
        active: state.active,
      );
      _scheduleExpiry();
    });
  }
}
