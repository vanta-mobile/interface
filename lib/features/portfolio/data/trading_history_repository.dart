import '../../../core/errors/api_error_details.dart';
import '../../../core/errors/api_error_parser.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/data/vanta_api_session_repository.dart';
import '../domain/trading_history.dart';
import 'trading_history_mapper.dart';

class ApiTradingHistoryRepository implements TradingHistoryRepository {
  const ApiTradingHistoryRepository(this.session);
  final VantaApiSessionRepository session;
  static const paths = {
    TradingHistoryTab.orders: '/v1/history/orders',
    TradingHistoryTab.positions: '/v1/history/positions',
    TradingHistoryTab.trades: '/v1/history/fills',
    TradingHistoryTab.transactions: '/v1/history/income',
  };
  static const transfersPath = '/v1/history/transfers';

  @override
  Future<TradingHistoryPage> read(
    TradingHistoryTab tab, {
    required String address,
    TradingHistoryCursor? cursor,
  }) async {
    final path = paths[tab]!;
    // Each ledger owns its cursor; an exhausted ledger is never restarted.
    final pages = await Future.wait([
      if (cursor == null || cursor.main != null) _page(path, tab, cursor?.main),
      if (tab == TradingHistoryTab.transactions && (cursor == null || cursor.transfers != null))
        _page(transfersPath, tab, cursor?.transfers, transfers: true),
    ]);
    String? main, transfers;
    var partial = false;
    final records = <TradingHistoryRecord>[];
    for (final page in pages) {
      records.addAll(page.records);
      partial |= page.partial;
      if (page.transfers) {
        transfers = page.next;
      } else {
        main = page.next;
      }
    }
    records.sort((a, b) => b.time.compareTo(a.time));
    return TradingHistoryPage(
      address: address,
      records: records,
      partial: partial,
      next: main == null && transfers == null ? null : TradingHistoryCursor(main, transfers),
    );
  }

  Future<_Page> _page(
    String path,
    TradingHistoryTab tab,
    String? cursor, {
    bool transfers = false,
  }) async {
    final json = await session.get(path, query: {'limit': '100', 'cursor': ?cursor});
    if (json['code'] case final String code) {
      throw VantaApiFailure(
        vantaApiRequestFailed,
        code: code,
        details: ApiErrorDetails(
          message: safeApiMessage(json['message']),
          status: 200,
          endpoint: path,
        ),
      );
    }
    try {
      final next = json['next_cursor'];
      if (!json.containsKey('next_cursor') ||
          next != null && (next is! String || next.isEmpty) ||
          json['partial'] is! bool ||
          (!transfers && json['symbol_filter_ignored'] is! bool) ||
          next != null && next == cursor) {
        throw const FormatException();
      }
      return _Page(
        mapTradingHistory(json['items'], tab, transfers: transfers, pageKey: cursor ?? 'first'),
        next as String?,
        json['partial']! as bool,
        transfers,
      );
    } on FormatException {
      throw VantaApiFailure(
        vantaApiDataInvalid,
        details: ApiErrorDetails(cause: ApiErrorCause.invalidResponse, endpoint: path),
      );
    }
  }
}

class _Page {
  const _Page(this.records, this.next, this.partial, this.transfers);
  final List<TradingHistoryRecord> records;
  final String? next;
  final bool partial, transfers;
}
