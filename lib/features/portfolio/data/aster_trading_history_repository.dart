import 'dart:convert';

import '../../../core/errors/api_error_details.dart';
import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/futures_history.dart';
import '../domain/trading_history.dart';
import 'aster_account_service.dart';
import 'aster_trading_history_mapper.dart';
import 'futures_history_mapper.dart';
import 'signed_account_request.dart';

/// Direct Aster reads own a fixed seven-day window. Saturated responses split
/// that window, including the boundary millisecond, without skipping records.
class AsterTradingHistoryRepository
    implements TradingHistoryRepository, TradingOrderFillsRepository {
  AsterTradingHistoryRepository({
    required this.service,
    required this.sign,
    required this.authorization,
    required this.nonces,
    required this.now,
  });
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AccountRequestAuthorization authorization;
  final AsterReadNonces nonces;
  final DateTime Function() now;

  @override
  Future<TradingHistoryPage> read(
    TradingHistoryTab tab, {
    required String address,
    TradingHistoryCursor? cursor,
  }) async {
    if (!historyUsesAster(tab)) throw const AccountReadFailure('accountDataInvalid');
    final pending = cursor == null
        ? [HistoryWindow.recent(now(), const Duration(days: 7))]
        : _windows(cursor);
    final window = pending.first;
    final query = FuturesHistoryQuery(
      kind: tab == TradingHistoryTab.orders ? FuturesHistoryKind.orders : FuturesHistoryKind.income,
      window: window,
    );
    final scope = RequestScope.current;
    final payload =
        await SignedAccountRequest(
          serverTime: service.serverTime,
          send: tab == TradingHistoryTab.orders ? service.orderHistory : service.incomeHistory,
          sign: sign,
          authorization: authorization,
          nonces: nonces,
        ).read(
          address: address,
          isCurrent: () => scope?.active ?? true,
          onStep: (_) {},
          parameters: {'startTime': '${window.start}', 'endTime': '${window.end}', 'limit': '1000'},
        );
    final FuturesHistoryPage page;
    try {
      page = mapFuturesHistory(payload, address: address, query: query, receivedAt: now());
    } on FormatException {
      throw AccountReadFailure(
        'accountDataInvalid',
        details: ApiErrorDetails(
          cause: ApiErrorCause.invalidResponse,
          endpoint: tab == TradingHistoryTab.orders ? '/fapi/v3/allOrders' : '/fapi/v3/income',
        ),
      );
    }
    final saturated = page.rawCount == FuturesHistoryPage.limit;
    final split = saturated ? window.split().reversed : const <HistoryWindow>[];
    final remaining = [...split, ...pending.skip(1)];
    return TradingHistoryPage(
      address: address,
      records: page.records.map(mapAsterTradingRecord),
      next: remaining.isEmpty
          ? null
          : TradingHistoryCursor(
              jsonEncode([
                for (final w in remaining) [w.start, w.end],
              ]),
            ),
      partial: saturated && window.start == window.end,
      recentDays: 7,
    );
  }

  @override
  Future<TradingHistoryPage> readOrderFills(
    HistoryOrder order, {
    required String address,
    TradingHistoryCursor? cursor,
  }) async {
    final from = cursor?.main;
    if (!RegExp(r'^[0-9]{1,31}$').hasMatch(order.id) ||
        !RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(order.symbol) ||
        cursor?.transfers != null ||
        from != null && !RegExp(r'^[0-9]{1,31}$').hasMatch(from)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    final scope = RequestScope.current;
    bool current() => scope?.active ?? true;
    final payload =
        await SignedAccountRequest(
          serverTime: service.serverTime,
          send: service.tradeHistory,
          sign: sign,
          authorization: authorization,
          nonces: nonces,
        ).read(
          address: address,
          isCurrent: current,
          onStep: (_) {},
          parameters: {
            'symbol': order.symbol,
            'orderId': order.id,
            'limit': '1000',
            'fromId': ?from,
          },
        );
    try {
      final fills = mapFuturesOrderFills(
        payload,
        symbol: order.symbol,
        orderId: order.id,
        fromId: from,
      );
      BigInt? maxId;
      for (final r in fills) {
        final id = BigInt.parse(r.tradeId);
        if (maxId == null || id > maxId) maxId = id;
      }
      return TradingHistoryPage(
        address: address,
        records: fills.map(mapAsterTradingRecord),
        next: (payload as List).length == 1000 && maxId != null
            ? TradingHistoryCursor('${maxId + BigInt.one}')
            : null,
      );
    } on FormatException {
      throw const AccountReadFailure(
        'accountDataInvalid',
        details: ApiErrorDetails(
          cause: ApiErrorCause.invalidResponse,
          endpoint: '/fapi/v3/userTrades',
        ),
      );
    }
  }

  List<HistoryWindow> _windows(TradingHistoryCursor cursor) {
    try {
      final raw = jsonDecode(cursor.main!);
      if (cursor.transfers != null || raw is! List || raw.isEmpty || raw.length > 64) {
        throw const FormatException();
      }
      return raw.map((r) {
        if (r is! List || r.length != 2 || r[0] is! int || r[1] is! int) {
          throw const FormatException();
        }
        final w = HistoryWindow(r[0] as int, r[1] as int);
        if (!w.fitsRequest) throw const FormatException();
        return w;
      }).toList();
    } catch (_) {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
