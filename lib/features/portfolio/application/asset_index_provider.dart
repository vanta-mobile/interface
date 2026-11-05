import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_providers.dart';
import '../data/aster_account_service.dart';
import '../data/asset_index_repository.dart';
import '../domain/asset_valuation.dart';

final assetIndexClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final assetIndexRepositoryProvider = Provider.autoDispose<AssetIndexRepository>((ref) {
  final service = AsterAccountService();
  ref.onDispose(service.close);
  return AsterAssetIndexRepository(service, now: ref.watch(assetIndexClockProvider));
});
final assetIndexProvider = NotifierProvider.autoDispose<AssetIndexController, AssetIndexState>(
  AssetIndexController.new,
);

/// Public prices only, shared by displayed Spot/Futures balances. No wallet
/// signatures. Cancel timers and discard in-flight results on pause/disposal.
class AssetIndexController extends Notifier<AssetIndexState> {
  Timer? _refreshTimer, _expiry;
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
    ref.onDispose(() {
      _generation++;
      _refreshTimer?.cancel();
      _expiry?.cancel();
    });
    Future.microtask(() {
      if (ref.mounted && _active) unawaited(refresh());
    });
    return AssetIndexState(checkedAt: _now, active: _active);
  }

  Future<void> refresh() async {
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
      final snapshot = await ref.read(assetIndexRepositoryProvider).read();
      if (!current()) return;
      state = AssetIndexState(checkedAt: _now, snapshot: snapshot);
    } catch (_) {
      if (!current()) return;
      state = AssetIndexState(checkedAt: _now, snapshot: state.snapshot, failed: true);
    }
    if (!current()) return;
    _scheduleExpiry();
    _refreshTimer = Timer(const Duration(seconds: 30), () => unawaited(refresh()));
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
