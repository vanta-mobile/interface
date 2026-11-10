import '../../authorization/application/trading_agent_provider.dart';
import '../../../core/network/network_providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_spot_service.dart';
import '../data/signed_spot_history_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/spot_history.dart';
import 'account_read_provider.dart';

final spotHistoryRepositoryProvider = Provider<SpotHistoryRepository>((ref) {
  final service = AsterSpotService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedSpotHistoryRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});
final spotHistoryClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final spotHistoryProvider = NotifierProvider<SpotHistoryController, SpotHistoryState>(
  SpotHistoryController.new,
);

class SpotHistoryController extends Notifier<SpotHistoryState> {
  int _generation = 0, _staleRevision = 0;
  Timer? _expiry;
  SpotHistoryQuery _initialQuery() => SpotHistoryQuery(
    kind: SpotHistoryKind.orders,
    window: HistoryWindow.recent(ref.read(spotHistoryClockProvider)(), const Duration(days: 7)),
  );
  @override
  SpotHistoryState build() {
    ref.listen(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
      (previous, next) {
        if (previous == next) return;
        _generation++;
        _expiry?.cancel();
        state = SpotHistoryState(query: _initialQuery());
      },
    );
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    return SpotHistoryState(query: _initialQuery());
  }

  void selectKind(SpotHistoryKind kind) {
    if (state.busy || kind == state.query.kind) return;
    _configure(
      SpotHistoryQuery(
        kind: kind,
        window: kind == SpotHistoryKind.orders && !state.query.window.fitsRequest
            ? _initialQuery().window
            : state.query.window,
      ),
    );
  }

  void setScope(String scope) {
    if (state.busy || scope.trim() == state.query.scope) return;
    _configure(
      SpotHistoryQuery(kind: state.query.kind, scope: scope.trim(), window: state.query.window),
    );
  }

  void setWindow(HistoryWindow window) {
    if (state.busy) return;
    if (!state.query.inWindow(window).validWindow) {
      state = SpotHistoryState(
        query: state.query,
        account: state.account,
        pending: state.pending,
        truncated: state.truncated,
        stale: state.stale,
        failure: const AccountReadFailure('historyInvalidWindow'),
      );
      return;
    }
    _configure(state.query.inWindow(window));
  }

  void _configure(SpotHistoryQuery query) {
    _generation++;
    _expiry?.cancel();
    state = SpotHistoryState(query: query);
  }

  Future<void> refresh() => _read(refreshing: true);
  Future<void> loadMore() => _read(refreshing: false);

  void stopRead() {
    if (!state.busy) return;
    _generation++;
    state = SpotHistoryState(
      query: state.query,
      account: state.account,
      pending: state.pending,
      truncated: state.truncated,
      stale: state.account != null,
      failure: const AccountReadFailure('historyReadStopped'),
    );
  }

  Future<void> _read({required bool refreshing}) async {
    if (state.busy || (!refreshing && state.pending.isEmpty)) return;
    final previous = state;
    final query = previous.query;
    if (!query.validScope || !query.validWindow) {
      state = SpotHistoryState(
        query: query,
        failure: AccountReadFailure(
          !query.validScope ? 'historyInvalidScope' : 'historyInvalidWindow',
        ),
      );
      return;
    }
    final auth = ref.read(authProvider);
    final identity = auth.identity;
    final address = identity?.walletAddress;
    if (auth.busy || address == null) return;
    if (identity?.signingAvailable != true) {
      state = SpotHistoryState(
        query: query,
        account: previous.account,
        pending: previous.pending,
        truncated: previous.truncated,
        stale: previous.account != null,
        failure: const AccountReadFailure('authWalletReconnect'),
      );
      return;
    }
    final generation = ++_generation;
    final staleRevision = _staleRevision;
    final remaining = refreshing ? query.window : previous.pending.first;
    final window = remaining.latestRequest;
    final requestQuery = query.inWindow(window);
    bool current() =>
        ref.mounted &&
        generation == _generation &&
        ref.read(authProvider).identity?.id == identity?.id &&
        ref.read(authProvider).identity?.walletAddress == address &&
        ref.read(authProvider).identity?.signingAvailable == true;
    void loading(AccountReadStep step) {
      if (current()) {
        state = SpotHistoryState(
          query: query,
          account: previous.account,
          pending: previous.pending,
          truncated: previous.truncated,
          stale: previous.account != null,
          step: step,
        );
      }
    }

    loading(AccountReadStep.preparing);
    try {
      final page = await ref
          .read(spotHistoryRepositoryProvider)
          .read(address: address, query: requestQuery, isCurrent: current, onStep: loading);
      if (!current()) return;
      if (page.query != requestQuery ||
          page.address.toLowerCase() != address.toLowerCase() ||
          page.rawCount < page.records.length ||
          page.rawCount > SpotHistoryPage.limit ||
          page.rawCount < 0 ||
          page.records.any((r) => !_matches(r, requestQuery))) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final records = <String, SpotHistoryRecord>{
        if (!refreshing && previous.account != null)
          for (final r in previous.account!.records) r.key: r,
      };
      for (final record in page.records) {
        final old = records[record.key];
        if (old != null && historyRecordsConflict(old, record)) {
          throw const AccountReadFailure('accountDataInvalid');
        }
        if (old == null || !record.versionTime.isBefore(old.versionTime)) {
          records[record.key] = record;
        }
      }
      final saturated = page.rawCount == SpotHistoryPage.limit;
      final children = saturated ? window.split().reversed.toList() : <HistoryWindow>[];
      final pending = [
        ...children,
        if (window.start > remaining.start) HistoryWindow(remaining.start, window.start - 1),
        if (!refreshing) ...previous.pending.skip(1),
      ];
      state = SpotHistoryState(
        query: query,
        account: SpotHistorySnapshot(
          address: address,
          query: query,
          receivedAt: refreshing ? page.receivedAt : previous.account!.receivedAt,
          records: sortSpotHistory(records.values),
        ),
        pending: pending,
        truncated: (!refreshing && previous.truncated) || (saturated && children.isEmpty),
        stale: staleRevision != _staleRevision || (!refreshing && previous.stale),
      );
      if (refreshing) {
        _expiry?.cancel();
        _expiry = Timer(const Duration(seconds: 30), markStale);
      }
    } catch (error) {
      if (!current()) return;
      state = SpotHistoryState(
        query: query,
        account: previous.account,
        pending: previous.pending,
        truncated: previous.truncated,
        stale: previous.account != null,
        failure: error is AccountReadFailure
            ? error
            : const AccountReadFailure('accountReadFailed'),
      );
    }
  }

  bool _matches(SpotHistoryRecord r, SpotHistoryQuery query) =>
      r.time.millisecondsSinceEpoch >= query.window.start &&
      r.time.millisecondsSinceEpoch <= query.window.end &&
      switch ((query.kind, r)) {
        (SpotHistoryKind.orders, SpotOrderRecord()) =>
          query.scope.isEmpty || r.symbol == query.scope,
        (SpotHistoryKind.trades, SpotTradeRecord()) =>
          query.scope.isEmpty || r.symbol == query.scope,
        (SpotHistoryKind.transactions, SpotTransactionRecord(:final asset)) =>
          query.scope.isEmpty || asset == query.scope,
        _ => false,
      };

  void markStale() {
    _staleRevision++;
    if (!ref.mounted || state.account == null || state.stale) return;
    state = SpotHistoryState(
      query: state.query,
      account: state.account,
      pending: state.pending,
      truncated: state.truncated,
      step: state.step,
      failure: state.failure,
      stale: true,
    );
  }
}
