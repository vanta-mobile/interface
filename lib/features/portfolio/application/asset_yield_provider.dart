import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_providers.dart';
import '../data/asset_yield_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/asset_yield.dart';

final assetYieldClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final assetYieldRepositoryProvider = Provider.autoDispose<AssetYieldRepository>((ref) {
  final aster = AsterYieldService(), lista = ListaYieldService();
  ref.onDispose(aster.close);
  ref.onDispose(lista.close);
  return PublicAssetYieldRepository(aster, lista, now: ref.watch(assetYieldClockProvider));
});
final assetYieldProvider = NotifierProvider.autoDispose
    .family<AssetYieldController, AssetYieldState, YieldAsset>(AssetYieldController.new);

/// Visible supported assets only; shared across Spot/Futures. Public GETs only.
class AssetYieldController extends Notifier<AssetYieldState> {
  AssetYieldController(this.asset);
  final YieldAsset asset;
  Timer? _refresh, _expiry;
  int _generation = 0;
  DateTime get _now => ref.read(assetYieldClockProvider)().toUtc();
  bool get _active => ref.read(quoteUpdatesActiveProvider);
  @override
  AssetYieldState build() {
    ref.watch(assetYieldRepositoryProvider);
    ref.listen(quoteUpdatesActiveProvider, (_, active) {
      _generation++;
      _refresh?.cancel();
      _expiry?.cancel();
      state = AssetYieldState(checkedAt: _now, quote: state.quote, active: active);
      if (active) unawaited(refresh());
    });
    ref.onDispose(() {
      _generation++;
      _refresh?.cancel();
      _expiry?.cancel();
    });
    Future.microtask(() {
      if (ref.mounted && _active) unawaited(refresh());
    });
    return AssetYieldState(checkedAt: _now, active: _active);
  }

  Future<void> refresh() async {
    if (!ref.mounted || !_active || state.loading) return;
    final generation = ++_generation;
    _refresh?.cancel();
    state = AssetYieldState(
      checkedAt: _now,
      quote: state.quote,
      loading: true,
      failureKey: state.failureKey,
    );
    bool current() => ref.mounted && generation == _generation && _active;
    try {
      final quote = await ref.read(assetYieldRepositoryProvider).read(asset);
      if (!current()) return;
      if (quote.asset != asset) throw const AccountReadFailure('accountDataInvalid');
      state = AssetYieldState(checkedAt: _now, quote: quote);
    } catch (error) {
      if (!current()) return;
      final key = error is AccountReadFailure ? error.key : null;
      state = AssetYieldState(
        checkedAt: _now,
        quote: state.quote,
        failureKey: switch (key) {
          'accountDataInvalid' || 'accountNetwork' || 'accountRateLimited' => key,
          _ => 'assetYieldFailed',
        },
      );
    }
    if (!current()) return;
    _scheduleExpiry();
    _refresh = Timer(const Duration(minutes: 5), () => unawaited(refresh()));
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final quote = state.quote;
    if (quote == null) return;
    final deadlines = [
      quote.receivedAt.add(const Duration(minutes: 5)),
      quote.receivedAt.subtract(const Duration(seconds: 30)),
      quote.sourceDay,
      quote.sourceDay.add(const Duration(days: 3)),
      if (quote.updatedAt != null) quote.updatedAt!.subtract(const Duration(seconds: 30)),
    ].where((time) => time.isAfter(_now)).toList()..sort();
    if (deadlines.isEmpty) return;
    _expiry = Timer(deadlines.first.difference(_now), () {
      if (!ref.mounted) return;
      state = AssetYieldState(
        checkedAt: _now,
        quote: state.quote,
        loading: state.loading,
        failureKey: state.failureKey,
        active: state.active,
      );
      _scheduleExpiry();
    });
  }
}
