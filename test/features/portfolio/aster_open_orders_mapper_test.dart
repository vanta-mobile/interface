import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';

void main() {
  AsterOpenOrders parse(Object? payload) =>
      mapAsterOpenOrders(payload, address: accountAddress, receivedAt: DateTime.utc(2026));

  test('all-symbol order snapshot preserves exact decimal quantities and type semantics', () {
    final snapshot = openOrdersFixture();
    expect(snapshot.orders.map((o) => o.symbol), ['ETHUSDT', 'BTCUSDT']);
    expect(snapshot.orders.first.remainingQty.toString(), '1.25');
    expect(snapshot.orders.first.limitNotional, null);
    expect(snapshot.orders.last.limitNotional.toString(), '32000.004');
    expect(snapshot.orders.last.units?.base, 'BTC');
    expect(() => snapshot.orders.clear(), throwsUnsupportedError);
  });

  test('last update wins by symbol and orderId; terminal status removes older active rows', () {
    final old = openOrder()..['updateTime'] = 10;
    final newer = openOrder(status: 'PARTIALLY_FILLED', executedQty: '0.1')..['updateTime'] = 12;
    final stale = openOrder()..['updateTime'] = 11;
    final other = openOrder(symbol: 'ETHUSDT')..['updateTime'] = 13;
    final terminal = openOrder(status: 'CANCELED')..['updateTime'] = 14;
    final snapshot = parse([old, newer, stale, other, terminal, old]);
    expect(snapshot.orders.single.symbol, 'ETHUSDT');
    expect(parse([old, newer, stale]).orders.single.executedQty.toString(), '0.1');
  });

  test('close-all conditional order has no fake zero size or notional', () {
    final order = openOrder(type: 'STOP_MARKET', origQty: '0', price: '0')
      ..['closePosition'] = true;
    final snapshot = parse([order]);
    expect(snapshot.orders.single.closePosition, true);
    expect(snapshot.orders.single.limitNotional, null);
  });

  test('empty signed list differs from invalid payload and terminal-only list', () {
    expect(parse(<Object?>[]).orders, isEmpty);
    expect(parse([openOrder(status: 'FILLED')]).orders, isEmpty);
    for (final bad in [
      null,
      <String, Object?>{},
      {'orders': <Object?>[]},
      [null],
    ]) {
      expect(() => parse(bad), throwsFormatException);
    }
  });

  test('invalid or unsafe fields reject whole snapshot rather than manufacture zeros', () {
    for (final field in [
      ('symbol', 'BTC USDT'),
      ('symbol', String.fromCharCodes([66, 84, 67, 10])),
      ('orderId', 0),
      ('status', 'UNKNOWN'),
      ('side', 'HOLD'),
      ('positionSide', 'UP'),
      ('origQty', '-1'),
      ('origQty', '1e-8'),
      ('origQty', 1.2),
      ('executedQty', '0.41'),
      ('price', '-1'),
      ('time', 0),
    ]) {
      final row = openOrder()..[field.$1] = field.$2;
      expect(() => parse([row]), throwsFormatException, reason: field.$1);
    }
  });
}
