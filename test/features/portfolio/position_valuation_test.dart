import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/mark_price_mapper.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/position_valuation.dart';

import '../../support/aster_account.dart';
import '../../support/mark_prices.dart';
import '../../support/position_risk.dart';

void main() {
  test('long, short and one-way use signed quantity with exact Decimal multiplication', () {
    for (final side in ['BOTH', 'LONG', 'SHORT']) {
      final p = mapPositionRisk(
        [
          positionRiskRow()
            ..['positionSide'] = side
            ..['positionAmt'] = side == 'LONG' ? '0.000000000000000001' : '-0.000000000000000001'
            ..['entryPrice'] = '80000',
        ],
        address: accountAddress,
        receivedAt: markClock,
        units: {'BTCUSDT': const AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT')},
      ).positions.single;
      final quote = mapMarkPrice(
        markPayload(price: '81000.000000000000000001'),
        receivedAt: markClock,
      );
      final result = PositionValuation(position: p, quote: quote);
      expect(result.notional, p.quantity * Decimal.parse('81000.000000000000000001'));
      expect(result.unrealizedProfit, p.quantity * Decimal.parse('1000.000000000000000001'));
      expect(result.usesPublicMark, true);
    }
  });
  test('no mark keeps snapshot mark without manufacturing new estimates', () {
    final p = positionRiskFixture().positions.first;
    final value = PositionValuation(position: p, quote: null);
    expect(value.mark, p.markPrice);
    expect(value.usesPublicMark, false);
    expect(value.notional, null);
    expect(value.unrealizedProfit, null);
  });
  test('missing or non-linear units and invalid entry never manufacture PnL', () {
    for (final spec in [
      (null, '80000'),
      (const AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'BTC'), '80000'),
      (const AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT'), '0'),
    ]) {
      final p = mapPositionRisk(
        [positionRiskRow()..['entryPrice'] = spec.$2],
        address: accountAddress,
        receivedAt: markClock,
        units: spec.$1 == null ? {} : {'BTCUSDT': spec.$1!},
      ).positions.single;
      final value = PositionValuation(
        position: p,
        quote: mapMarkPrice(markPayload(), receivedAt: markClock),
      );
      expect(value.unrealizedProfit, null);
    }
  });
  test('zero-quantity negative isolated balance cannot become estimated PnL', () {
    final value = PositionValuation(
      position: positionRiskFixture().positions.last,
      quote: mapMarkPrice(markPayload(), receivedAt: markClock),
    );
    expect(value.notional, null);
    expect(value.unrealizedProfit, null);
  });
}
