import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/api_error_parser.dart';
import '../../../core/market_failure.dart';
import '../domain/public_leverage.dart';

class PublicLeverageRepository {
  PublicLeverageRepository(this.client);
  final http.Client client;

  Future<Map<String, PublicLeverage>> read() async {
    final response = await client.post(
      Uri.https('www.asterdex.com', '/bapi/futures/v1/friendly/future/common/brackets'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    if (response.statusCode != 200) {
      throw MarketFailure(
        'Aster HTTP ${response.statusCode}',
        details: apiErrorDetails(decodeErrorPayload(response.body), status: response.statusCode),
      );
    }
    return mapPublicLeverage(jsonDecode(response.body));
  }
}

Map<String, PublicLeverage> mapPublicLeverage(Object? payload) {
  if (payload is! Map || payload['success'] != true || payload['code'] != '000000') {
    throw MarketFailure('Invalid Aster public risk response', details: apiErrorDetails(payload));
  }
  final data = payload['data'];
  if (data is! Map || data['brackets'] is! List) {
    throw const FormatException('Missing public risk brackets');
  }
  final result = <String, PublicLeverage>{};
  for (final item in data['brackets'] as List) {
    if (item is! Map || item['symbol'] is! String || item['riskBrackets'] is! List) {
      throw const FormatException('Invalid public risk market');
    }
    final symbol = item['symbol'] as String;
    if (symbol.isEmpty ||
        symbol.length > 80 ||
        symbol.trim() != symbol ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(symbol) ||
        result.containsKey(symbol)) {
      throw const FormatException('Invalid or duplicate public risk symbol');
    }
    final ranges = <(int, int)>[];
    for (final row in item['riskBrackets'] as List) {
      if (row is! Map) throw const FormatException('Invalid public risk bracket');
      final minimum = row['minOpenPosLeverage'], maximum = row['maxOpenPosLeverage'];
      if (minimum is! int ||
          maximum is! int ||
          minimum < 1 ||
          maximum > 1000 ||
          minimum > maximum) {
        throw const FormatException('Invalid public leverage range');
      }
      ranges.add((minimum, maximum));
    }
    if (ranges.isEmpty) throw const FormatException('Empty public leverage ranges');
    result[symbol] = PublicLeverage(ranges);
  }
  return Map.unmodifiable(result);
}
