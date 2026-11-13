import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/auth/data/vanta_api_session_repository.dart';
import 'package:vanta/features/auth/data/vanta_api_session_store.dart';
import 'package:vanta/features/market/application/favorite_symbols_provider.dart';
import 'package:vanta/features/market/data/watchlist_repository.dart';

import '../../support/api_notifications.dart' show InboxAuth, inboxIdentity;
import '../../support/vanta_api.dart';

Map<String, Object?> item(String symbol, int sort, [int minute = 0]) => {
  'symbol': symbol,
  'sort': sort,
  'added_at': DateTime.utc(2026, 11, 12, 8, minute).toIso8601String(),
};

class WatchlistFixture {
  WatchlistFixture({bool signedIn = true}) {
    store.value = VantaApiCredentials(
      address: vantaTestAddress.toLowerCase(),
      accessToken: 'stored',
      refreshToken: 'refresh',
      accessExpiresAt: vantaTestNow.add(const Duration(hours: 1)),
    );
    repository = vantaTestRepository(
      backend,
      store: store,
      signer: signer,
      now: () => vantaTestNow,
    );
    backend.routes['GET /v1/me/watchlist'] = (_) async {
      await readGate?.future;
      if (readFailure) return json({'code': 'internal_error', 'message': 'Watchlist down'}, 503);
      return json({'items': remote, 'count': remote.length});
    };
    backend.routes['POST /v1/me/watchlist'] = (request) async {
      await writeGate?.future;
      if (writeFailure) return json({'code': 'invalid_param', 'message': 'Bad symbol'}, 400);
      final symbol = (jsonDecode(request.body) as Map)['symbol'] as String;
      final added = !remote.any((e) => e['symbol'] == symbol);
      if (added) remote.add(item(symbol, remote.length));
      return json({'symbol': symbol, 'added': added});
    };
    backend.routes['POST /v1/auth/logout'] = (_) => json({});
    container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => auth = InboxAuth(signedIn ? inboxIdentity(vantaTestAddress) : null),
        ),
        vantaApiSessionRepositoryProvider.overrideWithValue(repository),
        vantaApiClockProvider.overrideWithValue(() => vantaTestNow),
      ],
    );
    container.read(authProvider);
    container.listen(favoriteSymbolsProvider, (_, _) {});
  }
  final backend = Backend();
  final signer = KeySigner();
  final store = MemoryStore();
  late final VantaApiSessionRepository repository;
  late final ProviderContainer container;
  late InboxAuth auth;
  final remote = <Map<String, Object?>>[];
  bool readFailure = false, writeFailure = false;
  Completer<void>? readGate, writeGate;
  Set<String> get favorites => container.read(favoriteSymbolsProvider);
  FavoriteSymbolsController get controller => container.read(favoriteSymbolsProvider.notifier);
  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await pumpEventQueue();
    }
  }

  void routeDelete() => backend.routes.addAll({
    for (final symbol in ['BTCUSDT', 'ETHUSDT', 'SOLUSDT'])
      'DELETE /v1/me/watchlist/$symbol': (_) async {
        await writeGate?.future;
        if (writeFailure) return json({'code': 'internal_error', 'message': 'Remove failed'}, 503);
        final before = remote.length;
        remote.removeWhere((e) => e['symbol'] == symbol);
        return json({'symbol': symbol, 'removed': remote.length != before});
      },
  });
}

