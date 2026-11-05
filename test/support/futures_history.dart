import 'dart:async';

import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/futures_history.dart';
import 'package:vanta/features/portfolio/data/futures_history_mapper.dart';

final futuresHistoryNow = DateTime.utc(2026, 11, 5, 6);
final futuresHistoryWindow = HistoryWindow.recent(futuresHistoryNow, const Duration(days: 7));
const futuresHistoryUnits = {
  'BTCUSDT': AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT'),
};
FuturesHistoryQuery futuresQuery(
  FuturesHistoryKind kind, {
  String symbol = '',
  String incomeType = '',
  HistoryWindow? window,
}) => FuturesHistoryQuery(
  kind: kind,
  window: window ?? futuresHistoryWindow,
  symbol: symbol,
  incomeType: incomeType,
);
Map<String, dynamic> futuresOrderRow({String id = '12345', int? time}) => {
  'symbol': 'BTCUSDT',
  'orderId': id,
  'clientOrderId': 'vanta-history-123',
  'time': time ?? futuresHistoryNow.millisecondsSinceEpoch,
  'updateTime': time ?? futuresHistoryNow.millisecondsSinceEpoch,
  'side': 'BUY',
  'positionSide': 'BOTH',
  'type': 'LIMIT',
  'origType': 'LIMIT',
  'timeInForce': 'GTC',
  'status': 'CANCELED',
  'origQty': '0.002',
  'executedQty': '0.001',
  'price': '80000',
  'avgPrice': '80000',
  'cumQuote': '80.000000000000000001',
  'stopPrice': '0',
  'reduceOnly': false,
  'closePosition': false,
  'workingType': 'CONTRACT_PRICE',
  'priceProtect': false,
};
Map<String, dynamic> futuresTradeRow({String id = '98765', int? time}) => {
  'id': id,
  'orderId': '12345',
  'symbol': 'BTCUSDT',
  'time': time ?? futuresHistoryNow.millisecondsSinceEpoch,
  'side': 'SELL',
  'positionSide': 'SHORT',
  'buyer': false,
  'maker': true,
  'price': '80000',
  'qty': '0.001',
  'quoteQty': '80.000000000000000001',
  'commission': '-0.008000000000000001',
  'commissionAsset': 'BNB',
  'realizedPnl': '-1.250000000000000001',
};
Map<String, dynamic> futuresIncomeRow({String id = '45678', int? time}) => {
  'tranId': id,
  'incomeType': 'FUNDING_FEE',
  'asset': 'USDT',
  'symbol': 'BTCUSDT',
  'income': '-0.000000000000000001',
  'tradeId': '',
  'info': 'Never render this raw payload',
  'time': time ?? futuresHistoryNow.millisecondsSinceEpoch,
};

class TestFuturesHistoryRepository implements FuturesHistoryRepository {
  final queries = <FuturesHistoryQuery>[];
  Completer<void>? gate;
  AccountReadFailure? failure;
  FuturesHistoryPage Function(FuturesHistoryQuery)? respond;
  bool Function()? latestCurrent;
  @override
  Future<FuturesHistoryPage> read({
    required String address,
    required FuturesHistoryQuery query,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    queries.add(query);
    latestCurrent = isCurrent;
    onStep(AccountReadStep.signing);
    await gate?.future;
    if (failure case final e?) throw e;
    return respond?.call(query) ??
        mapFuturesHistory(
          [
            switch (query.kind) {
              FuturesHistoryKind.orders => {
                ...futuresOrderRow(time: query.window.end),
                if (query.symbol.isNotEmpty) 'symbol': query.symbol,
              },
              FuturesHistoryKind.trades => {
                ...futuresTradeRow(time: query.window.end),
                'symbol': query.symbol,
              },
              FuturesHistoryKind.income => {
                ...futuresIncomeRow(time: query.window.end),
                if (query.symbol.isNotEmpty) 'symbol': query.symbol,
                if (query.incomeType.isNotEmpty) 'incomeType': query.incomeType,
              },
            },
          ],
          address: address,
          query: query,
          receivedAt: futuresHistoryNow,
          units: futuresHistoryUnits,
        );
  }
}
