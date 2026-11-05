import 'dart:convert';

/// Original numeric text; never parsed through double, even for integer money.
class FundingJsonNumber {
  const FundingJsonNumber(this.text);
  final String text;
  int? get integer => RegExp(r'^-?(?:0|[1-9]\d*)$').hasMatch(text) ? int.tryParse(text) : null;
}

Object? decodeFundingJson(String source) => _FundingJson(source).decode();

class _FundingJson {
  _FundingJson(this.source);
  final String source;
  int index = 0;
  static final number = RegExp(r'-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?');
  Never invalid() => throw const FormatException();
  void space() {
    while (index < source.length && const [9, 10, 13, 32].contains(source.codeUnitAt(index))) {
      index++;
    }
  }

  Object? decode() {
    if (source.length > 262144) invalid();
    final result = value(0);
    space();
    if (index != source.length) invalid();
    return result;
  }

  bool take(String token) {
    space();
    if (!source.startsWith(token, index)) return false;
    index += token.length;
    return true;
  }

  String string() {
    space();
    final start = index;
    if (!take('"')) invalid();
    while (index < source.length) {
      final char = source.codeUnitAt(index++);
      if (char == 92) {
        index++;
      } else if (char == 34) {
        return jsonDecode(source.substring(start, index)) as String;
      }
    }
    return invalid();
  }

  Object? value(int depth) {
    if (depth > 32) invalid();
    space();
    if (index >= source.length) invalid();
    if (source[index] == '"') return string();
    if (take('{')) {
      final result = <String, dynamic>{};
      if (take('}')) return result;
      do {
        final key = string();
        if (!take(':') || result.containsKey(key)) invalid();
        result[key] = value(depth + 1);
        if (take('}')) return result;
      } while (take(','));
      return invalid();
    }
    if (take('[')) {
      final result = <Object?>[];
      if (take(']')) return result;
      do {
        result.add(value(depth + 1));
        if (take(']')) return result;
      } while (take(','));
      return invalid();
    }
    if (take('true')) return true;
    if (take('false')) return false;
    if (take('null')) return null;
    final raw = number.matchAsPrefix(source, index)?.group(0);
    if (raw == null || raw.length > 160) invalid();
    index += raw.length;
    return FundingJsonNumber(raw);
  }
}
