import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/market_providers.dart';
import '../../market/application/selection_providers.dart';
import '../../market/data/mark_prices_repository.dart';
import '../../market/data/order_reference_prices_repository.dart';
import '../../market/domain/mark_prices.dart';
import '../../market/domain/order_reference_prices.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/live_order.dart';
import '../domain/main_order_capacity.dart';
import '../domain/main_order_pricing.dart';
import 'asset_index_provider.dart';
import 'live_order_provider.dart';
import 'main_order_capacity_provider.dart';
import 'symbol_settings_activity.dart';

/// Keep public streams alive during an expected wallet switch. Receipt expiry
/// still applies after OS suspension; this does not extend any signed lease.
final mainOrderQuotesActiveProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(orderSessionActiveProvider);
});

typedef MainOrderQuoteKey = ({String symbol, bool book});
final mainOrderQuoteRepositoryProvider = Provider.autoDispose
    .family<OrderReferencePricesRepository, MainOrderQuoteKey>((ref, key) {
      final repository = OrderReferencePricesRepository(
        ref.watch(asterServiceProvider),
        key.symbol,
        includeBook: key.book,
        active: ref.read(mainOrderQuotesActiveProvider),
        now: ref.watch(liveOrderClockProvider),
      );
      ref.listen(
        mainOrderQuotesActiveProvider,
        (_, active) => unawaited(repository.setActive(active)),
      );
      ref.listen(quoteReconnectProvider, (_, _) => unawaited(repository.reconnect()));
      ref.onDispose(() => unawaited(repository.dispose()));
      return repository;
    });
final mainOrderQuotesProvider = StreamProvider.autoDispose
    .family<OrderReferencePrices, MainOrderQuoteKey>(
      (ref, key) => ref.watch(mainOrderQuoteRepositoryProvider(key)).events,
      retry: (_, _) => null,
    );

final mainOrderMarksRepositoryProvider = Provider.autoDispose.family<MarkPricesRepository, String>((
  ref,
  symbols,
) {
  final repository = MarkPricesRepository(
    ref.watch(asterServiceProvider),
    symbols.split(',').toSet(),
    active: ref.read(mainOrderQuotesActiveProvider),
    now: ref.watch(liveOrderClockProvider),
  );
  ref.listen(mainOrderQuotesActiveProvider, (_, active) => unawaited(repository.setActive(active)));
  ref.listen(quoteReconnectProvider, (_, _) => unawaited(repository.reconnect()));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});
final mainOrderMarksProvider = StreamProvider.autoDispose.family<MarkPrices, String>(
  (ref, symbols) => ref.watch(mainOrderMarksRepositoryProvider(symbols)).events,
  retry: (_, _) => null,
);

/// Selected quotes before an explicit capacity read; afterwards include every
/// related nonzero position. Zero configuration rows need no price subscription.
({String marks, Set<String> last}) mainOrderPriceScope(
  LiveOrderContext context,
  MainOrderCapacitySnapshot? snapshot,
) {
  final marks = {context.symbol}, last = {context.symbol};
  if (snapshot?.context == context) {
    final multi = snapshot!.assetMode == FuturesAssetMode.multi;
    final eligible = {
      for (final a in snapshot.account.assets)
        if (multi ? a.marginAvailable : a.asset == context.rules.quoteAsset) a.asset,
    };
    for (final p in snapshot.account.positions) {
      if (p.quantity == Decimal.zero || !eligible.contains(p.units.margin)) continue;
      marks.add(p.symbol);
      if (!p.isolated) last.add(p.symbol);
    }
  }
  return (marks: (marks.toList()..sort()).join(','), last: Set.unmodifiable(last));
}

/// Only public transport is started here. Watching never requests a signature.
/// Do not gate on live.busy/current: the same public facts must survive review,
/// signing and the order's own persistent recovery log before transmission.
final mainOrderPricingProvider = Provider.autoDispose<MainOrderPricing>((ref) {
  final context = ref.watch(liveOrderProvider.select((s) => s.context));
  final stale = ref.watch(liveOrderProvider.select((s) => s.stale));
  final identity = ref.watch(
    authProvider.select((s) => (s.identity?.walletAddress, s.identity?.signingAvailable, s.busy)),
  );
  final symbol = ref.watch(symbolProvider);
  final snapshot = ref.watch(mainOrderCapacityProvider.select((s) => s.snapshot));
  final now = ref.watch(liveOrderClockProvider);
  final active = ref.watch(mainOrderQuotesActiveProvider);
  if (context == null ||
      stale ||
      identity.$3 ||
      identity.$2 != true ||
      identity.$1?.toLowerCase() != context.address.toLowerCase() ||
      context.symbol != symbol) {
    return MainOrderMarketData(
      anchor: null,
      marks: MarkPrices(),
      references: const {},
      indices: null,
      active: false,
      now: now,
    );
  }
  final scope = mainOrderPriceScope(context, snapshot);
  final markState = ref.watch(mainOrderMarksProvider(scope.marks));
  final marks = markState.value ?? MarkPrices();
  var unavailable =
      markState.hasError ||
      marks.connection == MarkPriceConnection.offline ||
      scope.marks
          .split(',')
          .any(
            (s) =>
                marks.invalid.contains(s) || marks.snapshotFailed && !marks.quotes.containsKey(s),
          );
  var pending =
      markState.isLoading ||
      marks.connection == MarkPriceConnection.connecting ||
      !markState.hasError &&
          !marks.snapshotFailed &&
          scope.marks.split(',').any((s) => !marks.quotes.containsKey(s));
  final quotes = <String, OrderReferencePrices>{};
  for (final symbol in scope.last) {
    final quoteState = ref.watch(
      mainOrderQuotesProvider((symbol: symbol, book: symbol == context.symbol)),
    );
    final value = quoteState.value;
    unavailable =
        unavailable ||
        quoteState.hasError ||
        value != null &&
            (value.connection == OrderPriceConnection.offline ||
                value.tradeFailed ||
                symbol == context.symbol && value.bookFailed);
    pending =
        pending ||
        quoteState.isLoading ||
        value != null &&
            (value.connection == OrderPriceConnection.connecting ||
                value.trade == null && !value.tradeFailed ||
                symbol == context.symbol && value.book == null && !value.bookFailed);
    if (value != null) quotes[symbol] = value;
  }
  final indices = snapshot?.assetMode == FuturesAssetMode.multi
      ? ref.watch(assetIndexProvider)
      : null;
  return MainOrderMarketData(
    anchor: context,
    marks: marks,
    references: quotes,
    indices: indices != null && indices.active && !indices.failed ? indices.snapshot : null,
    active: active,
    pending: !unavailable && (pending || (indices?.loading == true && indices?.snapshot == null)),
    now: now,
  );
});
