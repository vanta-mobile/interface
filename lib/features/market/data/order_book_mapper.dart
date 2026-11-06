import '../domain/market.dart';

List<BookLevel> mapBookLevels(Object? payload, {required bool descending}) {
  if (payload is! List || payload.length > 1000) throw const FormatException('Invalid depth');
  final levels = <BookLevel>[];
  for (final row in payload) {
    if (row is! List || row.length < 2) throw const FormatException('Invalid depth row');
    final price = _number(row[0]), quantity = _number(row[1]);
    if (price <= 0 || quantity < 0) throw const FormatException('Invalid depth value');
    if (quantity > 0) levels.add(BookLevel(price, quantity));
  }
  levels.sort((a, b) => descending ? b.price.compareTo(a.price) : a.price.compareTo(b.price));
  return List.unmodifiable(levels);
}

MarketTrade mapBookTrade(Map<String, Object?> event) {
  final price = _number(event['p']), quantity = _number(event['q']);
  final time = event['T'], maker = event['m'];
  if (price <= 0 || quantity <= 0 || time is! int || time <= 0 || maker is! bool) {
    throw const FormatException('Invalid trade');
  }
  return MarketTrade(price: price, quantity: quantity, buy: !maker, time: time);
}

double _number(Object? raw) {
  final value = raw is num
      ? raw.toDouble()
      : raw is String
      ? double.tryParse(raw)
      : null;
  if (value == null || !value.isFinite) throw const FormatException('Invalid market number');
  return value;
}
