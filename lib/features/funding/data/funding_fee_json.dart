import 'funding_json.dart';

/// Fee monetary fields accept exact decimal strings as well as JSON numbers.
Object? decodeFundingFeeJson(String source) {
  Object? normalize(Object? value) => switch (value) {
    FundingJsonNumber(:final text) => text,
    List<Object?> list => list.map(normalize).toList(),
    Map<String, dynamic> map => map.map((key, value) => MapEntry(key, normalize(value))),
    _ => value,
  };
  final payload = normalize(decodeFundingJson(source));
  if (payload is Map<String, dynamic>) {
    final code = payload['code'];
    if (code is String && RegExp(r'^-[1-9]\d{0,9}$').hasMatch(code)) {
      payload['code'] = int.parse(code);
    }
  }
  return payload;
}
