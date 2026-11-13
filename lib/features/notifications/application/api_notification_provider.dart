import 'dart:async';

import '../../../core/vanta_api/idempotency_key.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/request_scope.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../data/api_notification_repository.dart';
import '../domain/api_notification.dart';
import '../domain/notification_status.dart';

final apiNotificationRepositoryProvider = Provider<ApiNotificationRepository?>((ref) {
  final session = ref.watch(vantaApiSessionRepositoryProvider);
  return session == null ? null : ApiNotificationRepository(session);
});

class ApiInboxState {
  ApiInboxState({
    Iterable<ApiNotification> items = const [],
    Map<String, ApiNotification> cache = const {},
    this.category = NotificationFilter.all,
    this.unreadOnly = false,
    this.nextCursor,
    this.unread = 0,
    this.loaded = false,
    this.loading = false,
    this.marking = false,
    this.error,
  }) : items = List.unmodifiable(items),
       cache = Map.unmodifiable(cache);
  final List<ApiNotification> items;

  /// Detail snapshots survive removal by the unread filter and pagination.
  final Map<String, ApiNotification> cache;
  final NotificationFilter category;
  final bool unreadOnly, loaded, loading, marking;
  final String? nextCursor;
  final int unread;
  final Object? error;

  ApiInboxState copy({
    Iterable<ApiNotification>? items,
    Map<String, ApiNotification>? cache,
    String? nextCursor,
    bool replaceCursor = false,
    int? unread,
    bool? loaded,
    bool? loading,
    bool? marking,
    Object? error,
  }) => ApiInboxState(
    items: items ?? this.items,
    cache: cache ?? this.cache,
    category: category,
    unreadOnly: unreadOnly,
    nextCursor: replaceCursor ? nextCursor : this.nextCursor,
    unread: unread ?? this.unread,
    loaded: loaded ?? this.loaded,
    loading: loading ?? this.loading,
    marking: marking ?? this.marking,
    error: error,
  );
}

final apiNotificationInboxProvider =
    NotifierProvider<ApiNotificationInboxController, ApiInboxState>(
      ApiNotificationInboxController.new,
    );

final serverUnreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(apiNotificationInboxProvider.select((s) => s.unread)),
);

class ApiNotificationInboxController extends Notifier<ApiInboxState> {
  int _identityRevision = 0, _readRevision = 0;
  Future<void>? _reading, _writing;
  bool _readingMore = false;
  final _cursors = <String>{};
  final _writeKeys = <String, String>{};