void main() {
  group('mapWatchlist', () {
    test('orders by sort then added_at', () {
      expect(
        mapWatchlist({
          'items': [item('ETHUSDT', 2), item('SOLUSDT', 1, 5), item('BTCUSDT', 1, 1)],
          'count': 3,
        }),
        ['BTCUSDT', 'SOLUSDT', 'ETHUSDT'],
      );
    });

    test('rejects malformed rows, duplicates and a missing count', () {
      for (final body in [
        {
          'items': [item('ETHUSDT', 1)],
        },
        {
          'items': [
            {'symbol': 'eth-usdt', 'sort': 1, 'added_at': '2026-11-12T08:00:00Z'},
          ],
          'count': 1,
        },
        {
          'items': [
            {'symbol': 'ETHUSDT', 'sort': '1', 'added_at': '2026-11-12T08:00:00Z'},
          ],
          'count': 1,
        },
        {
          'items': [item('ETHUSDT', 1), item('ETHUSDT', 2)],
          'count': 2,
        },
      ]) {
        expect(() => mapWatchlist(body), throwsFormatException, reason: '$body');
      }
    });
  });

  test('a ready session loads the server watchlist', () async {
    final f = WatchlistFixture()..remote.addAll([item('ETHUSDT', 0), item('BTCUSDT', 1)]);
    await f.settle();
    expect(f.favorites, {'ETHUSDT', 'BTCUSDT'});
    expect(f.backend.requests.last.headers['authorization'], 'Bearer stored');
  });

  test('guest favorites stay local and merge into the server list after sign-in', () async {
    final f = WatchlistFixture(signedIn: false)..remote.add(item('BTCUSDT', 0));
    await f.settle();
    await f.controller.toggle('SOLUSDT');
    expect(f.favorites, {'SOLUSDT'});
    expect(f.backend.paths, isNot(contains('POST /v1/me/watchlist')));
    f.auth.setWallet(vantaTestAddress);
    await f.settle();
    expect(f.favorites, {'BTCUSDT', 'SOLUSDT'});
    expect(f.remote.map((e) => e['symbol']), ['BTCUSDT', 'SOLUSDT']);
  });

  test('a failed guest merge keeps the favorite and retries on refresh', () async {
    final f = WatchlistFixture(signedIn: false);
    await f.settle();
    await f.controller.toggle('SOLUSDT');
    f.writeFailure = true;
    f.auth.setWallet(vantaTestAddress);
    await f.settle();
    expect(f.favorites, {'SOLUSDT'});
    expect(f.remote, isEmpty);
    f.writeFailure = false;
    expect(await f.controller.refresh(), isNull);
    expect(f.remote.map((e) => e['symbol']), ['SOLUSDT']);
  });

  test('toggle writes to the server and rolls back with the API failure', () async {
    final f = WatchlistFixture()..routeDelete();
    await f.settle();
    expect(await f.controller.toggle('ETHUSDT'), isNull);
    expect(f.favorites, {'ETHUSDT'});
    expect(f.remote.map((e) => e['symbol']), ['ETHUSDT']);

    f.writeFailure = true;
    f.writeGate = Completer();
    final pending = f.controller.toggle('ETHUSDT');
    expect(f.favorites, isEmpty, reason: 'optimistic');
    f.writeGate!.complete();
    final failure = await pending;
    expect(failure, isA<VantaApiFailure>());
    expect((failure! as VantaApiFailure).details?.message, 'Remove failed');
    expect(f.favorites, {'ETHUSDT'});
  });

  test('rapid toggles are written in order', () async {
    final f = WatchlistFixture()..routeDelete();
    await f.settle();
    f.writeGate = Completer();
    final add = f.controller.toggle('BTCUSDT');
    final remove = f.controller.toggle('BTCUSDT');
    expect(f.favorites, isEmpty);
    f.writeGate!.complete();
    await Future.wait([add, remove]);
    expect(f.backend.paths.where((p) => p.contains('watchlist/') || p.startsWith('POST /v1/me')), [
      'POST /v1/me/watchlist',
      'DELETE /v1/me/watchlist/BTCUSDT',
    ]);
    expect(f.favorites, isEmpty);
    expect(f.remote, isEmpty);
  });

  test('a read failure keeps the current list and is returned by refresh', () async {
    final f = WatchlistFixture()..remote.add(item('BTCUSDT', 0));
    await f.settle();
    f.readFailure = true;
    final failure = await f.controller.refresh();
    expect((failure! as VantaApiFailure).details?.message, 'Watchlist down');
    expect(f.favorites, {'BTCUSDT'});
  });

  test('switching wallets clears the list and cancels the old read', () async {
    final f = WatchlistFixture()..remote.add(item('BTCUSDT', 0));
    f.readGate = Completer();
    await f.settle();
    f.auth.setWallet(null);
    f.readGate!.complete();
    await f.settle();
    expect(f.favorites, isEmpty);
    await f.controller.toggle('ETHUSDT');
    expect(f.favorites, {'ETHUSDT'}, reason: 'guest favorites are local again');
  });
}
