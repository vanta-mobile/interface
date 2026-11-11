import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../data/aster_account_service.dart';
import '../data/signed_open_order_strategy_repository.dart';
import '../domain/aster_open_orders.dart';
import '../domain/open_order_strategy.dart';
import 'account_read_provider.dart';
import 'open_orders_auto_read_provider.dart';
import 'open_orders_provider.dart';

final openOrderStrategyRepositoryProvider = Provider<OpenOrderStrategyRepository>((ref) {
  final service = AsterAccountService(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(service.close);
  return SignedOpenOrderStrategyRepository(
    service,
    ref.watch(identityRepositoryProvider).signWalletRequest,
    nonces: ref.watch(asterReadNoncesProvider),
    authorization: ref.watch(asterRequestAuthorizationProvider),
  );
});

/// TP/SL exits and strategy linkage of open orders, keyed `symbol:orderId`.
/// Filled from the open-order rows when the exchange reports them, otherwise
/// read silently with `strategyOpenOrder` under the active device grant. A
/// strategy is re-read when its order changes or after [_recheck]; failures
/// simply leave the order without TP/SL and are retried on the next snapshot.
final openOrderStrategiesProvider =
    NotifierProvider.autoDispose<OpenOrderStrategiesController, Map<String, OpenOrderStrategy>>(
      OpenOrderStrategiesController.new,
    );

const _recheck = Duration(seconds: 60);

class OpenOrderStrategiesController extends Notifier<Map<String, OpenOrderStrategy>> {
  final _checked = <String, (DateTime?, DateTime)>{};
  Object? _scope;
  int _generation = 0;
  bool _running = false, _again = false;

  @override
  Map<String, OpenOrderStrategy> build() {
    ref.listen(openOrdersReadProvider, (_, _) => _sync());
    ref.listen(tradingAgentProvider, (_, _) => _sync());
    ref.onDispose(() => _generation++);
    scheduleMicrotask(_sync);
    return const {};
  }

  static String key(AsterOpenOrder order) => '${order.symbol}:${order.orderId}';

  void _sync() {
    if (!ref.mounted) return;
    final snapshot = ref.read(openOrdersReadProvider).account;
    final grant = activeTradingGrant(ref);
    final scope = (snapshot?.address.toLowerCase(), grant);
    if (scope != _scope) {
      _scope = scope;
      _generation++;
      _checked.clear();
      if (state.isNotEmpty) state = const {};
    }
    if (snapshot == null) return;
    final live = {for (final order in snapshot.orders) key(order)};
    final kept = {
      for (final order in snapshot.orders) key(order): ?order.strategy,
      for (final entry in state.entries)
        if (live.contains(entry.key)) entry.key: entry.value,
    };
    if (!_sameEntries(kept, state)) state = kept;
    if (grant != null) unawaited(_readMissing(snapshot.address));
  }

  Future<void> _readMissing(String address) async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    final generation = _generation;
    bool current() => ref.mounted && generation == _generation;
    try {
      do {
        _again = false;
        final orders = ref.read(openOrdersReadProvider).account?.orders ?? const [];
        for (final order in orders) {
          if (!current()) return;
          final query = openOrderStrategyQuery(order);
          if (query == null) continue;
          final id = key(order), updated = order.updatedAt ?? order.time;
          final last = _checked[id];
          final now = DateTime.now();
          if (last != null && last.$1 == updated && now.difference(last.$2) < _recheck) continue;
          _checked[id] = (updated, now);
          try {
            final strategy = await ref
                .read(openOrderStrategyRepositoryProvider)
                .read(address: address, order: order, query: query, isCurrent: current);
            if (!current()) return;
            final next = {...state}..remove(id);
            if (strategy != null) next[id] = _merge(order.strategy, strategy);
            state = next;
          } on Object {
            if (!current()) return;
            // Keep the previous result; retry once a later snapshot arrives.
            _checked[id] = (updated, now.subtract(_recheck));
          }
        }
      } while (_again && current());
    } finally {
      _running = false;
      if (_again && ref.mounted) {
        _again = false;
        scheduleMicrotask(_sync);
      }
    }
  }
}

/// Row-reported exit prices win over the strategy read only when present.
OpenOrderStrategy _merge(OpenOrderStrategy? row, OpenOrderStrategy read) => OpenOrderStrategy(
  strategyId: read.strategyId,
  type: read.type ?? row?.type,
  sequence: read.sequence ?? row?.sequence,
  takeProfit: row?.takeProfit ?? read.takeProfit,
  stopLoss: row?.stopLoss ?? read.stopLoss,
);

bool _sameEntries(Map<String, OpenOrderStrategy> a, Map<String, OpenOrderStrategy> b) =>
    a.length == b.length && a.entries.every((e) => identical(b[e.key], e.value));
