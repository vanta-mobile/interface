import '../domain/market_descriptor.dart';

/// Labels are optional enrichment. Malformed optional labels do not hide a
/// tradable contract or turn search keywords into inferred classifications.
MarketDescriptor mapMarketDescriptor(Map<String, dynamic> payload) {
  String? label(Object? value) =>
      value is String &&
          value.trim().isNotEmpty &&
          value.length <= 100 &&
          !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)
      ? value.trim()
      : null;
  Iterable<String> labels(Object? value) =>
      value is List<dynamic> ? value.take(128).map(label).whereType<String>().toSet() : const [];
  return MarketDescriptor(
    name: label(payload['name']) ?? '',
    aliases: labels(payload['tags']),
    categories: labels(payload['underlyingSubType']),
  );
}
