import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/asset_metadata_provider.dart';
import '../domain/asset_metadata.dart';

/// Shared display metadata; each consumer retains its own size and fallback.
class AssetTokenLogo extends ConsumerWidget {
  const AssetTokenLogo({
    super.key,
    required this.symbol,
    required this.size,
    required this.fallback,
  });
  final String symbol;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(assetMetadataProvider(AssetMetadataSource.logos));
    final uri = catalog.snapshot?.forSymbol(symbol)?.logo;
    return AssetLogoImage(
      image: uri == null ? null : ref.watch(assetLogoProvider(uri)),
      size: size,
      fallback: fallback,
    );
  }
}

/// Decorative thumbnails keep their slot through loading and decode failures.
class AssetLogoImage extends StatelessWidget {
  const AssetLogoImage({
    super.key,
    required this.image,
    required this.size,
    required this.fallback,
  });
  final AsyncValue<Uint8List>? image;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child:
          image?.when(
            data: (bytes) => Image.memory(
              bytes,
              width: size,
              height: size,
              cacheWidth: (size * 3).ceil(),
              cacheHeight: (size * 3).ceil(),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
            loading: () => fallback,
            error: (_, _) => fallback,
          ) ??
          fallback,
    ),
  );
}
