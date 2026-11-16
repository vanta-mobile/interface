import '../../../core/errors/api_error_details.dart';
import '../../../core/errors/api_error_parser.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../auth/data/vanta_api_session_repository.dart';
import '../domain/trading_history.dart';
import 'trading_history_mapper.dart';

class ApiTradingHistoryRepository
    implements
        TradingHistoryRepository,
        TradingOrderFillsRepository,
        TradingPositionOrdersRepository {
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
    // Income is the backend's merged ledger. Appending transfers would count
    // reported deposit/withdraw/transfer income twice without a shared identity.
    final page = await _page(path, tab, cursor?.main);
    return TradingHistoryPage(
      address: address,
      records: page.records,
      partial: page.partial,
      next: page.next == null ? null : TradingHistoryCursor(page.next),
    );
  }

  @override
  Future<TradingHistoryPage> readOrderFills(
    HistoryOrder order, {
    required String address,
    TradingHistoryCursor? cursor,
  }) async {
    // The server filters the order; still validate exact symbol + order ID
    // locally, because symbol filtering is explicitly unsupported.
    final page = await _page(
      paths[TradingHistoryTab.trades]!,
      TradingHistoryTab.trades,
      cursor?.main,
      orderId: order.id,
    );
    return TradingHistoryPage(
      address: address,
      records: page.records.whereType<HistoryFill>().where(
        (f) => f.symbol == order.symbol && f.orderId == order.id,
      ),
      partial: page.partial,
      next: page.next == null ? null : TradingHistoryCursor(page.next),
    );
  }

  @override
  Future<List<HistoryOrder>> readPositionOrders(HistoryPosition position) async {
    final path = '/v1/history/positions/${position.id}/orders';
    final json = await session.get(path);
    _checkBusinessFailure(json, path);
    try {
      if (json['position_id'] is! int || '${json['position_id']}' != position.id) {
        throw const FormatException();
      }
      final items = json['items'];
      // This endpoint returns the complete list without pagination or a limit.
      if (items is! List) throw const FormatException();
      final orders = <HistoryOrder>[];
      final keys = <String>{};
      for (final item in items) {
        final order = mapTradingHistory([item], TradingHistoryTab.orders).single as HistoryOrder;
        if (order.symbol != position.symbol || !keys.add(order.key)) throw const FormatException();
        orders.add(order);
      }
      orders.sort((a, b) => b.time.compareTo(a.time));
      return List.unmodifiable(orders);
    } on FormatException {
      throw VantaApiFailure(
        vantaApiDataInvalid,
        details: ApiErrorDetails(cause: ApiErrorCause.invalidResponse, endpoint: path),
      );
    }
  }

  void _checkBusinessFailure(Map<String, Object?> json, String path) {
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
  }

  Future<_Page> _page(String path, TradingHistoryTab tab, String? cursor, {String? orderId}) async {
    final json = await session.get(
      path,
      query: {'limit': '100', 'cursor': ?cursor, 'order_id': ?orderId},
    );
    _checkBusinessFailure(json, path);
    try {
      final next = json['next_cursor'];
      if (!json.containsKey('next_cursor') ||
          next != null && (next is! String || next.isEmpty) ||
          json['partial'] is! bool ||
          json['symbol_filter_ignored'] is! bool ||
          next != null && next == cursor) {
        throw const FormatException();
      }
      return _Page(
        mapTradingHistory(json['items'], tab),
        next as String?,
        json['partial']! as bool,
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
  const _Page(this.records, this.next, this.partial);
  final List<TradingHistoryRecord> records;
  final String? next;
  final bool partial;
}