  @override
  ApiInboxState build() {
    final access = ref.watch(vantaApiSessionProvider.select((s) => (s.address, s.ready)));
    ref.watch(
      authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress?.toLowerCase())),
    );
    ref.watch(apiNotificationRepositoryProvider);
    final revision = ++_identityRevision;
    _readRevision++;
    _reading = null;
    _writing = null;
    _cursors.clear();
    _writeKeys.clear();
    ref.onDispose(() {
      _identityRevision++;
      _readRevision++;
    });
    if (access.$2) {
      scheduleMicrotask(() {
        if (ref.mounted && revision == _identityRevision) unawaited(refresh());
      });
    }
    return ApiInboxState(loading: access.$2);
  }

  bool _current(int revision) =>
      ref.mounted &&
      revision == _identityRevision &&
      ref.read(vantaApiSessionProvider).ready &&
      ref.read(vantaApiSessionProvider).address ==
          ref.read(authProvider).identity?.walletAddress?.toLowerCase();

  Future<void> filter(NotificationFilter category, bool unreadOnly) {
    if (category == state.category && unreadOnly == state.unreadOnly) return Future.value();
    _readRevision++;
    _reading = null;
    _cursors.clear();
    state = ApiInboxState(
      category: category,
      unreadOnly: unreadOnly,
      cache: state.cache,
      unread: state.unread,
      marking: state.marking,
    );
    return refresh();
  }

  Future<void> refresh() => _start(false);
  Future<void> loadMore() => _start(true);
  Future<void> _start(bool more) {
    if (_reading case final pending?) {
      if (more || !_readingMore) return pending;
      // Pull-to-refresh replaces pagination and waits for a fresh first page.
      _readRevision++;
      _reading = null;
    }
    _readingMore = more;
    final task = _read(more);
    _reading = task;
    return task.whenComplete(() {
      if (identical(_reading, task)) _reading = null;
    });
  }

  Future<void> _read(bool more) async {
    final identity = _identityRevision;
    final repository = ref.read(apiNotificationRepositoryProvider);
    if (!_current(identity) || repository == null) return;
    final old = state;
    if (more && old.nextCursor == null) return;
    final revision = ++_readRevision;
    bool current() => _current(identity) && revision == _readRevision;
    state = state.copy(loading: true);
    try {
      final page = await RequestScope.runOwned(
        current,
        () => repository.read(
          category: old.category,
          unreadOnly: old.unreadOnly,
          cursor: more ? old.nextCursor : null,
        ),
      );
      if (!current()) return;
      if (page.nextCursor != null &&
          (page.nextCursor == old.nextCursor && more ||
              more && _cursors.contains(page.nextCursor))) {
        throw const VantaApiFailure(vantaApiDataInvalid);
      }
      final items = <String, ApiNotification>{
        if (more)
          for (final item in old.items) item.key: item,
        for (final item in page.items) item.key: item,
      }.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (items.length > 10000) throw const VantaApiFailure(vantaApiDataInvalid);
      if (!more) _cursors.clear();
      if (page.nextCursor != null) _cursors.add(page.nextCursor!);
      final cache = {...state.cache, for (final item in items) item.key: item};
      // Bound retained detail snapshots as well as the visible paginated list.
      while (cache.length > 10000) {
        cache.remove(cache.keys.first);
      }
      state = state.copy(
        items: items,
        cache: cache,
        unread: page.unread,
        loaded: true,
        loading: false,
        nextCursor: page.nextCursor,
        replaceCursor: true,
      );
    } catch (error) {
      if (current()) state = state.copy(loading: false, error: error);
    }
  }

  Future<void> markRead([ApiNotification? entry]) async {
    if (entry?.read == true) return;
    return _markTarget(entry?.readTarget);
  }

  /// Marks one entry by its server identity, for example a tapped push
  /// notification whose entry has not been loaded into this inbox.
  Future<void> markReadTarget(ApiNotificationReadTarget target) => _markTarget(target);

  bool _knownRead(ApiNotificationReadTarget target) => state.cache.values.any(
    (item) =>
        item.read &&
        item.kind == target.kind &&
        (target.kind == ApiNotificationKind.event ? item.key == target.key : item.id == target.id),
  );

  Future<void> _markTarget(ApiNotificationReadTarget? target) async {
    final identity = _identityRevision;
    if (!_current(identity)) return;
    if (_writing case final pending?) {
      await pending;
      if (!_current(identity)) return;
      if (target != null && _knownRead(target)) return;
      return _markTarget(target);
    }
    if (target != null && _knownRead(target)) return;
    final task = _mark(target, identity);
    _writing = task;
    try {
      await task;
    } finally {
      if (identical(_writing, task)) _writing = null;
    }
  }

  Future<void> _mark(ApiNotificationReadTarget? target, int identity) async {
    final repository = ref.read(apiNotificationRepositoryProvider);
    if (repository == null) return;
    final operation = switch (target) {
      null => 'all',
      ApiNotificationReadTarget(kind: ApiNotificationKind.event, :final key) => 'event:$key',
      ApiNotificationReadTarget(:final id) => 'broadcast:$id',
    };
    final key = _writeKeys.putIfAbsent(operation, newIdempotencyKey);
    bool current() => _current(identity);
    state = state.copy(marking: true);
    try {
      await RequestScope.runOwned(
        current,
        () => repository.markRead(target: target, idempotencyKey: key),
      );
      if (!current()) return;
      _writeKeys.remove(operation);
      ApiNotification updated(ApiNotification item) =>
          target == null ||
              target.kind == ApiNotificationKind.event && item.key == target.key ||
              target.kind == ApiNotificationKind.broadcast &&
                  item.kind == ApiNotificationKind.broadcast &&
                  item.id <= target.id
          ? item.asRead()
          : item;
      final cache = {for (final item in state.cache.values) item.key: updated(item)};
      state = state.copy(
        cache: cache,
        items: state.items.map(updated).where((e) => !state.unreadOnly || !e.read),
      );
      // A read response has no global count. Reconcile with a fresh page; never
      // derive the badge from a filtered or partially loaded subset.
      _readRevision++;
      _reading = null;
      await refresh();
    } catch (error) {
      if (current()) state = state.copy(error: error);
    } finally {
      if (current()) state = state.copy(marking: false, error: state.error);
    }
  }
}
