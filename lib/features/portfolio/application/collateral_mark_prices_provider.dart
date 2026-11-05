import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_providers.dart';
import '../../market/data/mark_prices_repository.dart';
import '../../market/domain/mark_prices.dart';
import '../domain/aster_account.dart';
import '../domain/asset_collateral.dart';

typedef CollateralMarkScope = ({String address, String symbols});

/// Derive a stable account-wide scope from the already loaded snapshot. Cards
/// share one subscription; quantity changes alone do not replace the transport.
CollateralMarkScope collateralMarkScope(String address, Iterable<AsterPosition> positions) {
  final symbols =
      positions
          .where((p) => p.quantity != Decimal.zero && supportsCollateralMarkPnl(p))
          .map((p) => p.symbol)
          .toSet()
          .toList()
        ..sort();
  return (address: address.toLowerCase(), symbols: symbols.join(','));
}

/// Public transport only. Consuming a loaded account card must never initialize
/// private account reads, authentication, or a wallet signing workflow.
final collateralMarkRepositoryProvider = Provider.autoDispose
    .family<MarkPricesRepository?, CollateralMarkScope>((ref, scope) {
      if (scope.address.isEmpty || scope.symbols.isEmpty) return null;
      final repository = MarkPricesRepository(
        ref.watch(asterServiceProvider),
        scope.symbols.split(',').toSet(),
        active: ref.read(quoteUpdatesActiveProvider),
      );
      ref.listen(
        quoteUpdatesActiveProvider,
        (_, active) => unawaited(repository.setActive(active)),
      );
      ref.onDispose(() => unawaited(repository.dispose()));
      return repository;
    });

final collateralMarkPricesProvider = StreamProvider.autoDispose
    .family<MarkPrices, CollateralMarkScope>(
      (ref, scope) =>
          ref.watch(collateralMarkRepositoryProvider(scope))?.events ?? Stream.value(MarkPrices()),
      retry: (_, _) => null,
    );
