import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/position_trigger_calculation.dart';

import '../../support/live_order.dart';

void main() {
  LiveOrderPosition position({bool short = false, String entry = '79000'}) => LiveOrderPosition(
    side: 'BOTH',
    quantity: Decimal.parse(short ? '-0.01' : '0.01'),
    entryPrice: Decimal.parse(entry),
  );
  PositionTriggerCalculation calculate(
    String input, {
    bool short = false,
    PositionTriggerInput mode = PositionTriggerInput.pnl,
    String quantity = '0.005',
    String entry = '79000',
    int leverage = 10,
    LiveOrderRules? rules,
  }) => calculatePositionTriggerPrice(
    position: position(short: short, entry: entry),
    quantity: Decimal.parse(quantity),
    leverage: leverage,
    rules: rules ?? liveContext().rules,
    mode: mode,
    input: input,
  );

  for (final short in [false, true]) {
    for (final positive in [false, true]) {
      test('PnL inverse respects direction, sign and selected quantity: $short $positive', () {
        final result = calculate(positive ? '5' : '-5', short: short);
        expect(result.failure, null);
        expect(result.price, Decimal.parse((positive != short) ? '80000' : '78000'));
        expect(result.pnl, Decimal.parse(positive ? '5' : '-5'));
        final entire = calculate(positive ? '5' : '-5', short: short, quantity: '0.01');
        expect(entire.price, Decimal.parse((positive != short) ? '79500' : '78500'));
        expect(entire.pnl, result.pnl);
      });
      test('leveraged entry ROI inverse: $short $positive', () {
        final result = calculate(
          positive ? '10' : '-10',
          short: short,
          mode: PositionTriggerInput.roi,
        );
        expect(result.price, Decimal.parse((positive != short) ? '79790' : '78210'));
        expect(result.roi, Decimal.parse(positive ? '10' : '-10'));
        expect(
          calculate(
            positive ? '10' : '-10',
            short: short,
            mode: PositionTriggerInput.roi,
            quantity: '0.01',
          ).price,
          result.price,
        );
        expect(result.pnl, Decimal.parse(positive ? '3.95' : '-3.95'));
      });
    }
  }
  test('rational division rounds once to exchange tick and reports actual estimate', () {
    final result = calculate('1', quantity: '0.003');
    expect(result.price, Decimal.parse('79333.3'));
    expect(result.pnl, Decimal.parse('0.9999'));
    expect(result.roi! > Decimal.parse('4.2189'), true);
    expect(result.roi! < Decimal.parse('4.219'), true);
    expect(calculate('0.0000000000000000000001').price, Decimal.parse('79000'));
    expect(calculate('0.00025').price, Decimal.parse('79000.1'));
  });
  test('rounding uses nonzero minimum lattice, does not silently clamp bounds', () {
    final payload = liveExchangePayload();
    final price = ((payload['symbols'] as List).single['filters'] as List).first as Map;
    price.addAll(<String, dynamic>{'minPrice': '0.03', 'tickSize': '0.1', 'maxPrice': '80000'});
    final rules = mapLiveOrderRules(payload, 'BTCUSDT');
    expect(calculate('0', rules: rules).price, Decimal.parse('79000.03'));
    expect(calculate('5.1', rules: rules).failure, 'triggerCalculationBounds');
    price['tickSize'] = '0';
    expect(
      calculate('1', rules: mapLiveOrderRules(payload, 'BTCUSDT')).failure,
      'triggerCalculationTick',
    );
  });
  for (final invalid in [
    '',
    '+1',
    '1e2',
    'NaN',
    'Infinity',
    '.1',
    '1.',
    ' 1',
    '1,2',
    '--1',
    '1' * 81,
  ]) {
    test('strict signed decimal rejects $invalid', () {
      expect(calculate(invalid).failure, 'triggerCalculationInput');
    });
  }
  test('invalid position, quantity, leverage and impossible price fail safely', () {
    for (final quantity in ['0', '-1', '0.011']) {
      expect(calculate('1', quantity: quantity).failure, 'triggerCalculationPosition');
    }
    expect(calculate('1', entry: '0').failure, 'triggerCalculationPosition');
    expect(calculate('1', leverage: 0).failure, 'triggerCalculationPosition');
    expect(calculate('1', leverage: -1).failure, 'triggerCalculationPosition');
    expect(calculate('-395').failure, 'triggerCalculationBounds');
    expect(calculate('-1000', mode: PositionTriggerInput.roi).failure, 'triggerCalculationBounds');
    expect(calculate('100000').failure, 'triggerCalculationBounds');
    expect(
      calculatePositionTriggerPrice(
        position: null,
        quantity: Decimal.one,
        leverage: 10,
        rules: liveContext().rules,
        mode: PositionTriggerInput.pnl,
        input: '1',
      ).failure,
      'triggerCalculationPosition',
    );
  });
}
