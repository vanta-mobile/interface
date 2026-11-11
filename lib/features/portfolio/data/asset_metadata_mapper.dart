import '../domain/asset_metadata.dart';

AssetMetadataSnapshot mapAssetMetadata(
  Object? payload, {
  required AssetMetadataSource source,
  required DateTime receivedAt,
}) {
  if (payload is! Map<String, dynamic> ||
      payload['code'] != '000000' ||
      (payload.containsKey('success') && payload['success'] != true) ||
      payload['data'] is! List ||
      (payload['data'] as List).length > 5000) {
    throw const FormatException();
  }
  final entries = <String, AssetMetadata>{};
  String? name(Object? value) {
    if (value == null || value == '') return null;
    if (value is! String ||
        value.length > 120 ||
        RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]').hasMatch(value)) {
      throw const FormatException();
    }
    return value.trim().isEmpty ? null : value.trim();
  }

  for (final row in payload['data'] as List) {
    if (row is! Map<String, dynamic>) throw const FormatException();
    final symbol = row['assetCode'];
    if (symbol is! String ||
        symbol.isEmpty ||
        symbol.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(symbol)) {
      throw const FormatException();
    }
    // The public logo catalog also contains protocol/points labels with spaces.
    // They cannot match an account asset identifier; do not invent aliases.
    if (!RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(symbol)) continue;
    final key = symbol.toUpperCase();
    if (entries.containsKey(key)) throw const FormatException();
    entries[key] = AssetMetadata(
      symbol: symbol,
      name: source == AssetMetadataSource.names ? name(row['assetName']) : null,
      chineseName: source == AssetMetadataSource.names ? name(row['chineseName']) : null,
      logo: assetLogoUri(row['logoUrl']),
    );
  }
  return AssetMetadataSnapshot(source: source, receivedAt: receivedAt.toUtc(), entries: entries);
}
