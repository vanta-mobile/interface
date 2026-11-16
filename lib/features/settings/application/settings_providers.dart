import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/network/request_scope.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../core/vanta_api/vanta_api_http.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../notifications/application/push_device_provider.dart';
import '../data/app_cache_repository.dart';
import '../data/app_update_repository.dart';
import '../domain/app_version.dart';

/// Installed release version from the native bundle; null when unreadable.
final appVersionProvider = FutureProvider<AppVersion?>((ref) async {
  try {
    final metadata = await ref.watch(pushDeviceMetadataReaderProvider)();
    return AppVersion.tryParse(metadata.appVersion);
  } catch (_) {
    return null;
  }
});

/// Owned by the settings page: leaving it closes the lease and aborts a check.
final appUpdateRepositoryProvider = Provider.autoDispose<AppUpdateRepository?>((ref) {
  final base = ref.watch(vantaApiConfigurationProvider).baseUri;
  if (base == null) return null;
  final repository = AppUpdateRepository(
    VantaApiHttp(baseUri: base, client: ref.watch(backendHttpPoolProvider).lease()),
  );
  ref.onDispose(repository.close);
  return repository;
});

final appUpdatePlatformProvider = Provider<String>(
  (ref) => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
);

final appUpdateCheckProvider = NotifierProvider.autoDispose<AppUpdateCheckController, bool>(
  AppUpdateCheckController.new,
);

/// State is whether a check is in flight.
class AppUpdateCheckController extends Notifier<bool> {
  int _revision = 0;
  @override
  bool build() {
    ref.watch(appUpdateRepositoryProvider);
    _revision++;
    _pending = null;
    ref.onDispose(() => _revision++);
    return false;
  }

  Future<AppUpdateCheck>? _pending;
  Future<AppUpdateCheck> check() {
    if (_pending case final pending?) return pending;
    final task = _check();
    _pending = task;
    return task.whenComplete(() {
      if (identical(_pending, task)) _pending = null;
    });
  }

  Future<AppUpdateCheck> _check() async {
    final repository = ref.read(appUpdateRepositoryProvider);
    final revision = _revision;
    bool isCurrent() => ref.mounted && revision == _revision;
    if (repository == null) throw const VantaApiFailure(vantaApiUnavailable);
    final platform = ref.read(appUpdatePlatformProvider);
    state = true;
    try {
      final current = await ref.read(appVersionProvider.future);
      if (!isCurrent()) throw const VantaApiFailure(vantaApiRequestFailed);
      if (current == null) throw const VantaApiFailure(vantaApiDataInvalid);
      final config = await RequestScope.runOwned(isCurrent, () => repository.read(platform));
      if (!isCurrent()) throw const VantaApiFailure(vantaApiRequestFailed);
      return AppUpdateCheck(current: current, minimum: config.minimum, release: config.release);
    } finally {
      if (isCurrent()) state = false;
    }
  }
}

final appCacheRepositoryProvider = Provider<AppCacheRepository>((_) => AppCacheRepository());

class AppCacheState {
  const AppCacheState({this.bytes, this.clearing = false});

  /// Null until measured or when the cache directory cannot be read.
  final int? bytes;
  final bool clearing;
}

final appCacheProvider = NotifierProvider.autoDispose<AppCacheController, AppCacheState>(
  AppCacheController.new,
);

class AppCacheController extends Notifier<AppCacheState> {
  int _revision = 0;

  @override
  AppCacheState build() {
    ref.onDispose(() => _revision++);
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(measure());
    });
    return const AppCacheState();
  }

  Future<void> measure() async {
    final revision = ++_revision;
    int? bytes;
    try {
      bytes = await ref.read(appCacheRepositoryProvider).size();
    } catch (_) {
      bytes = null;
    }
    if (ref.mounted && revision == _revision) {
      state = AppCacheState(bytes: bytes, clearing: state.clearing);
    }
  }

  /// Throws when any cache entry could not be removed; the size is re-measured.
  Future<void> clear() async {
    if (state.clearing) return;
    state = AppCacheState(bytes: state.bytes, clearing: true);
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      await ref.read(appCacheRepositoryProvider).clear();
    } finally {
      if (ref.mounted) {
        state = AppCacheState(bytes: state.bytes);
        await measure();
      }
    }
  }
}
