import 'dart:async';

import 'package:vanta/features/portfolio/data/spot_history_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/spot_history.dart';

import 'aster_account.dart';

final historyNow = DateTime.utc(2026, 11, 2, 12);
final historyTime = historyNow.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
final historyWindow = HistoryWindow.recent(historyNow, const Duration(days: 7));

Map<String, Object?> spotOrderRow({
  Object id = 349661,
  String symbol = 'BNBUSDT',
  String status = 'NEW',
  String executed = '0',
  int? time,
  int? updated,
}) => {
  'orderId': id,
  'symbol': symbol,
  'status': status,
  'price': '1.100000000000000001',
  'avgPrice': executed == '0' ? '0' : '1.10',
  'origQty': '5',
  'executedQty': executed,
  'cumQuote': executed == '0' ? '0' : '1.10',
  'timeInForce': 'GTC',
  'type': 'LIMIT',
  'side': 'BUY',
  'stopPrice': '0',
  'time': time ?? historyTime,
  'updateTime': updated ?? time ?? historyTime,
};
Map<String, Object?> spotTradeRow({Object id = 1002, String symbol = 'BNBUSDT', int? time}) => {
  'symbol': symbol,
  'id': id,
  'orderId': 349661,
  'side': 'BUY',
  'price': '1.100000000000000001',
  'qty': '0.000000000000000001',
  'quoteQty': '0.0000000000000000011',
  'commission': '-0.000000000000000001',
  'commissionAsset': 'BNB',
  'time': time ?? historyTime,
  'maker': false,
  'buyer': true,
};
Map<String, Object?> spotTransactionRow({
  Object id = '1759115482304540227',
  String type = 'TRADE_SOURCE',
  String asset = 'ASTER',
  int? time,
}) => {
  'tranId': id,
  'tradeId': null,
  'asset': asset,
  'symbol': '',
  'balanceDelta': '-500.000000000000000001',
  'balanceInfo': 'TRADE_SOURCE',
  'time': time ?? historyTime,
  'type': type,
};
Map<String, Object?> spotSymbols() => {
  'symbols': [
    {'symbol': 'BNBUSDT', 'baseAsset': 'BNB', 'quoteAsset': 'USDT', 'status': 'BREAK'},
    {'symbol': 'BTCUSDT', 'baseAsset': 'BTC', 'quoteAsset': 'USDT'},
  ],
};

class TestSpotHistoryRepository implements SpotHistoryRepository {
  final queries = <SpotHistoryQuery>[];
  Completer<void>? gate;
  AccountReadFailure? failure;
  int? rawCount;
  List<SpotHistoryRecord>? records;
  SpotHistoryPage Function(SpotHistoryQuery)? respond;
  @override
  Future<SpotHistoryPage> read({
    required String address,
    required SpotHistoryQuery query,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    queries.add(query);
    onStep(AccountReadStep.signing);
    await gate?.future;
    if (failure case final error?) throw error;
    if (respond != null) return respond!(query);
    final rows = <Object?>[
      switch (query.kind) {
        SpotHistoryKind.orders => spotOrderRow(time: query.window.end),
        SpotHistoryKind.trades => spotTradeRow(time: query.window.end),
        SpotHistoryKind.transactions => spotTransactionRow(time: query.window.end),
      },
    ];
    final mapped = mapSpotHistory(
      rows,
      address: address,
      query: query,
      receivedAt: historyNow,
      units: mapSpotSymbolUnits(spotSymbols()),
    );
    return SpotHistoryPage(
      address: accountAddress,
      query: query,
      receivedAt: historyNow,
      records: records ?? mapped.records,
      rawCount: rawCount ?? records?.length ?? mapped.rawCount,
    );
  }
}
