import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../portfolio/application/asset_metadata_provider.dart';
import '../../portfolio/application/asset_metadata_refresh_provider.dart';
import '../domain/funding_catalog.dart';

final fundingNetworkLogoProvider = FutureProvider.autoDispose.family<Uint8List, int>(
  (ref, chainId) => ref.watch(assetMetadataServiceProvider).networkLogo(chainId),
  retry: (_, _) => null,
);

/// Refresh the catalog and retry failed visible images without discarding
/// successful static thumbnails or starting requests for unused assets.
final fundingIconRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final tasks = <Future<Object?>>[ref.read(assetMetadataRefreshProvider)()];
    for (final id in fundingEvmChainIds) {
      final image = fundingNetworkLogoProvider(id);
      if (ref.exists(image) && ref.read(image).hasError) {
        tasks.add(ref.refresh(image.future));
      }
    }
    // Failed decorative images retain their fallback and never fail funding.
    await Future.wait(tasks.map((task) => task.then<void>((_) {}, onError: (Object _) {})));
  };
});
