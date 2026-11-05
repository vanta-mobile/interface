import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/open_order_update_mapper.dart';

import '../../support/open_order_updates.dart';

void main() {
  test('exact decimals, IDs, trade time and event time preserve distinct meanings', () {
    final row = orderUpdatePayload(
      id: '1234567890123456789012345678901',
      quantity: '0.000000000000000003',
      filled: '0.000000000000000001',
      price: '80000.123456789123456789',
    );
    final event = mapOpenOrderUpdate(row);
    expect(event.origQty.toString(), '0.000000000000000003');
    expect(event.executedQty.toString(), '0.000000000000000001');
    expect(event.price.toString(), '80000.123456789123456789');
    expect(event.orderId, '1234567890123456789012345678901');
    expect(event.eventTime.millisecondsSinceEpoch, orderEventClock);
    expect(event.transactionTime.millisecondsSinceEpoch, orderEventClock - 1);
    expect(event.toOrder().time, null);
    expect(event.terminal, false);
  });
  test(
    'conditional original type and trailing stop ignore sp while preserving activation/callback',
    () {
      final row = orderUpdatePayload();
      final order = row['o'] as Map<String, dynamic>;
      order.addAll({
        'o': 'TRAILING_STOP_MARKET',
        'ot': 'TRAILING_STOP_MARKET',
        'AP': '7476.890000000000000001',
        'cr': '5.0',
        'sp': 'not used',
      });
      final event = mapOpenOrderUpdate(row);
      expect(event.stopPrice, null);
      expect(event.activatePrice.toString(), '7476.890000000000000001');
      expect(event.priceRate.toString(), '5');
      expect(event.originalType, 'TRAILING_STOP_MARKET');
    },
  );
  test('close-all terminal events can carry actual filled quantity with no original quantity', () {
    final row = orderUpdatePayload(status: 'FILLED', quantity: '0', filled: '2');
    (row['o'] as Map<String, dynamic>).addAll({
      'o': 'STOP_MARKET',
      'ot': 'STOP_MARKET',
      'cp': true,
    });
    final event = mapOpenOrderUpdate(row);
    expect(event.terminal, true);
    expect(event.closePosition, true);
    expect(event.executedQty.toString(), '2');
  });
  for (final status in ['FILLED', 'CANCELED', 'EXPIRED', 'REJECTED']) {
    test('known terminal $status is unambiguous', () {
      expect(
        mapOpenOrderUpdate(
          orderUpdatePayload(status: status, filled: status == 'FILLED' ? '0.40' : '0.1'),
        ).terminal,
        true,
      );
    });
  }
  test('invalid, future extension and inconsistent fields fail closed without zero coercion', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (e) => e['E'] = '1',
      (e) => e['T'] = 0,
      (e) => e['E'] = 253402300800000,
      (e) => (e['o'] as Map)['i'] = 0,
      (e) => (e['o'] as Map)['s'] = 'BTC\nUSDT',
      (e) => (e['o'] as Map)['S'] = 'HOLD',
      (e) => (e['o'] as Map)['ps'] = 'UP',
      (e) => (e['o'] as Map)['q'] = 0.4,
      (e) => (e['o'] as Map)['z'] = '0.5',
      (e) => (e['o'] as Map)['p'] = '1e-18',
      (e) => (e['o'] as Map)['R'] = 'false',
      (e) => (e['o'] as Map)['cp'] = 1,
      (e) => (e['o'] as Map)['X'] = 'NEW_INSURANCE',
      (e) => (e['o'] as Map)['X'] = 'NEW_ADL',
      (e) => (e['o'] as Map)['o'] = 'UNKNOWN',
      (e) => (e['o'] as Map)['f'] = 'UNKNOWN',
      (e) => (e['o'] as Map)['x'] = 'UNKNOWN',
      (e) => (e['o'] as Map)['T'] = null,
      (e) => (e['o'] as Map)['X'] = 'NEW',
      (e) => (e['o'] as Map)['X'] = 'FILLED',
      (e) => (e['o'] as Map)['z'] = '0',
      (e) => (e['o'] as Map)['q'] = '0',
    ];
    for (final mutate in mutations) {
      final row = orderUpdatePayload();
      mutate(row);
      expect(() => mapOpenOrderUpdate(row), throwsFormatException, reason: '$row');
    }
  });
}
