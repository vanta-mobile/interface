import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_futures_history_repository.dart';
import '../domain/account_snapshot.dart';
import '../domain/futures_history.dart';
import '../domain/futures_history_merge.dart';
import 'account_change_provider.dart';
import 'account_read_provider.dart';

final futuresHistoryRepositoryProvider = Provider<FuturesHistoryRepository>((ref) {
  final service = AsterAccountService();
  ref.onDispose(service.close);
  return SignedFuturesHistoryRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    now: ref.watch(futuresHistoryClockProvider),
  );
});
final futuresHistoryClockProvider = Provider<DateTime Function()>((_) => DateTime.now);
final futuresHistoryProvider = NotifierProvider<FuturesHistoryController, FuturesHistoryState>(
  FuturesHistoryController.new,
);

class FuturesHistoryController extends Notifier<FuturesHistoryState> {
  int _generation = 0, _staleRevision = 0;
  Timer? _expiry;
  FuturesHistoryQuery _initialQuery() => FuturesHistoryQuery(
    kind: FuturesHistoryKind.orders,
    window: HistoryWindow.recent(ref.read(futuresHistoryClockProvider)(), const Duration(days: 7)),
  );
  @override
  FuturesHistoryState build() {
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
        state = FuturesHistoryState(query: _initialQuery());
      },
    );
    ref.listen(accountChangeProvider.select((s) => s.lastEventAt), (a, b) {
      if (a != b) markStale();
    });
    ref.onDispose(() {
      _generation++;
      _expiry?.cancel();
    });
    return FuturesHistoryState(query: _initialQuery());
  }

  void selectKind(FuturesHistoryKind kind) {
    if (state.busy || kind == state.query.kind) return;
    _configure(
      FuturesHistoryQuery(kind: kind, window: state.query.window, symbol: state.query.symbol),
    );
  }

  void setSymbol(String value) {
    if (state.busy || value.trim() == state.query.symbol) return;
    _configure(
      FuturesHistoryQuery(
        kind: state.query.kind,
        window: state.query.window,
        symbol: value.trim(),
        incomeType: state.query.incomeType,
      ),
    );
  }

  void setIncomeType(String value) {
    if (state.busy ||
        state.query.kind != FuturesHistoryKind.income ||
        value == state.query.incomeType) {
      return;
    }
    _configure(
      FuturesHistoryQuery(
        kind: state.query.kind,
        window: state.query.window,
        symbol: state.query.symbol,
        incomeType: value,
      ),
    );
  }

  void setWindow(HistoryWindow window) {
    if (state.busy) return;
    if (!window.valid) {
      state = FuturesHistoryState(
        query: state.query,
        account: state.account,
        pending: state.pending,
        truncated: state.truncated,
        stale: state.stale,
        failure: const AccountReadFailure('futuresHistoryInvalidWindow'),
      );
      return;
    }
    _configure(state.query.inWindow(window));
  }

  void _configure(FuturesHistoryQuery query) {
    _generation++;
    _expiry?.cancel();
    state = FuturesHistoryState(query: query);
  }

  Future<void> refresh() => _read(refreshing: true);
  Future<void> loadMore() => _read(refreshing: false);

  void stopRead() {
    if (!state.busy) return;
    _generation++;
    _expiry?.cancel();
    state = FuturesHistoryState(
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
    if (!query.valid) {
      state = FuturesHistoryState(
        query: query,
        failure: AccountReadFailure(
          !query.validSymbol
              ? 'futuresHistoryInvalidSymbol'
              : !query.validIncomeType
              ? 'futuresHistoryInvalidType'
              : 'futuresHistoryInvalidWindow',
        ),
      );
      return;
    }
    final auth = ref.read(authProvider);
    final identity = auth.identity;
    final address = identity?.walletAddress;
    if (auth.busy || address == null) return;
    if (identity?.signingAvailable != true) {
      state = FuturesHistoryState(
        query: query,
        account: previous.account,
        pending: previous.pending,
        truncated: previous.truncated,
        stale: previous.account != null,
        failure: const AccountReadFailure('authWalletReconnect'),
      );
      return;
    }
    if (refreshing) _expiry?.cancel();
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
        ref.read(authProvider).identity?.signingAvailable == true &&
        ref.read(authProvider).identity?.walletKind == identity?.walletKind;
    void loading(AccountReadStep step) {
      if (current()) {
        state = FuturesHistoryState(
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
          .read(futuresHistoryRepositoryProvider)
          .read(address: address, query: requestQuery, isCurrent: current, onStep: loading);
      if (!current()) return;
      final age = ref.read(futuresHistoryClockProvider)().difference(page.receivedAt);
      if (page.query != requestQuery ||
          age.isNegative ||
          page.address.toLowerCase() != address.toLowerCase() ||
          page.rawCount < page.records.length ||
          page.rawCount > FuturesHistoryPage.limit ||
          page.rawCount < 0 ||
          page.records.any((r) => !futuresHistoryMatches(r, requestQuery))) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final records = mergeFuturesHistory(
        !refreshing ? previous.account?.records ?? const [] : const [],
        page.records,
      );
      if (records.length > 10000) throw const AccountReadFailure('futuresHistoryCapacity');
      final saturated = page.rawCount == FuturesHistoryPage.limit;
      final children = saturated ? window.split().reversed.toList() : <HistoryWindow>[];
      final pending = [
        ...children,
        if (window.start > remaining.start) HistoryWindow(remaining.start, window.start - 1),
        if (!refreshing) ...previous.pending.skip(1),
      ];
      state = FuturesHistoryState(
        query: query,
        account: FuturesHistorySnapshot(
          address: address,
          query: query,
          receivedAt: refreshing ? page.receivedAt : previous.account!.receivedAt,
          records: records,
        ),
        pending: pending,
        truncated: (!refreshing && previous.truncated) || (saturated && children.isEmpty),
        stale:
            staleRevision != _staleRevision ||
            age >= const Duration(seconds: 30) ||
            (!refreshing && previous.stale),
      );
      if (refreshing) {
        _expiry?.cancel();
        _expiry = Timer(
          age >= const Duration(seconds: 30) ? Duration.zero : const Duration(seconds: 30) - age,
          markStale,
        );
      }
    } catch (error) {
      if (!current()) return;
      state = FuturesHistoryState(
        query: query,
        account: previous.account,
        pending: previous.pending,
        truncated: previous.truncated,
        stale: previous.account != null,
        failure: error is AccountReadFailure
            ? error
            : AccountReadFailure(
                error is FormatException ? 'accountDataInvalid' : 'accountReadFailed',
              ),
      );
    }
  }

  void markStale() {
    _staleRevision++;
    if (!ref.mounted || state.account == null || state.stale) return;
    state = FuturesHistoryState(
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
