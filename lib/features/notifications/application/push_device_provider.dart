import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/request_scope.dart';
import '../../../core/vanta_api/idempotency_key.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../../core/localization/locale_provider.dart';
import '../data/native_push_device.dart';
import '../data/push_api_repository.dart';
import '../domain/push_device.dart';
import 'push_messaging_provider.dart';

final pushApiRepositoryProvider = Provider<PushApiRepository?>((ref) {
  final session = ref.watch(vantaApiSessionRepositoryProvider);
  return session == null ? null : PushApiRepository(session);
});
final pushDeviceMetadataReaderProvider = Provider<Future<PushDeviceMetadata> Function()>(
  (_) => readNativePushDevice,
);
final pushUtcOffsetProvider = Provider<int Function()>(
  (_) =>
      () => DateTime.now().timeZoneOffset.inMinutes,
);

class PushDeviceState {
  const PushDeviceState({this.status, this.busy = false, this.error, this.bound = false});
  final PushStatus? status;
  final bool busy, bound;
  final Object? error;
}

final pushDeviceProvider = NotifierProvider<PushDeviceController, PushDeviceState>(
  PushDeviceController.new,
);

/// One device binding for the active Vanta session. No implicit wallet signing,
/// token persistence or credential copies. Logout revokes server bindings in
/// the backend transaction; never send an old wallet's cleanup under a new one.
class PushDeviceController extends Notifier<PushDeviceState> {
  int _revision = 0;
  String? _owner, _registeredSignature;
  bool _paused = false;
  Future<void>? _pending;
  final _possibleTokens = <String>{};
  final _keys = <String, String>{};

