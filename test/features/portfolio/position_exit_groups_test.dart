import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/domain/position_exit_groups.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';

Decimal d(String value) => Decimal.parse(value);

PositionRisk position() => PositionRisk(
  symbol: 'BTCUSDT',
  side: 'BOTH',
  quantity: d('0.01'),
  entryPrice: d('80000'),
  markPrice: d('80000'),
  isolated: false,
  isolatedWallet: Decimal.zero,
  leverage: 20,
);

AsterOpenOrder order(
  String id, {
  required String type,
  String? client,
  String side = 'SELL',
  String status = 'NEW',
  bool closePosition = false,
  int minute = 0,
}) => AsterOpenOrder(
  symbol: 'BTCUSDT',
  orderId: id,
  clientOrderId: client,
  side: side,
  positionSide: 'BOTH',
  type: type,
  status: status,
  time: DateTime.utc(2026, 11, 13, 12, minute),
  origQty: d(closePosition ? '0' : '0.005'),
  executedQty: Decimal.zero,
  price: Decimal.zero,
  stopPrice: d('90000'),
  reduceOnly: !closePosition,
  closePosition: closePosition,
);

void main() {
  test('pairs legs by client-ID base or strategy, earliest group first', () {
    final groups = positionExitGroups(position(), [
      order('5', type: 'TAKE_PROFIT_MARKET', minute: 9),
      order('3', type: 'STOP_MARKET', client: 'vanta-abc-def-sl', minute: 2),
      order('2', type: 'TAKE_PROFIT_MARKET', client: 'vanta-abc-def-tp', minute: 1),
      order('4', type: 'STOP_MARKET', client: 'vanta-abc-xyz-3', minute: 5),
      order('6', type: 'TAKE_PROFIT', client: 'vanta-abc-xyz-2', minute: 6),
      order('1', type: 'STOP_MARKET', closePosition: true),
    ]);
    expect(groups.map((g) => [g.takeProfit?.orderId, g.stopLoss?.orderId]), [
      [null, '1'],
      ['2', '3'],
      ['6', '4'],
      ['5', null],
    ]);
    expect(groups.map((g) => g.entire), [true, false, false, false]);
  });

  test('an unpaired or duplicate leg forms its own group', () {
    final groups = positionExitGroups(position(), [
      order('1', type: 'TAKE_PROFIT_MARKET', client: 'vanta-a-b-tp'),
      order('2', type: 'TAKE_PROFIT_MARKET', client: 'vanta-a-b-tp', minute: 1),
      order('3', type: 'STOP_MARKET', client: 'web-order', minute: 2),
    ]);
    expect(groups.map((g) => g.orders.map((o) => o.orderId).toList()), [
      ['1'],
      ['2'],
      ['3'],
    ]);
  });

  test('skips orders that do not close this position', () {
    final groups = positionExitGroups(position(), [
      order('1', type: 'TAKE_PROFIT', status: 'FILLED'),
      order('2', type: 'LIMIT'),
      order('3', type: 'STOP_MARKET', side: 'BUY'),
    ]);
    expect(groups, isEmpty);
  });

  test('only uses open orders of the position wallet', () {
    final orders = AsterOpenOrders(
      address: '0xAbC',
      receivedAt: DateTime.utc(2026),
      orders: [order('1', type: 'STOP_MARKET')],
      units: const {},
    );
    expect(walletPositionExitGroups(position(), orders, '0xabc'), hasLength(1));
    expect(walletPositionExitGroups(position(), orders, '0xdef'), isEmpty);
    expect(walletPositionExitGroups(position(), null, '0xabc'), isEmpty);
  });
}
