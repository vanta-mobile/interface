part of 'order_cancellation_provider.dart';

/// Shares the single-order controller's session revision and action state.
/// This prevents simultaneous single/bulk cancellations or stale confirmations.
mixin BatchOrderCancellation on Notifier<OrderCancellationState> {
  int get _revision;
  set _revision(int value);
  bool _batchStopRequested = false;

  BatchCancelIntent? prepareBatch({String? symbol}) {
    final auth = ref.read(authProvider);
    final identity = auth.identity;
    final read = ref.read(openOrdersReadProvider);
    final snapshot = read.account;
    final address = identity?.walletAddress;
    if (state.busy ||
        state.needsRecheck ||
        auth.busy ||
        read.busy ||
        address == null ||
        identity?.signingAvailable != true ||
        snapshot == null ||
        snapshot.address.toLowerCase() != address.toLowerCase()) {
      return null;
    }
    final symbols =
        snapshot.orders
            .where((o) => symbol == null || o.symbol == symbol)
            .map((o) => o.symbol)
            .toSet()
            .toList()
          ..sort();
    if (symbols.isEmpty) return null;
    return BatchCancelIntent(
      address: address,
      snapshot: snapshot,
      symbols: symbols,
      revision: _revision,
    );
  }

  Future<void> cancelBatch(BatchCancelIntent intent) => _runBatch(intent, checkingOnly: false);

  Future<void> recheckBatch() async {
    final batch = state.batch;
    if (batch == null || !batch.needsRecheck) return;
    await _runBatch(batch.intent, checkingOnly: true);
  }

  void stopBatch() {
    final batch = state.batch;
    if (batch == null || !batch.busy) return;
    _batchStopRequested = true;
    _emitBatch(batch.intent, batch.results, batch.step, batch.currentSymbol);
  }

  Future<void> _runBatch(BatchCancelIntent intent, {required bool checkingOnly}) async {
    if (state.busy || intent.revision != _revision) return;
    final identity = ref.read(authProvider).identity;
    if (ref.read(authProvider).busy ||
        identity?.signingAvailable != true ||
        identity?.walletAddress != intent.address ||
        intent.symbols.isEmpty) {
      return;
    }
    if (!checkingOnly &&
        (state.needsRecheck ||
            !identical(ref.read(openOrdersReadProvider).account, intent.snapshot) ||
            intent.symbols.any((s) => !intent.snapshot.orders.any((o) => o.symbol == s)))) {
      return;
    }
    final previous = state.batch;
    final revision = ++_revision;
    final active = intent.atRevision(revision);
    bool current() =>
        ref.mounted &&
        revision == _revision &&
        ref.read(authProvider).identity?.id == identity?.id &&
        ref.read(authProvider).identity?.walletAddress == intent.address &&
        ref.read(authProvider).identity?.signingAvailable == true;
    final results = checkingOnly && previous != null
        ? {...previous.results}
        : {
            for (final symbol in intent.symbols)
              symbol: BatchSymbolCancellation(symbol: symbol, submitted: false),
          };
    final targets = checkingOnly
        ? results.values.where((r) => r.needsRecheck).map((r) => r.symbol).toList()
        : intent.symbols;
    _batchStopRequested = false;
    _emitBatch(active, results, OrderCancelStep.preparing, targets.firstOrNull);
    final repository = ref.read(batchOrderCancellationRepositoryProvider);
    for (final symbol in targets) {
      if (!current()) return;
      if (_batchStopRequested) break;
      _emitBatch(active, results, OrderCancelStep.preparing, symbol);
      final eventsAtStart = ref.read(openOrdersReadProvider.notifier).eventRevision;
      BatchSymbolCancellation result;
      try {
        final operation = checkingOnly ? repository.recheckSymbol : repository.cancelSymbol;
        result = await operation(
          address: intent.address,
          symbol: symbol,
          originalOrders: intent.snapshot.orders,
          isCurrent: current,
          onStep: (step) {
            if (current()) _emitBatch(active, results, step, symbol);
          },
        );
      } catch (error) {
        if (!current()) return;
        result = BatchSymbolCancellation(
          symbol: symbol,
          submitted: true,
          failure: error is AccountReadFailure
              ? error
              : const AccountReadFailure('accountReadFailed'),
        );
      }
      if (!current()) return;
      final snapshot = result.snapshot;
      if (result.symbol != symbol ||
          (snapshot != null &&
              (!result.submitted ||
                  snapshot.address.toLowerCase() != intent.address.toLowerCase() ||
                  snapshot.orders.any((o) => o.symbol != symbol)))) {
        result = BatchSymbolCancellation(
          symbol: symbol,
          submitted: true,
          failure: const AccountReadFailure('accountDataInvalid'),
        );
      }
      if (ref.read(openOrdersReadProvider.notifier).hasSymbolEventAfter(symbol, eventsAtStart)) {
        result = BatchSymbolCancellation(
          symbol: result.symbol,
          submitted: result.submitted,
          snapshot: result.snapshot,
          failure: result.failure,
          newerOrderEvents: true,
        );
      }
      try {
        _applyBatchResult(result, eventsAtStart);
      } on FormatException {
        ref.read(openOrdersReadProvider.notifier).markStale();
        result = BatchSymbolCancellation(
          symbol: symbol,
          submitted: result.submitted,
          failure: const AccountReadFailure('orderEventsCapacity'),
        );
      }
      results[symbol] = result;
      _emitBatch(active, results, OrderCancelStep.checking, symbol);
      // A refused request or an unconfirmed outcome stops further DELETEs.
      // Remaining symbols are visible as not submitted; they require a new
      // confirmation, even if a later GET resolves the uncertain symbol.
      if (!result.submitted || result.needsRecheck) break;
    }
    if (current()) _emitBatch(active, results, OrderCancelStep.idle, null);
  }

  void _applyBatchResult(BatchSymbolCancellation result, int eventsAtStart) {
    final snapshot = ref.read(openOrdersReadProvider).account;
    final verified = result.snapshot;
    if (snapshot != null && verified != null) {
      ref
          .read(openOrdersReadProvider.notifier)
          .applyVerifiedSnapshot(
            AsterOpenOrders(
              address: snapshot.address,
              receivedAt: snapshot.receivedAt,
              orders: [
                ...snapshot.orders.where((o) => o.symbol != result.symbol),
                ...verified.orders,
              ],
              units: {...snapshot.units, ...verified.units},
              lastEventAt: snapshot.lastEventAt,
            ),
            since: eventsAtStart,
            closed: snapshot.orders
                .where(
                  (o) =>
                      o.symbol == result.symbol &&
                      !verified.orders.any((v) => v.orderId == o.orderId),
                )
                .where(
                  (o) => !ref.read(openOrdersReadProvider.notifier).hasEventAfter(o, eventsAtStart),
                )
                .map((o) => (o.symbol, o.orderId)),
          );
    } else if (result.submitted) {
      ref.read(openOrdersReadProvider.notifier).markStale();
    }
    if (result.submitted) {
      ref.read(accountReadProvider.notifier).markStale();
      ref.read(positionRiskProvider.notifier).markStale();
    }
  }

  void _emitBatch(
    BatchCancelIntent intent,
    Map<String, BatchSymbolCancellation> results,
    OrderCancelStep step,
    String? symbol,
  ) {
    state = OrderCancellationState(
      batch: BatchCancellationState(
        intent: intent,
        results: results,
        step: step,
        currentSymbol: symbol,
        stopRequested: _batchStopRequested,
      ),
    );
  }
}
