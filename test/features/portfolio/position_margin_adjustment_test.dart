import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/position_margin_adjustment.dart';
import 'package:vanta/features/portfolio/domain/isolated_margin_ratio.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

import '../../support/position_margin_adjustment.dart';

void main() {
  test(
    'add max uses min available and cross wallet less isolated initial and crossed maintenance',
    () {
      final account = marginAccount();
      (account['positions'] as List).add({
        'symbol': 'BTCUSDT',
        'positionSide': 'LONG',
        'positionAmt': '1',
        'isolated': false,
        'positionInitialMargin': '999',
        'maintMargin': '7.123456789123',
      });
      final c = marginContext(account: account);
      expect(c.addMax, md('72.876543210877'));
      expect(c.maxInput(MarginDirection.add), '72.87');
      expect(
        marginContext(account: marginAccount(available: '1.23456789')).addMax,
        md('1.23456789'),
      );
    },
  );
  test('other-asset costs excluded but unknown units never treated as free margin', () {
    final account = marginAccount();
    (account['positions'] as List).add({
      'symbol': 'UNKNOWN',
      'positionSide': 'BOTH',
      'positionAmt': '1',
      'isolated': false,
      'maintMargin': '1',
    });
    expect(marginContext(account: account).addMax, null);
  });
  for (final key in ['availableBalance', 'crossWalletBalance']) {
    test('missing $key blocks add without fallback', () {
      final account = marginAccount();
      ((account['assets'] as List).first as Map).remove(key);
      expect(marginContext(account: account).addMax, null);
    });
  }
  test('negative add limit clamps to zero; max does not exceed tiny balances', () {
    expect(marginContext(account: marginAccount(cross: '-1')).addMax, md('0'));
    final c = marginContext(account: marginAccount(available: '0.00999999'));
    expect(c.maxInput(MarginDirection.add), '0.00');
    expect(c.amount(c.maxInput(MarginDirection.add)!, MarginDirection.add), null);
  });
  test(
    'remove max uses signed own maintenance and mark initial margin; long and short PnL signs',
    () {
      final long = marginContext(risk: marginRisk(mark: '110'));
      expect(long.removeMax, md('48')); // min(50-1, 50+20-22)
      final short = marginContext(
        account: marginAccount(quantity: '-2', side: 'SHORT'),
        risk: marginRisk(quantity: '-2', side: 'SHORT', mark: '110'),
      );
      expect(short.removeMax, md('8')); // min(49, 50-20-22)
      expect(marginContext(account: marginAccount(maintenance: '49')).removeMax, md('1'));
    },
  );
  test('repeating division rounds initial margin upward and Max downward', () {
    final risk = marginRisk(quantity: '1')..['leverage'] = '3';
    final account = marginAccount(quantity: '1');
    ((account['positions'] as List).first as Map)['leverage'] = '3';
    final c = marginContext(account: account, risk: risk);
    expect(c.removeMax, lessThan(md('16.666666666666666666666666666667')));
    expect(c.maxInput(MarginDirection.remove), '16.66');
  });
  test(
    'missing maintenance disables remove and nonpositive equity never grants a negative limit',
    () {
      final a = marginAccount();
      ((a['positions'] as List).first as Map).remove('maintMargin');
      expect(marginContext(account: a).removeMax, null);
      expect(marginContext(risk: marginRisk(mark: '1')).removeMax, md('0'));
    },
  );
  for (final value in ['', '0', '-1', '01', '1e1', 'NaN', ' 1', '1 ', '1.000000001', '81']) {
    test(
      'invalid or over-max input $value rejected',
      () => expect(marginContext().amount(value, MarginDirection.add), null),
    );
  }
  test('exact input precision and direction revalidation', () {
    final c = marginContext();
    expect(c.amount('0.00000001', MarginDirection.add), md('0.00000001'));
    expect(c.amount('50', MarginDirection.add), md('50'));
    expect(c.amount('50', MarginDirection.remove), null);
  });
  test('long liquidation chooses consistent risk tier and moves away on add', () {
    final c = marginContext();
    final before = c.liquidation(MarginDirection.add, md('0'))!;
    final after = c.liquidation(MarginDirection.add, md('10'))!;
    expect(
      (before - md('75.765306122448979591836734')).abs(),
      lessThan(md('0.000000000000000000000002')),
    );
    expect(
      (after - md('70.707070707070707070707070')).abs(),
      lessThan(md('0.000000000000000000000002')),
    );
    expect(c.position.entryPrice, md('100'));
    expect(c.position.quantity, md('2'));
    expect(c.liquidation(MarginDirection.remove, md('10'))!, greaterThan(before));
  });
  test('short liquidation moves upward on add and downward on remove', () {
    final c = marginContext(
      account: marginAccount(quantity: '-2', side: 'SHORT'),
      risk: marginRisk(quantity: '-2', side: 'SHORT'),
    );
    final before = c.liquidation(MarginDirection.add, md('0'))!;
    expect(c.liquidation(MarginDirection.add, md('10'))!, greaterThan(before));
    expect(c.liquidation(MarginDirection.remove, md('10'))!, lessThan(before));
  });
  test('no valid positive liquidation remains unknown', () {
    final c = marginContext(
      account: marginAccount(wallet: '500'),
      risk: marginRisk(wallet: '500'),
    );
    expect(c.liquidation(MarginDirection.add, md('0')), null);
    expect(c.liquidation(MarginDirection.add, md('-1')), null);
  });
  test('position sameness locks side, quantity, entry and wallet', () {
    final c = marginContext();
    expect(c.samePosition(marginContext()), true);
    expect(c.samePosition(marginContext(risk: marginRisk(wallet: '51'))), false);
    expect(c.samePosition(marginContext(risk: marginRisk(quantity: '3'))), false);
    expect(c.samePosition(marginContext(risk: marginRisk(entry: '101'))), false);
  });
  test('margin ratio is same account maintenance / wallet plus UPL, not initial margin', () {
    final p = AsterPosition(
      symbol: 'BTCUSDT',
      side: 'BOTH',
      quantity: md('1'),
      isolated: true,
      isolatedWallet: md('100'),
      unrealizedProfit: md('-20'),
      maintenanceMargin: md('4'),
      initialMargin: md('999'),
    );
    expect(isolatedMarginRatio(p).percent, md('5'));
    expect(isolatedMarginRatio(p).atRisk, false);
  });
  for (final pnl in ['-100', '-101']) {
    test('nonpositive equity $pnl flags risk without numeric ratio', () {
      final p = AsterPosition(
        symbol: 'BTCUSDT',
        side: 'BOTH',
        quantity: md('1'),
        isolated: true,
        isolatedWallet: md('100'),
        unrealizedProfit: md(pnl),
        maintenanceMargin: md('4'),
      );
      expect(isolatedMarginRatio(p), (percent: null, atRisk: true));
    });
  }
}
