import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/main_order_risk_mapper.dart';

import '../../support/main_order_revaluation.dart';

Map<String, dynamic> riskRow(String symbol) => {
  'symbol': symbol,
  'brackets': [
    {
      'bracket': 1,
      'initialLeverage': 100,
      'notionalFloor': 0,
      'notionalCap': 1000,
      'maintMarginRatio': '0.005',
      'cum': 0,
    },
    {
      'bracket': 2,
      'initialLeverage': 50,
      'notionalFloor': 1000,
      'notionalCap': 100000,
      'maintMarginRatio': '0.01',
      'cum': 5,
    },
  ],
};

void main() {
  test(
    'selects exact symbol keys from unscoped risk response and freezes all nested collections',
    () {
      final raw = [riskRow('BTCUSDT'), riskRow('ETHUSDT'), riskRow('SOLUSDT')];
      final value = mapMainOrderRiskTiers(raw, {'ETHUSDT', 'BTCUSDT'});
      expect(value.keys.toSet(), {'BTCUSDT', 'ETHUSDT'});
      expect(value['ETHUSDT']!.last.floor, d('1000'));
      expect(value['ETHUSDT']!.last.cumulative, d('5'));
      expect(value['ETHUSDT']!.last.rate, d('0.01'));
      (raw[1]['brackets'] as List).clear();
      expect(value['ETHUSDT']!.length, 2);
      expect(() => value.clear(), throwsUnsupportedError);
      expect(() => value['ETHUSDT']!.clear(), throwsUnsupportedError);
    },
  );
  for (final scenario in [
    'object',
    'missing',
    'duplicate',
    'duplicateUnused',
    'unknownShape',
    'noSymbols',
  ]) {
    test('rejects $scenario unscoped risk data', () {
      Object? payload = [riskRow('BTCUSDT')];
      var symbols = {'BTCUSDT'};
      switch (scenario) {
        case 'object':
          payload = riskRow('BTCUSDT');
        case 'missing':
          symbols = {'BTCUSDT', 'ETHUSDT'};
        case 'duplicate':
          payload = [riskRow('BTCUSDT'), riskRow('BTCUSDT')];
        case 'duplicateUnused':
          payload = [riskRow('BTCUSDT'), riskRow('ETHUSDT'), riskRow('ETHUSDT')];
        case 'unknownShape':
          payload = [riskRow('BTCUSDT'), 0];
        case 'noSymbols':
          symbols = {};
      }
      expect(() => mapMainOrderRiskTiers(payload, symbols), throwsFormatException);
    });
  }
  for (final scenario in [
    'rateDouble',
    'negativeRate',
    'unitRate',
    'decreasingRate',
    'badCum',
    'initialCum',
    'gap',
    'invalidCap',
  ]) {
    test('invalid $scenario tier cannot supply maintenance', () {
      final row = riskRow('BTCUSDT'), brackets = <Map<String, dynamic>>[];
      brackets.addAll((row['brackets'] as List).cast<Map<String, dynamic>>());
      switch (scenario) {
        case 'rateDouble':
          brackets[0]['maintMarginRatio'] = 0.005;
        case 'negativeRate':
          brackets[0]['maintMarginRatio'] = '-0.1';
        case 'unitRate':
          brackets[1]['maintMarginRatio'] = '1';
        case 'decreasingRate':
          brackets[1]['maintMarginRatio'] = '0.001';
        case 'badCum':
          brackets[1]['cum'] = 6;
        case 'initialCum':
          brackets[0]['cum'] = 1;
        case 'gap':
          brackets[1]['notionalFloor'] = 1001;
        case 'invalidCap':
          brackets[1]['notionalCap'] = 1000;
      }
      expect(() => mapMainOrderRiskTiers([row], {'BTCUSDT'}), throwsFormatException);
    });
  }
}
