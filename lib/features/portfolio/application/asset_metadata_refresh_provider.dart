import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/asset_metadata.dart';
import 'asset_metadata_provider.dart';

/// Await catalog refresh and failed active thumbnails without reloading cached
/// successes or starting image requests for assets that have no consumers.
final assetMetadataRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final catalog = assetMetadataProvider(AssetMetadataSource.logos);
    if (ref.exists(catalog)) await ref.read(catalog.notifier).refresh();
    if (!ref.mounted) return;
    final entries = ref.exists(catalog) ? ref.read(catalog).snapshot?.entries.values : null;
    final tasks = <Future<Object?>>[];
    for (final entry in entries ?? <AssetMetadata>[]) {
      final uri = entry.logo;
      if (uri == null) continue;
      final image = assetLogoProvider(uri);
      if (ref.exists(image) && ref.read(image).hasError) {
        ref.read(assetLogoRetryProvider)(uri);
        tasks.add(ref.read(image.future));
      }
    }
    // Failed decorative images retain their fallback and do not fail the page.
    await Future.wait(tasks.map((task) => task.then<void>((_) {}, onError: (Object _) {})));
  };
});
