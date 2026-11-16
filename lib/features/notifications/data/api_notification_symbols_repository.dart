import '../../../core/errors/api_error_details.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../core/vanta_api/vanta_api_http.dart';
import '../domain/api_notification.dart';

class ApiNotificationSymbolsRepository {
  const ApiNotificationSymbolsRepository(this.http);
  final VantaApiHttp http;

  Future<Map<String, NotificationSymbolUnits>> read() async {
    const path = '/v1/symbols';
    final json = await http.get(path);
    try {
      final items = json['items'];
      if (items is! List) throw const FormatException();
      final result = <String, NotificationSymbolUnits>{};
      String? text(Object? value) {
        if (value == null) return null;
        if (value is! String ||
            !RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(value)) {
          throw const FormatException();
        }
        return value;
      }

      for (final item in items) {
        if (item is! Map<String, Object?>) throw const FormatException();
        final symbol = text(item['aster_symbol']);
        if (symbol == null) throw const FormatException();
        final units = NotificationSymbolUnits(
          base: text(item['base_asset']),
          quote: text(item['quote_asset']),
        );
        final old = result[symbol];
        if (old != null && (old.base != units.base || old.quote != units.quote)) {
          throw const FormatException();
        }
        result[symbol] = units;
      }
      return Map.unmodifiable(result);
    } on FormatException {
      throw const VantaApiFailure(
        vantaApiDataInvalid,
        details: ApiErrorDetails(cause: ApiErrorCause.invalidResponse, endpoint: path),
      );
    }
  }

  void close() => http.close();
}