  @override
  PushDeviceState build() {
    ref.watch(pushApiRepositoryProvider);
    ref.listen(
      vantaApiSessionProvider.select((s) => (s.address, s.ready)),
      (_, _) => unawaited(refresh()),
    );
    ref.listen(
      authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress?.toLowerCase())),
      (_, _) => unawaited(refresh()),
    );
    ref.listen(pushRegistrationProvider, (_, _) => unawaited(refresh()));
    ref.listen(localeProvider, (_, _) => unawaited(refresh()));
    ref.onDispose(() => _revision++);
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(refresh());
    });
    return const PushDeviceState();
  }

  String? _activeOwner() {
    final session = ref.read(vantaApiSessionProvider);
    final identity = ref.read(authProvider).identity;
    return session.ready && identity?.walletAddress?.toLowerCase() == session.address
        ? '${identity!.id}:${session.address}'
        : null;
  }

  bool _current(int revision, String owner) =>
      ref.mounted && revision == _revision && _activeOwner() == owner;

  Future<void> refresh() {
    final revision = ++_revision, owner = _activeOwner();
    if (owner != _owner) {
      _owner = owner;
      _registeredSignature = null;
      _possibleTokens.clear();
      _keys.clear();
      _paused = false;
      state = const PushDeviceState();
    }
    if (owner == null) return Future.value();
    final previous = _pending ?? Future.value();
    final task = previous.then((_) async {
      if (_current(revision, owner)) await _sync(revision, owner);
    });
    _pending = task;
    return task.whenComplete(() {
      if (identical(_pending, task)) _pending = null;
    });
  }

  Future<void> _sync(int revision, String owner) async {
    final repository = ref.read(pushApiRepositoryProvider);
    if (repository == null) return;
    bool current() => _current(revision, owner);
    state = PushDeviceState(status: state.status, bound: state.bound, busy: true);
    Object? failure;
    try {
      await _synchronizeBinding(repository, current);
    } catch (error) {
      failure = _failure(error);
    }
    if (!current()) return;
    // Capability is useful even when native registration fails. A broken SDK
    // or device registration must not hide no_server_visibility from the inbox.
    var status = state.status;
    try {
      status = await RequestScope.runOwned(current, repository.status);
    } catch (error) {
      failure = _failure(error);
    }
    if (current()) {
      state = PushDeviceState(status: status, bound: _registeredSignature != null, error: failure);
    }
  }

  Object _failure(Object error) =>
      error is VantaApiFailure ? error : const VantaApiFailure(vantaApiRequestFailed);

  Future<void> _synchronizeBinding(PushApiRepository repository, bool Function() current) async {
    final registration = await ref.read(pushRegistrationProvider.future);
    if (!current()) return;
    final token = !_paused && registration.canReceive ? registration.token : null;
    await RequestScope.runOwned(current, () async {
      // A timed-out registration may have reached the backend. Retain its
      // token for cleanup when it changes or permission is withdrawn.
      for (final oldToken in _possibleTokens.toList()) {
        if (oldToken == token) continue;
        final operation = 'unregister:$oldToken';
        await repository.unregister(oldToken, idempotencyKey: _key(operation));
        if (!current()) return;
        _keys.remove(operation);
        _possibleTokens.remove(oldToken);
        _registeredSignature = null;
      }
      if (token == null || token.isEmpty) return;
      final metadata = await ref.read(pushDeviceMetadataReaderProvider)();
      if (!current()) return;
      final locale = (ref.read(localeProvider) ?? PlatformDispatcher.instance.locale)
          .toLanguageTag();
      final offset = ref.read(pushUtcOffsetProvider)();
      final signature = jsonEncode([
        token,
        metadata.platform.name,
        metadata.appId,
        metadata.appVersion,
        metadata.environment?.name,
        locale,
        offset,
      ]);
      if (signature == _registeredSignature) return;
      _possibleTokens.add(token);
      final operation = 'register:$signature';
      await repository.register(
        PushDeviceRegistration(
          metadata: metadata,
          token: token,
          locale: locale,
          utcOffsetMinutes: offset,
        ),
        idempotencyKey: _key(operation),
      );
      if (!current()) return;
      _keys.remove(operation);
      _registeredSignature = signature;
    });
  }

  String _key(String operation) => _keys.putIfAbsent(operation, newIdempotencyKey);

  /// Explicit backend unbinding; remains paused until bind() or a new session.
  Future<void> unbind() {
    _paused = true;
    return refresh();
  }

  Future<void> bind() {
    _paused = false;
    return refresh();
  }

  /// Ready for a future settings UI; the current design adds no settings page.
  /// Updates are serialized with binding work and cancelled on identity change.
  Future<void> updatePreferences(PushPreferencesUpdate update) {
    final owner = _activeOwner();
    if (owner == null) return Future.value();
    final revision = _revision;
    final previous = _pending ?? Future.value();
    final task = previous.then((_) async {
      if (_current(revision, owner)) await _updatePreferences(update, revision, owner);
    });
    _pending = task;
    return task.whenComplete(() {
      if (identical(_pending, task)) _pending = null;
    });
  }

  Future<void> _updatePreferences(PushPreferencesUpdate update, int revision, String owner) async {
    final repository = ref.read(pushApiRepositoryProvider);
    if (repository == null) return;
    final operation = jsonEncode([
      for (final category in PushCategory.values) update.categories[category],
      update.quietStart,
      update.quietEnd,
      update.minNotional?.toString(),
    ]);
    bool current() => _current(revision, owner);
    state = PushDeviceState(status: state.status, bound: state.bound, busy: true);
    try {
      await RequestScope.runOwned(
        current,
        () => repository.updatePreferences(update, idempotencyKey: _key('prefs:$operation')),
      );
      if (!current()) return;
      _keys.remove('prefs:$operation');
      final status = await RequestScope.runOwned(current, repository.status);
      if (current()) state = PushDeviceState(status: status, bound: state.bound);
    } catch (error) {
      if (current()) {
        state = PushDeviceState(
          status: state.status,
          bound: _registeredSignature != null,
          error: error is VantaApiFailure ? error : const VantaApiFailure(vantaApiRequestFailed),
        );
      }
    }
  }
}

/// Refresh native permission/token and timezone when returning from OS settings.
final pushDeviceLifecycleProvider = Provider<void>((ref) {
  ref.listen(pushDeviceProvider, (_, _) {});
  final observer = _PushResumeObserver(() async {
    ref.invalidate(pushRegistrationProvider);
    try {
      await ref.read(pushRegistrationProvider.future);
    } catch (_) {
      /* Owned state keeps the error. */
    }
    if (ref.mounted) await ref.read(pushDeviceProvider.notifier).refresh();
  });
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

class _PushResumeObserver extends WidgetsBindingObserver {
  _PushResumeObserver(this.resume);
  final Future<void> Function() resume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(resume());
  }
}
