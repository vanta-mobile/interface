import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/data/funding_fee_json.dart';
import 'package:vanta/features/funding/data/funding_fee_mapper.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';

import '../../support/funding_fee.dart';

void main() {
  FundingFeeQuote read(String source) => mapFundingFee(
    decodeFundingFeeJson(source),
    query: fundingFeeQuery,
    receivedAt: DateTime.utc(2026, 11, 3),
  );
  test(
    'numeric money preserves all source digits, no double conversion or inferred wallet gas',
    () {
      final quote = read(fundingFeePayload);
      expect(quote.assetFee.toString(), '0.123456789012345678901234567890123456789');
      expect(quote.usdFee.toString(), '0.100000000000000001');
      expect(quote.assetPriceUsd.toString(), '1.1235782');
      expect(quote.query, fundingFeeQuery);
      expect(quote.receivedAt.isUtc, true);
    },
  );
  for (final (raw, expected) in [
    ('0', '0'),
    ('1e-18', '0.000000000000000001'),
    ('123.4500e+2', '12345'),
    ('9007199254740993123456789', '9007199254740993123456789'),
    ('"0.000000000000000001"', '0.000000000000000001'),
    ('-0', '0'),
  ]) {
    test('numeric or string money $raw remains exact', () {
      final quote = read(
        '{"code":"000000","success":true,"data":{"gasCost":$raw,"gasUsdValue":0}}',
      );
      expect(quote.assetFee.toString(), expected);
      expect(quote.usdFee.toString(), '0');
      expect(quote.assetPriceUsd, null);
    });
  }
  for (final raw in [
    'null',
    'true',
    '[]',
    '{}',
    '-1',
    '"NaN"',
    '"Infinity"',
    '""',
    '"1,000"',
    '1e999999',
    '1e-999999',
    '"${'1' * 161}"',
  ]) {
    test('invalid fee $raw is rejected instead of yielding free withdrawal', () {
      expect(
        () => read('{"code":"000000","success":true,"data":{"gasCost":$raw,"gasUsdValue":0}}'),
        throwsFormatException,
      );
    });
  }
  for (final source in [
    '{}',
    '{"code":"000000","success":true,"data":{}}',
    '{"code":"000000","success":false,"data":{"gasCost":0,"gasUsdValue":0}}',
    '{"code":0,"success":true,"data":{"gasCost":0,"gasUsdValue":0}}',
    '{"code":"000000","success":true,"data":{"gasCost":0}}',
    '{"code":"000000","success":true,"data":{"gasCost":0,"gasUsdValue":0,"tokenPrice":0}}',
    '{"code":"000000","success":true,"data":{"gasCost":0,"gasUsdValue":-0.1}}',
  ]) {
    test('envelope and required USD/optional positive price are validated: $source', () {
      expect(() => read(source), throwsFormatException);
    });
  }
  test('JSON strings, escaped quotes and backslashes remain unchanged', () {
    final value = decodeFundingFeeJson(
      r'{"a":"1.234e+8","b":"a\\\"123","c":[true,null,12,{"4":0.5}]}',
    ) as Map;
    expect(value['a'], '1.234e+8');
    expect(value['b'], 'a\\"123');
    expect(value['c'], [
      true,
      null,
      '12',
      {'4': '0.5'},
    ]);
  });
  for (final source in [
    '{1:2}',
    '{"a":1,2:3}',
    '[01]',
    '[1.]',
    '[1e]',
    '[+1]',
    '[-]',
    '[1 2]',
    '{"a":NaN}',
    '"unterminated',
    r'"bad\q"',
  ]) {
    test('lossless decoder still rejects malformed JSON $source', () {
      expect(() => decodeFundingFeeJson(source), throwsFormatException);
    });
  }
  test('oversized payload and numeric lexemes are bounded before allocation', () {
    expect(() => decodeFundingFeeJson(' ' * 262145), throwsFormatException);
    expect(() => decodeFundingFeeJson('[${'1' * 161}]'), throwsFormatException);
  });
  test('numeric error code is preserved for shared safe transport classification', () {
    expect((decodeFundingFeeJson('{"code":-2015,"msg":"private detail"}') as Map)['code'], -2015);
  });
  test('query identity includes market, asset and chain', () {
    expect(
      fundingFeeQuery,
      const FundingFeeQuery(market: TransferMarket.perp, chainId: 56, asset: 'USDT'),
    );
    expect(
      fundingFeeQuery,
      isNot(const FundingFeeQuery(market: TransferMarket.spot, chainId: 56, asset: 'USDT')),
    );
    expect(
      fundingFeeQuery,
      isNot(const FundingFeeQuery(market: TransferMarket.perp, chainId: 1, asset: 'USDT')),
    );
    expect(
      fundingFeeQuery,
      isNot(const FundingFeeQuery(market: TransferMarket.perp, chainId: 56, asset: 'BNB')),
    );
    final queries = <FundingFeeQuery>{fundingFeeQuery};
    queries.add(FundingFeeQuery(market: TransferMarket.perp, chainId: 56, asset: 'USDT'));
    expect(queries.length, 1);
  });
}
