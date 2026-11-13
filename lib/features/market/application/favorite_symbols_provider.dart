import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/request_scope.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../data/watchlist_repository.dart';

final watchlistRepositoryProvider = Provider<WatchlistRepository?>((ref) {
  final session = ref.watch(vantaApiSessionRepositoryProvider);
  return session == null ? null : WatchlistRepository(session);
});

final favoriteSymbolsProvider = NotifierProvider<FavoriteSymbolsController, Set<String>>(
  FavoriteSymbolsController.new,
);

/// Favorites are local while no Vanta session is ready. Once a wallet's session
/// is ready the server watchlist is authoritative and the guest favorites are
/// merged into it (the contract leaves this merge to the client). Another
/// wallet's list is never shown or merged; signing out clears it.
class FavoriteSymbolsController extends Notifier<Set<String>> {
  var _base = <String>{};
  final _intents = <String, (bool, Object)>{};
  final _guestPending = <String>{};
  String? _owner;
  int _revision = 0;
  Future<void> _queue = Future.value();
  Future<Object?>? _loading;

  @override
  Set<String> build() {
    ref.watch(watchlistRepositoryProvider);
    ref.listen(
      vantaApiSessionProvider.select((s) => (s.address, s.ready)),
      (_, _) => unawaited(refresh()),
    );
    ref.listen(
      authProvider.select((s) => (s.identity?.id, s.identity?.walletAddress?.toLowerCase())),
      (_, _) => unawaited(refresh()),
    );
    ref.onDispose(() => _revision++);
    _revision++;
    _owner = null;
    _base = {};
    _intents.clear();
    _guestPending.clear();
    _loading = null;
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(refresh());
    });
    return const {};
  }

  String? _activeOwner() {
    if (ref.read(watchlistRepositoryProvider) == null) return null;
    final session = ref.read(vantaApiSessionProvider);
    final identity = ref.read(authProvider).identity;
    return session.ready && identity?.walletAddress?.toLowerCase() == session.address
        ? '${identity!.id}:${session.address}'
        : null;
  }

  bool _current(int revision, String owner) =>
      ref.mounted && revision == _revision && _activeOwner() == owner;

  void _publish() {
    final next = {..._base, ..._guestPending};
    for (final MapEntry(key: symbol, value: (want, _)) in _intents.entries) {
      want ? next.add(symbol) : next.remove(symbol);
    }
    state = Set.unmodifiable(next);
  }

  /// Reads the server watchlist (merging pending guest favorites first).
  /// Completes after the read settles; returns its failure instead of throwing.
  Future<Object?> refresh() {
    final owner = _activeOwner();
    if (owner != _owner) {
      final guest = _owner == null ? {..._base, ..._guestPending} : <String>{};
      _revision++;
      _owner = owner;
      _intents.clear();
      _guestPending.clear();
      _loading = null;
      _base = {};
      if (owner != null) _guestPending.addAll(guest);
      _publish();
    }
    if (owner == null) return Future.value();
    if (_loading case final loading?) return loading;
    final revision = _revision;
    final task = _enqueue(() => _load(revision, owner));
    _loading = task;
    return task.whenComplete(() {
      if (identical(_loading, task)) _loading = null;
    });
  }

  Future<Object?> _load(int revision, String owner) async {
    final repository = ref.read(watchlistRepositoryProvider);
    if (repository == null || !_current(revision, owner)) return null;
    bool current() => _current(revision, owner);
    try {
      final remote = await RequestScope.runOwned(current, repository.read);
      if (!current()) return null;
      _base = remote.toSet();
      for (final symbol in [..._guestPending]) {
        if (!_base.contains(symbol)) {
          await RequestScope.runOwned(current, () => repository.add(symbol));
          if (!current()) return null;
          _base.add(symbol);
        }
        _guestPending.remove(symbol);
      }
      return null;
    } catch (error) {
      return current() ? error : null;
    } finally {
      if (current()) _publish();
    }
  }

  /// Flips [symbol] immediately. With a session the server write follows in
  /// order; a failure restores the confirmed value and is returned.
  Future<Object?> toggle(String symbol) {
    final want = !state.contains(symbol);
    final owner = _owner;
    if (owner == null) {
      want ? _base.add(symbol) : _base.remove(symbol);
      _publish();
      return Future.value();
    }
    final revision = _revision, token = Object();
    _intents[symbol] = (want, token);
    _guestPending.remove(symbol);
    _publish();
    return _enqueue(() async {
      final repository = ref.read(watchlistRepositoryProvider);
      bool current() => _current(revision, owner);
      if (repository == null || !current()) return null;
      Object? failure;
      try {
        await RequestScope.runOwned(
          current,
          () => want ? repository.add(symbol) : repository.remove(symbol),
        );
        if (current()) want ? _base.add(symbol) : _base.remove(symbol);
      } catch (error) {
        failure = error;
      }
      if (!current()) return null;
      if (identical(_intents[symbol]?.$2, token)) _intents.remove(symbol);
      _publish();
      return failure;
    });
  }

  Future<Object?> _enqueue(Future<Object?> Function() work) {
    final result = _queue.then((_) => work());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}
