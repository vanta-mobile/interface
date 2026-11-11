import '../../../core/network/request_scope.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_providers.dart';
import '../data/asset_metadata_service.dart';
import '../data/asset_logo_disk_cache.dart';
import '../data/asset_metadata_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/asset_metadata.dart';

final assetMetadataClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final assetLogoDiskCacheProvider = Provider<AssetLogoDiskCache>(
  (ref) => AssetLogoDiskCache(now: ref.watch(assetMetadataClockProvider)),
);
final assetMetadataServiceProvider = Provider.autoDispose<AssetMetadataService>((ref) {
  final s = AssetMetadataService(
    client: ref.watch(backendHttpPoolProvider).lease(),
    diskCache: ref.watch(assetLogoDiskCacheProvider),
  );
  ref.onDispose(s.close);
  return s;
});
final assetMetadataRepositoryProvider = Provider.autoDispose<AssetMetadataRepository>(
  (ref) => PublicAssetMetadataRepository(
    ref.watch(assetMetadataServiceProvider),
    now: ref.watch(assetMetadataClockProvider),
  ),
);
final assetLogoProvider = FutureProvider.autoDispose.family<Uint8List, Uri>(
  (ref, uri) => ref.watch(assetMetadataServiceProvider).logo(uri),
  retry: (_, _) => null,
);
final assetLogoRetryProvider = Provider.autoDispose<void Function(Uri)>(
  (ref) => (uri) {
    ref.read(assetMetadataServiceProvider).evictLogo(uri);
    ref.invalidate(assetLogoProvider(uri));
  },
);
final assetMetadataProvider = NotifierProvider.autoDispose
    .family<AssetMetadataController, AssetMetadataState, AssetMetadataSource>(
      AssetMetadataController.new,
    );

/// Two independent public sources, shared across Spot/Futures. No account reads,
/// signing, retry loops or per-asset catalog requests.
class AssetMetadataController extends Notifier<AssetMetadataState> {
  AssetMetadataController(this.source);
  final AssetMetadataSource source;
  int _generation = 0;
  Timer? _expiry;
  DateTime get _now => ref.read(assetMetadataClockProvider)().toUtc();
  bool get _active => ref.read(quoteUpdatesActiveProvider);
  @override
  AssetMetadataState build() {
    ref.watch(assetMetadataRepositoryProvider);
    // A hidden icon has no expiry UI to update; release its timer as soon as
    // the last consumer leaves, including the frame before auto-disposal.
    ref.onCancel(() => _expiry?.cancel());
    ref.onResume(
      () => scheduleMicrotask(() {
        if (ref.mounted) _schedule();
      }),
    );
    ref.listen(quoteUpdatesActiveProvider, (_, active) {
      _generation++;
      _expiry?.cancel();
      final snapshot = state.snapshot;
      state = AssetMetadataState(
        snapshot: snapshot,
        failed: state.failed,
        stale: snapshot != null && !snapshot.freshAt(_now),
        active: active,
      );
      if (active) {
        if (!state.failed && (snapshot == null || !snapshot.freshAt(_now))) {
          unawaited(refresh());
        } else {
          _schedule();
        }
      }
    });
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    Future.microtask(() {
      if (ref.mounted && _active) unawaited(refresh());
    });
    return AssetMetadataState(active: _active);
  }

  void _schedule() {
    _expiry?.cancel();
    final snapshot = state.snapshot;
    if (snapshot == null || !_active || !snapshot.freshAt(_now)) return;
    _expiry = Timer(snapshot.receivedAt.add(const Duration(minutes: 15)).difference(_now), () {
      if (!ref.mounted) return;
      state = AssetMetadataState(
        snapshot: state.snapshot,
        loading: state.loading,
        failed: state.failed,
        stale: true,
        active: _active,
      );
    });
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
    final generation = ++_generation, snapshot = state.snapshot;
    state = AssetMetadataState(
      snapshot: snapshot,
      loading: true,
      failed: state.failed,
      stale: state.stale,
    );
    try {
      final value = await RequestScope.run(
        () => ref.mounted && generation == _generation && _active,
        () => ref.read(assetMetadataRepositoryProvider).read(source),
      );
      if (!ref.mounted || generation != _generation || !_active) return;
      if (value.source != source || !value.freshAt(_now)) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      state = AssetMetadataState(snapshot: value);
    } catch (_) {
      if (!ref.mounted || generation != _generation || !_active) return;
      state = AssetMetadataState(
        snapshot: state.snapshot,
        failed: true,
        stale: state.snapshot != null,
      );
    }
    _schedule();
  }
}
