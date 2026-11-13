import '../../../core/errors/api_error_details.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/data/vanta_api_session_repository.dart';

/// The signed-in principal's remote watchlist (`/v1/me/watchlist`). It is
/// user scoped, so switching sub-accounts does not change it.
class WatchlistRepository {
  const WatchlistRepository(this.session);
  final VantaApiSessionRepository session;
  static const path = '/v1/me/watchlist';

  /// Symbols in the server's explicit `sort` order (ties by `added_at`).
  Future<List<String>> read() async {
    final json = await session.get(path);
    try {
      return mapWatchlist(json);
    } on FormatException {
      throw _invalid(path);
    }
  }

  /// Idempotent: an existing entry answers `added=false`.
  Future<void> add(String symbol) async {
    final json = await session.postStateful(path, body: {'symbol': symbol});
    if (json['symbol'] case final value? when value != symbol) throw _invalid(path);
    if (json['added'] case final value? when value is! bool) throw _invalid(path);
  }

  /// Idempotent: removing an absent entry answers `removed=false`.
  Future<void> remove(String symbol) async {
    final target = '$path/${Uri.encodeComponent(symbol)}';
    final json = await session.deleteStateful(target);
    if (json['symbol'] case final value? when value != symbol) throw _invalid(target);
    if (json['removed'] case final value? when value is! bool) throw _invalid(target);
  }

  static VantaApiFailure _invalid(String endpoint) => VantaApiFailure(
    vantaApiDataInvalid,
    details: ApiErrorDetails(cause: ApiErrorCause.invalidResponse, endpoint: endpoint),
  );
}

final _symbol = RegExp(r'^[A-Z0-9]{1,40}$');

List<String> mapWatchlist(Map<String, Object?> json) {
  final items = json['items'];
  if (items is! List || json['count'] is! int) throw const FormatException('watchlist');
  final rows = <(String, int, DateTime)>[];
  final seen = <String>{};
  for (final item in items) {
    if (item is! Map<String, Object?>) throw const FormatException('watchlist item');
    final symbol = item['symbol'], sort = item['sort'], added = item['added_at'];
    if (symbol is! String || !_symbol.hasMatch(symbol) || sort is! int || added is! String) {
      throw const FormatException('watchlist item');
    }
    if (!seen.add(symbol)) throw const FormatException('duplicate watchlist symbol');
    rows.add((symbol, sort, DateTime.parse(added)));
  }
  rows.sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$3.compareTo(b.$3));
  return [for (final row in rows) row.$1];
}
