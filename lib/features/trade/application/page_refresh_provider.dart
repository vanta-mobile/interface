import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/refresh_batch.dart';
import '../../market/application/market_providers.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/application/asset_index_provider.dart';
import '../../portfolio/application/asset_metadata_provider.dart';
import '../../portfolio/application/asset_yield_provider.dart';
import '../../portfolio/application/open_orders_provider.dart';
import '../../portfolio/application/spot_account_provider.dart';
import '../../portfolio/domain/asset_metadata.dart';
import '../../portfolio/domain/asset_yield.dart';

final pageRefreshProvider = Provider<PageRefreshController>((ref) => PageRefreshController(ref));

class PageRefreshController {
  PageRefreshController(this.ref);
  final Ref ref;
  final _market = RefreshBatch(), _futures = RefreshBatch(), _portfolio = RefreshBatch();

  Future<void> markets() => _market.run([
    () async {
      if (ref.read(instrumentsProvider).value == null) {
        ref.invalidate(instrumentsProvider);
        await ref.read(instrumentsProvider.future);
      }
      if (!ref.mounted) return;
      final repository = ref.read(marketQuotesRepositoryProvider);
      await repository?.refresh();
    },
  ]);

  Future<void> futures() => _futures.run([
    () async {
      if (ref.read(instrumentsProvider).value == null) {
        ref.invalidate(instrumentsProvider);
        await ref.read(instrumentsProvider.future);
      }
      if (!ref.mounted) return;
      await ref.read(marketSyncProvider)?.refresh();
    },
    // Keep wallet prompts sequential and only refresh previously read data.
    () async {
      if (ref.read(accountReadProvider).account != null) {
        await ref.read(accountReadProvider.notifier).refresh();
      }
      if (ref.mounted && ref.read(openOrdersReadProvider).account != null) {
        await ref.read(openOrdersReadProvider.notifier).refresh();
      }
    },
  ]);

  Future<void> portfolio({required bool spot, required bool demo}) => _portfolio.run([
    if (!demo) ...[
      if (ref.exists(assetIndexProvider)) ref.read(assetIndexProvider.notifier).refresh,
      for (final source in AssetMetadataSource.values)
        if (ref.exists(assetMetadataProvider(source)))
          ref.read(assetMetadataProvider(source).notifier).refresh,
      for (final asset in YieldAsset.values)
        if (ref.exists(assetYieldProvider(asset)))
          ref.read(assetYieldProvider(asset).notifier).refresh,
      if (spot && ref.read(spotAccountReadProvider).account != null)
        ref.read(spotAccountReadProvider.notifier).refresh,
      if (!spot && ref.read(accountReadProvider).account != null)
        ref.read(accountReadProvider.notifier).refresh,
    ],
  ]);
}
