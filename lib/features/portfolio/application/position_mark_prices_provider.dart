import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_providers.dart';
import '../../market/data/mark_prices_repository.dart';
import '../../market/domain/mark_prices.dart';
import 'position_risk_provider.dart';

/// Only the risk screen consumes this provider. Leaving the screen or losing
/// its account scope closes the public subscription and freshness timers.
final positionMarkRepositoryProvider = Provider.autoDispose<MarkPricesRepository?>((ref) {
  final scope = ref.watch(
    positionRiskProvider.select((s) {
      final symbols =
          s.account?.positions.where((p) => !p.balanceOnly).map((p) => p.symbol).toSet().toList() ??
          <String>[];
      symbols.sort();
      return (s.account?.address, symbols.join(','));
    }),
  );
  if (scope.$1 == null || scope.$2.isEmpty) return null;
  final symbols = scope.$2.split(',').toSet();
  final repository = MarkPricesRepository(
    ref.watch(asterServiceProvider),
    symbols,
    active: ref.read(quoteUpdatesActiveProvider),
  );
  ref.listen(quoteUpdatesActiveProvider, (_, active) => unawaited(repository.setActive(active)));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

final positionMarkPricesProvider = StreamProvider.autoDispose<MarkPrices>(retry: (_, _) => null, (
  ref,
) {
  final repository = ref.watch(positionMarkRepositoryProvider);
  return repository?.events ?? Stream.value(MarkPrices());
});
