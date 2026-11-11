import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';

Map<String, dynamic> _row(Object? hash) => {
  'symbol': 'BTCUSDT',
  'orderId': 1917641,
  'status': 'NEW',
  'side': 'BUY',
  'positionSide': 'BOTH',
  'type': 'LIMIT',
  'origQty': '0.40',
  'executedQty': '0',
  'price': '80000',
  'time': 1579276756075,
  'updateTime': 1579276756075,
  'newChainData': ?(hash == null ? null : {'hash': hash}),
};

String? _hash(Object? raw) => mapAsterOpenOrders(
  [_row(raw)],
  address: '0x0000000000000000000000000000000000000001',
  receivedAt: DateTime.utc(2026),
).orders.single.transactionHash;

void main() {
  test('a top-level hash is also accepted', () {
    const hash = '0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    final order = mapAsterOpenOrders(
      [
        {..._row(null), 'hash': hash},
      ],
      address: '0x0000000000000000000000000000000000000001',
      receivedAt: DateTime.utc(2026),
    ).orders.single;
    expect(order.transactionHash, hash);
  });

  test('placement hash is optional and validated', () {
    const lower = '0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    expect(_hash(lower), lower);
    expect(_hash(lower.replaceFirst('0x', '0X').toUpperCase()), lower);
    expect(_hash(null), isNull);
    expect(_hash('0X${'0' * 64}'), isNull);
    expect(_hash('0x1234'), isNull);
    expect(_hash(42), isNull);
  });
}
