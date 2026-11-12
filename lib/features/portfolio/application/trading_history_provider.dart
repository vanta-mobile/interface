import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/network/request_scope.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../data/aster_account_service.dart';
import '../data/trading_history_repository.dart';
import '../data/aster_trading_history_repository.dart';
import '../domain/trading_history.dart';
import 'account_read_provider.dart';
import 'futures_history_provider.dart';
import 'trading_history_access_provider.dart';

final asterTradingHistoryRepositoryProvider = Provider<AsterTradingHistoryRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return AsterTradingHistoryRepository(
    service: service,
    sign: ref.watch(identityRepositoryProvider).signWalletRequest,
    authorization: ref.watch(asterRequestAuthorizationProvider),
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(futuresHistoryClockProvider),
  );
});

final tradingOrderFillsRepositoryProvider = Provider<TradingOrderFillsRepository>(
  (ref) => ref.watch(asterTradingHistoryRepositoryProvider),
);

final tradingHistoryRepositoryProvider = Provider<TradingHistoryRepository?>((ref) {
  final session = ref.watch(vantaApiSessionRepositoryProvider);
  return session == null ? null : ApiTradingHistoryRepository(session);
});

final tradingHistorySourceProvider = Provider.autoDispose
    .family<TradingHistoryRepository?, TradingHistoryTab>(
      (ref, tab) => historyUsesAster(tab)
          ? ref.watch(asterTradingHistoryRepositoryProvider)
          : ref.watch(tradingHistoryRepositoryProvider),
    );

class TradingHistoryState {
  const TradingHistoryState({this.page, this.busy = false, this.error});
  final TradingHistoryPage? page;
  final bool busy;
  final Object? error;
  bool get hasError => error != null;
}

final tradingHistoryProvider = NotifierProvider.autoDispose
    .family<TradingHistoryController, TradingHistoryState, TradingHistoryTab>(
      TradingHistoryController.new,
    );

class TradingHistoryController extends Notifier<TradingHistoryState> {
  TradingHistoryController(this.tab);
  final TradingHistoryTab tab;
  int _revision = 0;
  Future<void>? _pending;
  final _seenCursors = <(String?, String?)>{};
  @override
  TradingHistoryState build() {
    final session = ref.read(tradingHistoryAccessProvider(tab));
    ref.listen(tradingHistoryAccessProvider(tab), (previous, next) {
      if (!next.ready) {
        // Access loss aborts transport through current(), but retain its typed
        // failure when Aster revokes a grant during that same request.
        state = TradingHistoryState(error: state.error);
      } else if (previous?.ready != true) {
        scheduleMicrotask(() {
          if (ref.mounted) unawaited(refresh());
        });
      }
    });
    ref.watch(tradingHistoryIdentityProvider);
    ref.watch(tradingHistorySourceProvider(tab));
    final revision = ++_revision;
    _pending = null;
    _seenCursors.clear();
    ref.onDispose(() => _revision++);
    if (session.ready) {
      scheduleMicrotask(() {
        if (ref.mounted && revision == _revision) unawaited(refresh());
      });
    }
    return TradingHistoryState(busy: session.ready);
  }

  Future<void> refresh() => _start(false);
  Future<void> loadMore() => _start(true);
  Future<void> _start(bool more) {
    if (_pending case final pending?) return pending;
    final task = _read(more);
    _pending = task;
    return task.whenComplete(() {
      if (identical(_pending, task)) _pending = null;
    });
  }

  Future<void> _read(bool more) async {
    final session = ref.read(tradingHistoryAccessProvider(tab));
    final repository = ref.read(tradingHistorySourceProvider(tab));
    final identity = ref.read(tradingHistoryIdentityProvider);
    if (!session.ready || session.address == null || repository == null) {
      state = const TradingHistoryState();
      return;
    }
    final old = state.page;
    if (more && old?.next == null) return;
    if (!more) _seenCursors.clear();
    final revision = ++_revision;
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        ref.read(tradingHistoryIdentityProvider) == identity &&
        ref.read(tradingHistoryAccessProvider(tab)).address == session.address &&
        ref.read(tradingHistoryAccessProvider(tab)).ready;
    state = TradingHistoryState(page: old, busy: true);
    try {
      final page = await RequestScope.runOwned(
        current,
        () => repository.read(tab, address: session.address!, cursor: more ? old?.next : null),
      );
      if (!current()) return;
      if (page.address != session.address) throw const VantaApiFailure(vantaApiDataInvalid);
      if (page.next case final next?) {
        if (_seenCursors.contains((next.main, next.transfers))) {
          throw const VantaApiFailure(vantaApiDataInvalid);
        }
      }
      final records = <String, TradingHistoryRecord>{
        if (more)
          for (final r in old!.records) r.key: r,
        for (final r in page.records) r.key: r,
      }.values.toList()..sort((a, b) => b.time.compareTo(a.time));
      if (records.length > 10000) {
        throw const VantaApiFailure('futuresHistoryCapacity');
      }
      if (page.next case final next?) {
        _seenCursors.add((next.main, next.transfers));
      }
      state = TradingHistoryState(
        page: TradingHistoryPage(
          address: page.address,
          records: records,
          next: page.next,
          partial: page.partial || more && old!.partial,
          recentDays: page.recentDays,
        ),
      );
    } catch (error) {
      if (ref.mounted &&
          revision == _revision &&
          ref.read(tradingHistoryIdentityProvider) == identity) {
        state = TradingHistoryState(page: current() ? old : null, error: error);
      }
    }
  }
}

/// Metadata is independent of private history; missing units remain unknown.
final tradingHistoryUnitsProvider = FutureProvider.autoDispose((ref) async {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return RequestScope.runOwned(() => ref.mounted, service.contractUnits);
}, retry: (_, _) => null);
