import 'package:vanta/features/portfolio/data/open_order_update_mapper.dart';
import 'package:vanta/features/portfolio/domain/open_order_update.dart';

const orderEventClock = 1793620802000;
Map<String, dynamic> orderUpdatePayload({
  String symbol = 'BTCUSDT',
  String id = '1917641',
  String status = 'PARTIALLY_FILLED',
  String quantity = '0.40',
  String filled = '0.1',
  String price = '80000.01',
  int eventTime = orderEventClock,
  int? transactionTime,
}) => {
  'e': 'ORDER_TRADE_UPDATE',
  'E': eventTime,
  'T': transactionTime ?? eventTime - 1,
  'o': <String, dynamic>{
    's': symbol,
    'i': id,
    'c': 'vanta-test-order',
    'ap': filled == '0' ? '0' : price,
    'l': filled,
    'L': filled == '0' ? '0' : price,
    't': 42,
    'rp': '0',
    'S': 'BUY',
    'ps': 'BOTH',
    'o': 'LIMIT',
    'ot': 'LIMIT',
    'f': 'GTC',
    'q': quantity,
    'z': filled,
    'p': price,
    'sp': '0',
    'R': false,
    'cp': false,
    'X': status,
    'x': status == 'NEW'
        ? 'NEW'
        : status == 'CANCELED'
        ? 'CANCELED'
        : status == 'EXPIRED'
        ? 'EXPIRED'
        : 'TRADE',
    'T': transactionTime ?? eventTime - 1,
    'wt': 'CONTRACT_PRICE',
  },
};
OpenOrderUpdate orderUpdate({
  String symbol = 'BTCUSDT',
  String id = '1917641',
  String status = 'PARTIALLY_FILLED',
  String filled = '0.1',
  String price = '80000.01',
  int eventTime = orderEventClock,
  int? transactionTime,
}) => mapOpenOrderUpdate(
  orderUpdatePayload(
    symbol: symbol,
    id: id,
    status: status,
    filled: filled,
    price: price,
    eventTime: eventTime,
    transactionTime: transactionTime,
  ),
);
