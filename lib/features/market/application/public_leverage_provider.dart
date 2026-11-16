import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../data/market_http_client.dart';
import '../data/public_leverage_repository.dart';
import '../domain/public_leverage.dart';

final publicLeverageRepositoryProvider = Provider.autoDispose<PublicLeverageRepository>((ref) {
  final client = createMarketHttpClient(client: ref.watch(backendHttpPoolProvider).lease());
  ref.onDispose(client.close);
  final repository = PublicLeverageRepository(client);
  ref.onDispose(repository.dispose);
  return repository;
});

final publicLeverageProvider = FutureProvider.autoDispose<Map<String, PublicLeverage>>(
  retry: (_, _) => null,
  (ref) => ref.watch(publicLeverageRepositoryProvider).read(),
);
