import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/asset_metadata_provider.dart';
import '../domain/asset_metadata.dart';

class AssetIdentity extends ConsumerWidget {
  const AssetIdentity({super.key, required this.symbol});
  final String symbol;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(assetMetadataProvider(AssetMetadataSource.names)),
        logos = ref.watch(assetMetadataProvider(AssetMetadataSource.logos));
    final metadata = names.snapshot?.forSymbol(symbol),
        logo = logos.snapshot?.forSymbol(symbol)?.logo ?? metadata?.logo;
    final name = metadata?.displayName(Localizations.localeOf(context).languageCode == 'zh');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AssetLogo(uri: logo),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(symbol, style: Theme.of(context).textTheme.titleMedium),
              if (name != null && name != symbol)
                Text(name, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssetLogo extends ConsumerWidget {
  const _AssetLogo({required this.uri});
  final Uri? uri;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), value = uri;
    Widget fallback({bool retry = false}) => SizedBox(
      width: 44,
      height: 44,
      child: retry
          ? IconButton(
              tooltip: l.assetMetadataRetryIcon,
              onPressed: () => ref.read(assetLogoRetryProvider)(value!),
              icon: const Icon(Icons.broken_image_outlined),
            )
          : Semantics(
              label: l.assetMetadataNoIcon,
              child: const Icon(Icons.token_outlined, color: AppColors.muted),
            ),
    );
    if (value == null) return fallback();
    return ref
        .watch(assetLogoProvider(value))
        .when(
          data: (bytes) => SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Image.memory(
                bytes,
                width: 32,
                height: 32,
                cacheWidth: 96,
                cacheHeight: 96,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback(retry: true),
              ),
            ),
          ),
          loading: () => fallback(),
          error: (_, _) => fallback(retry: true),
        );
  }
}

class AssetMetadataStatus extends ConsumerWidget {
  const AssetMetadataStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        names = ref.watch(assetMetadataProvider(AssetMetadataSource.names)),
        logos = ref.watch(assetMetadataProvider(AssetMetadataSource.logos));
    final loading = names.loading || logos.loading, active = names.active && logos.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l.assetMetadataTitle, style: Theme.of(context).textTheme.bodySmall),
            ),
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton(
              key: const Key('asset-metadata-refresh'),
              tooltip: l.assetMetadataRefresh,
              onPressed: !active || loading
                  ? null
                  : () {
                      for (final s in AssetMetadataSource.values) {
                        ref.read(assetMetadataProvider(s).notifier).refresh();
                      }
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (names.failed)
          Text(l.assetMetadataNamesFailed, style: const TextStyle(color: AppColors.warning)),
        if (logos.failed)
          Text(l.assetMetadataIconsFailed, style: const TextStyle(color: AppColors.warning)),
        if (names.stale || logos.stale)
          Text(l.assetMetadataStale, style: Theme.of(context).textTheme.bodySmall),
        if (!active) Text(l.assetMetadataPaused, style: Theme.of(context).textTheme.bodySmall),
        if (!loading &&
            !names.failed &&
            !logos.failed &&
            names.snapshot?.entries.isEmpty == true &&
            logos.snapshot?.entries.isEmpty == true)
          Text(l.assetMetadataEmpty),
      ],
    );
  }
}
