import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/account_update_mapper.dart';

import '../../support/account_updates.dart';

void main() {
  test(
    'keeps exact signed balances, quantity and event PnL without interpreting cr or bc as cash',
    () {
      final event = accountUpdate();
      expect(event.balances.single.walletBalance.toString(), '102.000000000000000001');
      expect(event.positions.single.quantity.toString(), '-0.2');
      expect(event.positions.single.unrealizedProfit.toString(), '-0.000000000000001');
      expect(event.eventTime.millisecondsSinceEpoch, accountEventClock);
      expect(event.transactionTime.millisecondsSinceEpoch, accountEventClock - 1);
      expect(() => event.balances.clear(), throwsUnsupportedError);
    },
  );
  test('funding balance-only and position-only updates may omit the other list', () {
    final balanceOnly = accountUpdatePayload();
    (balanceOnly['a'] as Map).remove('P');
    (balanceOnly['a'] as Map)['m'] = 'FUNDING_FEE';
    expect(mapAccountUpdate(balanceOnly).positions, isEmpty);
    final positionOnly = accountUpdatePayload();
    (positionOnly['a'] as Map).remove('B');
    expect(mapAccountUpdate(positionOnly).balances, isEmpty);
  });
  test('explicit zero close and negative isolated wallet remain distinct', () {
    final event = accountUpdate(
      positions: [accountPositionUpdate(quantity: '0', wallet: '-2')],
    );
    expect(event.positions.single.quantity.toString(), '0');
    expect(event.positions.single.isolatedWallet.toString(), '-2');
    final negative = accountUpdate(balances: [accountBalanceUpdate(wallet: '-1')]);
    expect(negative.balances.single.walletBalance.toString(), '-1');
  });
  test('unknown reason may carry valid updates without guessing a financial outcome', () {
    final payload = accountUpdatePayload();
    (payload['a'] as Map)['m'] = 'FUTURE_REASON';
    expect(mapAccountUpdate(payload).balances.length, 1);
  });
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'wrong type': (p) => p['e'] = 'ORDER_TRADE_UPDATE',
    'noninteger time': (p) => p['T'] = 1.5,
    'out of range E': (p) => p['E'] = 253402300800000,
    'empty update': (p) => p['a'] = {'m': 'ORDER'},
    'invalid list': (p) => (p['a'] as Map)['B'] = <String, Object?>{},
    'duplicate asset': (p) =>
        (p['a'] as Map)['B'] = [accountBalanceUpdate(), accountBalanceUpdate()],
    'duplicate position': (p) =>
        (p['a'] as Map)['P'] = [accountPositionUpdate(), accountPositionUpdate()],
    'double money': (p) => ((p['a'] as Map)['B'] as List).first['wb'] = 1.01,
    'missing money': (p) => ((p['a'] as Map)['B'] as List).first.remove('cw'),
    'scientific money': (p) => ((p['a'] as Map)['P'] as List).first['pa'] = '1e-8',
    'negative entry': (p) => ((p['a'] as Map)['P'] as List).first['ep'] = '-1',
    'wrong LONG sign': (p) => ((p['a'] as Map)['P'] as List).first['ps'] = 'LONG',
    'wrong SHORT sign': (p) =>
        (p['a'] as Map)['P'] = [accountPositionUpdate(side: 'SHORT', quantity: '1')],
    'unknown side': (p) => ((p['a'] as Map)['P'] as List).first['ps'] = 'NEW_SIDE',
    'unknown margin type': (p) => ((p['a'] as Map)['P'] as List).first['mt'] = 'new_mode',
    'invalid accumulated pnl': (p) =>
        ((p['a'] as Map)['P'] as List).first['cr'] = <String, Object?>{},
  }.entries) {
    test('rejects ${mutation.key} before publishing financial state', () {
      final payload = accountUpdatePayload();
      mutation.value(payload);
      expect(() => mapAccountUpdate(payload), throwsFormatException);
    });
  }
}
