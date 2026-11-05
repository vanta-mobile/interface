import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/exact_json.dart';
import 'package:vanta/features/portfolio/data/asset_yield_mapper.dart';
import 'package:vanta/features/portfolio/domain/asset_yield.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  const usdf =
      '{"code":"000000","success":true,"data":{'
      '"baseApyList":[{"day":"2026-11-04","apy":1.750000000000000001}],'
      '"tradeApyList":[{"day":"2026-11-04","apy":9.700000000000000002}]}}';
  const lista =
      '{"code":"000000000","data":{"comprehensiveApy":"0.014499999999999999",'
      '"time":"2026-11-04","updateTime":1793750400000}}';
  AssetYieldQuote parse(String source, [YieldAsset asset = YieldAsset.usdf]) =>
      mapAssetYield(decodeFundingJson(source), asset: asset, receivedAt: now);

  test('USDF adds percentage points exactly without double or another factor of 100', () {
    final quote = parse(usdf);
    expect(quote.percent.toString(), '11.450000000000000003');
    expect(quote.basePercent.toString(), '1.750000000000000001');
    expect(quote.tradePercent.toString(), '9.700000000000000002');
    expect(quote.sourceDay, DateTime.utc(2026, 11, 4));
    expect(quote.receivedAt, now);
    expect(quote.freshAt(now), true);
  });
  test('Lista comprehensive ratio becomes exact percentage; not apr or launchPoolApy', () {
    final quote = parse(lista, YieldAsset.asbnb);
    expect(quote.percent.toString(), '1.4499999999999999');
    expect(quote.percent.toStringAsFixed(2), '1.45');
    expect(quote.basePercent, null);
    expect(quote.tradePercent, null);
    expect(quote.updatedAt, DateTime.utc(2026, 11, 4));
  });
  test('published numeric Lista ratio retains raw digits too', () {
    expect(
      parse(
        lista.replaceAll('"0.014499999999999999"', '0.014499999999999999'),
        YieldAsset.asbnb,
      ).percent.toString(),
      '1.4499999999999999',
    );
  });
  test('source order is preserved; no invented sorting of historical rate rows', () {
    final quote = parse(
      usdf.replaceAll(
        '1.750000000000000001}',
        '1.750000000000000001},{"day":"2026-11-03","apy":99}',
      ),
    );
    expect(quote.percent.toString(), '11.450000000000000003');
  });
  test('explicit zero and negative published rates are preserved', () {
    final zero = usdf
        .replaceAll('1.750000000000000001', '0')
        .replaceAll('9.700000000000000002', '0');
    expect(parse(zero).percent, Decimal.zero);
    expect(parse(zero.replaceFirst('"apy":0', '"apy":-0.125')).percent, Decimal.parse('-0.125'));
  });
  for (final value in ['null', 'true', '"NaN"', '"Infinity"', '1e-3', '"1%"', '" 1"', '""', '{}']) {
    test('rejects invalid USDF rate $value instead of defaulting zero', () {
      expect(() => parse(usdf.replaceFirst('1.750000000000000001', value)), throwsFormatException);
    });
  }
  for (final value in ['null', 'false', '"nan"', '"1e-3"', '[]', '"${'1' * 161}"']) {
    test('rejects invalid Lista comprehensive ratio $value', () {
      expect(
        () => parse(lista.replaceFirst('"0.014499999999999999"', value), YieldAsset.asbnb),
        throwsFormatException,
      );
    });
  }
  for (final day in [
    '2026-02-30',
    '2026-13-01',
    '2026-11-4',
    '2026-11-04T00:00:00Z',
    '1969-12-31',
  ]) {
    test('rejects invalid source calendar date $day', () {
      expect(() => parse(usdf.replaceAll('2026-11-04', day)), throwsFormatException);
    });
  }
  test('different base/trading dates cannot be combined', () {
    expect(() => parse(usdf.replaceFirst('2026-11-04', '2026-11-03')), throwsFormatException);
  });
  for (final change in [
    (String s) => s.replaceFirst('"success":true', '"success":false'),
    (String s) => s.replaceFirst('"code":"000000"', '"code":"100001"'),
    (String s) => s.replaceFirst('"data":{', '"missing":{'),
    (String s) => s.replaceFirst('"baseApyList"', '"missing"'),
    (String s) => s.replaceFirst('"tradeApyList"', '"missing"'),
    (String s) => s.replaceFirst('"apy":', '"missing":'),
    (String s) => s.replaceFirst('"day":', '"missing":'),
  ]) {
    test('missing or unsuccessful USDF data is unavailable (${change(usdf).hashCode})', () {
      expect(() => parse(change(usdf)), throwsFormatException);
    });
  }
  test('empty and overlarge USDF lists are invalid', () {
    final p = decodeFundingJson(usdf) as Map<String, dynamic>;
    final data = p['data'] as Map<String, dynamic>;
    final first = (data['baseApyList'] as List).first;
    data['baseApyList'] = <Object?>[];
    expect(() => mapAssetYield(p, asset: YieldAsset.usdf, receivedAt: now), throwsFormatException);
    data['baseApyList'] = List.filled(5001, first);
    expect(() => mapAssetYield(p, asset: YieldAsset.usdf, receivedAt: now), throwsFormatException);
  });
  for (final raw in ['0', '-1', '1.5', '"1793750400000"', '253402300800000']) {
    test('invalid publisher timestamp $raw', () {
      expect(
        () => parse(lista.replaceFirst('1793750400000', raw), YieldAsset.asbnb),
        throwsFormatException,
      );
    });
  }
  test('missing optional publisher timestamp remains unknown', () {
    expect(
      parse(lista.replaceFirst(',"updateTime":1793750400000', ''), YieldAsset.asbnb).updatedAt,
      null,
    );
  });
  test('no native Dart double accepted at data boundary', () {
    expect(
      () => mapAssetYield(
        {
          'code': '000000000',
          'data': {'time': '2026-11-04', 'comprehensiveApy': 0.0145},
        },
        asset: YieldAsset.asbnb,
        receivedAt: now,
      ),
      throwsFormatException,
    );
  });
  test('receipt and source freshness are independent with exact five-minute boundary', () {
    final quote = parse(usdf);
    expect(
      quote.freshAt(now.add(const Duration(minutes: 5)).subtract(const Duration(microseconds: 1))),
      true,
    );
    expect(quote.freshAt(now.add(const Duration(minutes: 5))), false);
    expect(quote.freshAt(now.subtract(const Duration(seconds: 31))), false);
    expect(quote.freshAt(now.subtract(const Duration(seconds: 30))), true);
    expect(parse(usdf.replaceAll('2026-11-04', '2026-11-02')).freshAt(now), true);
    expect(parse(usdf.replaceAll('2026-11-04', '2026-11-01')).freshAt(now), false);
    expect(parse(usdf.replaceAll('2026-11-04', '2026-11-05')).freshAt(now), false);
  });
  test('future publisher timestamp is not a fresh quote', () {
    expect(
      parse(
        lista.replaceFirst(
          '1793750400000',
          '${now.add(const Duration(minutes: 1)).millisecondsSinceEpoch}',
        ),
        YieldAsset.asbnb,
      ).freshAt(now),
      false,
    );
  });
  test('support is exact symbols only; no suffix or case guessing', () {
    expect(YieldAsset.forSymbol('USDF'), YieldAsset.usdf);
    expect(YieldAsset.forSymbol('ASBNB'), YieldAsset.asbnb);
    for (final symbol in ['usdf', 'asBNB', 'BNB', 'USDT', 'USDF2']) {
      expect(YieldAsset.forSymbol(symbol), null);
    }
  });
  test('duplicate JSON financial fields are rejected', () {
    expect(() => parse(usdf.replaceFirst('"apy":', '"apy":1,"apy":')), throwsFormatException);
  });
}
