import 'package:decimal/decimal.dart';

Decimal fundingMoney(Object? raw) {
  if (raw is! String ||
      raw.length > 160 ||
      !RegExp(r'^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$').hasMatch(raw)) {
    throw const FormatException();
  }
  final parts = raw.toLowerCase().split('e');
  if (parts.length == 2 && (int.tryParse(parts.last)?.abs() ?? 1000) > 160) {
    throw const FormatException();
  }
  final value = Decimal.parse(raw);
  if (value < Decimal.zero) throw const FormatException();
  return value;
}
