import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/data/public_leverage_repository.dart';
import 'package:vanta/features/market/domain/public_leverage.dart';

void main() {
  test('verified official public response selects real per-market defaults', () {
    final values = mapPublicLeverage(
      jsonDecode(File('docs/reference/public-market-leverage-sample.json').readAsStringSync()),
    );
    expect(values['BTCUSDT']!.defaultLeverage(), 20);
    expect(values['ETHUSDT']!.defaultLeverage(), 20);
    expect(values['SUSHIUSDT']!.defaultLeverage(), 5);
    expect(values['SBETUSDT']!.defaultLeverage(), 10);
  });
  test('prefer 20x, fall back only to supported leverage including gaps', () {
    expect(PublicLeverage([(1, 200)]).defaultLeverage(), 20);
    expect(PublicLeverage([(1, 5)]).defaultLeverage(), 5);
    expect(PublicLeverage([(1, 10)]).defaultLeverage(), 10);
    expect(PublicLeverage([(1, 5), (25, 50)]).defaultLeverage(), 5);
    expect(PublicLeverage([(25, 50)]).defaultLeverage(), 25);
  });
  Map<String, Object?> payload(Object? rows) => {
    'success': true,
    'code': '000000',
    'data': {'brackets': rows},
  };
  Map<String, Object?> row(String symbol, Object? low, Object? high) => {
    'symbol': symbol,
    'riskBrackets': [
      {'minOpenPosLeverage': low, 'maxOpenPosLeverage': high},
    ],
  };
  test('map public catalog independently per market', () {
    final values = mapPublicLeverage(payload([row('BTCUSDT', 1, 200), row('SUSHIUSDT', 1, 5)]));
    expect(values['BTCUSDT']!.defaultLeverage(), 20);
    expect(values['SUSHIUSDT']!.defaultLeverage(), 5);
    expect(() => values.clear(), throwsUnsupportedError);
  });
  test('preserve exchange Unicode and hyphen symbols without applying generic defaults', () {
    final values = mapPublicLeverage(
      payload([row('龙虾USDT', 1, 5), row('B-MONEYUSDT', 1, 10), row('DEFAULT_BRACKETS', 1, 200)]),
    );
    expect(values['龙虾USDT']!.defaultLeverage(), 5);
    expect(values['B-MONEYUSDT']!.defaultLeverage(), 10);
    expect(values['UNKNOWNUSDT'], isNull);
  });
  test('reject malformed ranges, duplicate symbols and business failures', () {
    for (final range in [(0, 20), (10, 5), (1, 1001), ('1', 20), (1.5, 20)]) {
      expect(
        () => mapPublicLeverage(payload([row('BTCUSDT', range.$1, range.$2)])),
        throwsFormatException,
      );
    }
    expect(
      () => mapPublicLeverage(payload([row('BTCUSDT', 1, 5), row('BTCUSDT', 1, 20)])),
      throwsFormatException,
    );
    expect(
      () => mapPublicLeverage({'success': false, 'code': '123', 'message': 'Unavailable'}),
      throwsA(anything),
    );
  });
}
