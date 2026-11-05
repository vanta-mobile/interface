import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/position_returns.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';
import 'package:vanta/features/portfolio/domain/account_event_reconciliation.dart';
import 'package:vanta/features/portfolio/domain/account_update_book.dart';

import '../../support/aster_account.dart';
import '../../support/position_risk.dart';
import '../../support/account_updates.dart';

void main() {
  PositionRisk position({
    String side = 'BOTH',
    String quantity = '2',
    String mark = '110',
    String entry = '100',
    String leverage = '10',
    bool isolated = false,
    String wallet = '99',
    AsterContractUnits? units = const AsterContractUnits(
      base: 'BTC',
      quote: 'USDT',
      margin: 'USDT',
    ),
  }) => mapPositionRisk(
    [
      positionRiskRow()
        ..['positionSide'] = side
        ..['positionAmt'] = quantity
        ..['markPrice'] = mark
        ..['entryPrice'] = entry
        ..['leverage'] = leverage
        ..['marginType'] = isolated ? 'isolated' : 'cross'
        ..['isolatedWallet'] = wallet,
    ],
    address: accountAddress,
    receivedAt: DateTime.utc(2026),
    units: units == null ? {} : {'BTCUSDT': units},
  ).positions.single;
  PositionReturns values(PositionRisk p, {String? mark = '110', String? pnl = '20'}) =>
      PositionReturns(
        position: p,
        mark: mark == null ? null : Decimal.parse(mark),
        pnl: pnl == null ? null : Decimal.parse(pnl),
      );

  test('cross margin and ROE use current mark and leverage, never entire account balance', () {
    final v = values(position());
    expect(v.margin, Decimal.parse('22'));
    expect(v.initialMargin, Decimal.parse('22'));
    expect(v.roePercent, Decimal.parse('90.91'));
  });
  test('isolated allocation stays separate from ROE initial-margin denominator', () {
    final v = values(position(isolated: true, wallet: '999'));
    expect(v.margin, Decimal.parse('999'));
    expect(v.initialMargin, Decimal.parse('22'));
    expect(v.roePercent, Decimal.parse('90.91'));
  });
  test('PRD ASTER margin sample uses mark not entry or last trade', () {
    final v = values(
      position(quantity: '29.48', mark: '0.71901', entry: '0.71230', leverage: '4'),
      mark: '0.71901',
      pnl: '0.1978108',
    );
    expect(v.margin, Decimal.parse('5.2991037'));
    expect(v.roePercent, Decimal.parse('3.73'));
  });
  for (final side in ['BOTH', 'LONG', 'SHORT']) {
    test('$side uses magnitude for denominator and signed PnL for return', () {
      final v = values(
        position(side: side, quantity: side == 'LONG' ? '2' : '-2'),
        pnl: '-20',
      );
      expect(v.initialMargin, Decimal.parse('22'));
      expect(v.roePercent, Decimal.parse('-90.91'));
    });
  }
  test('finite decimal arithmetic preserves fractions beyond double precision', () {
    final v = values(
      position(quantity: '0.000000000000000001', leverage: '8'),
      mark: '81000.000000000000000001',
      pnl: '0.000000000000001',
    );
    expect(v.margin, Decimal.parse('0.000000000000010125000000000000000000125'));
    expect(v.roePercent, Decimal.parse('9.88'));
  });
  test('repeating margin stays nonzero for tiny quantity and ROE divides exact inputs', () {
    final v = values(
      position(quantity: '0.000000000000000000000000000001', leverage: '3'),
      mark: '1',
      pnl: '0.000000000000000000000000000001',
    );
    expect(v.margin! > Decimal.zero, true);
    expect(v.roePercent, Decimal.parse('300'));
  });
  test('percentage rounds only once, halves away from zero and no negative zero', () {
    for (final (pnl, result) in [
      ('0.0001', '0.01'),
      ('-0.0001', '-0.01'),
      ('0.00001', '0'),
      ('-0.00001', '0'),
    ]) {
      final v = values(
        position(quantity: '2', leverage: '1'),
        mark: '1',
        pnl: pnl,
      );
      expect(v.roePercent, Decimal.parse(result));
    }
  });
  test('nonterminating leverage reciprocal is exact instead of rounded to five places', () {
    final v = values(
      position(quantity: '3', leverage: '3'),
      mark: '1',
      pnl: '1',
    );
    expect(v.margin, Decimal.one);
    expect(v.roePercent, Decimal.parse('100'));
  });
  test('zero PnL is valid zero return; loss may exceed minus 100 percent', () {
    expect(values(position(), pnl: '0').roePercent, Decimal.zero);
    expect(values(position(), pnl: '-44').roePercent, Decimal.parse('-200'));
  });
  test('missing or nonlinear units do not manufacture cross margin or ROE', () {
    for (final units in [
      null,
      const AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'BTC'),
    ]) {
      final v = values(position(units: units));
      expect(v.margin, null);
      expect(v.roePercent, null);
    }
  });
  test('missing mark, zero mark and missing PnL do not manufacture percentage', () {
    for (final mark in [null, '0']) {
      expect(values(position(), mark: mark).roePercent, null);
    }
    expect(values(position(), pnl: null).roePercent, null);
    expect(values(position(entry: '0')).roePercent, null);
  });
  test('event has no leverage so ROE unknown; isolated wallet remains known', () {
    final book = AccountUpdateBook()..add(accountUpdate());
    final p = reconcileRiskUpdates(positionRiskFixture(), book, since: 0).positions.first;
    final v = values(p);
    expect(v.margin, Decimal.parse('1.5'));
    expect(v.initialMargin, null);
    expect(v.roePercent, null);
  });
  test('zero quantity with isolated debt is an allocation record, never a return', () {
    final p = positionRiskFixture().positions.last;
    final v = values(p);
    expect(v.margin, Decimal.parse('-2'));
    expect(v.initialMargin, null);
    expect(v.roePercent, null);
  });
}
