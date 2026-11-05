enum AssetMetadataSource { names, logos }

/// Display-only information. Never supplies financial precision, permissions,
/// token addresses, prices or signed API asset identifiers.
class AssetMetadata {
  const AssetMetadata({required this.symbol, this.name, this.chineseName, this.logo});
  final String symbol;
  final String? name, chineseName;
  final Uri? logo;
  String? displayName(bool chinese) => chinese ? chineseName ?? name : name;
  bool matches(String query) =>
      [symbol, name, chineseName].whereType<String>().any((s) => s.toLowerCase().contains(query));
}

class AssetMetadataSnapshot {
  AssetMetadataSnapshot({
    required this.source,
    required this.receivedAt,
    required Map<String, AssetMetadata> entries,
  }) : entries = Map.unmodifiable(entries);
  final AssetMetadataSource source;
  final DateTime receivedAt;
  final Map<String, AssetMetadata> entries;
  AssetMetadata? forSymbol(String symbol) => entries[symbol.toUpperCase()];
  bool freshAt(DateTime now) =>
      !now.isBefore(receivedAt.subtract(const Duration(seconds: 30))) &&
      now.isBefore(receivedAt.add(const Duration(minutes: 15)));
}

class AssetMetadataState {
  const AssetMetadataState({
    this.snapshot,
    this.loading = false,
    this.failed = false,
    this.stale = false,
    this.active = true,
  });
  final AssetMetadataSnapshot? snapshot;
  final bool loading, failed, stale, active;
}

abstract interface class AssetMetadataRepository {
  Future<AssetMetadataSnapshot> read(AssetMetadataSource source);
}

/// The official catalogs currently publish PNGs on this specific CDN.
Uri? assetLogoUri(Object? value) {
  if (value is! String || value.isEmpty || value.length > 512) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'static.astherus.finance' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.toString() != value ||
      uri.path.contains('%') ||
      uri.path.contains('..') ||
      uri.path.contains('//') ||
      !RegExp(r'^/image/admin_mgs_image_upload/[A-Za-z0-9_/-]+\.png$').hasMatch(uri.path)) {
    return null;
  }
  return uri;
}
