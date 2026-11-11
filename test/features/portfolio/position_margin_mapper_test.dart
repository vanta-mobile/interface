import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/exact_json.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/portfolio/data/position_margin_mapper.dart';

import '../../support/position_margin_adjustment.dart';

void main() {
  test('fractional JSON numbers retain exact lexical value and integer fields remain integers', () {
    final json = decodePositionMarginJson(
      '{"code":200,"amount":0.100000000000000001,"rows":[1.25,2]}',
    ) as Map;
    expect(json['amount'], '0.100000000000000001');
    expect(json['code'], 200);
    expect(json['rows'], ['1.25', 2]);
  });
  test('large account payload preserves exact money while funding keeps its default bound', () {
    final source = '{"metadata":"${'x' * 900000}","amount":0.100000000000000001}';
    final decoded = decodePositionMarginJson(source) as Map;
    expect(decoded['amount'], '0.100000000000000001');
    expect(() => decodeFundingJson(source), throwsFormatException);
    expect(() => decodePositionMarginJson('"${'x' * (16 * 1024 * 1024)}"'), throwsFormatException);
  });
  test('Aster risk exponent coefficients preserve their exact decimal value', () {
    expect(marginDecimal('1.4481993E7'), md('14481993'));
    expect(marginDecimal('4.18161993E8'), md('418161993'));
    expect(marginDecimal('1e-8'), md('0.00000001'));
    for (final bad in ['NaN', 'Infinity', '1e161', '1e-161', '1e9999']) {
      expect(() => marginDecimal(bad), throwsFormatException);
    }
  });
  test('tiers accept object and scoped array with consistent cumulative maintenance', () {
    expect(mapMarginRiskTiers(marginBrackets(), 'BTCUSDT').last.cumulative, md('1.5'));
    expect(mapMarginRiskTiers([marginBrackets()], 'BTCUSDT').length, 2);
  });
  for (final value in ['-0.1', '1', '1.01', 'bad']) {
    test('invalid maintenance rate $value rejected', () {
      final data = marginBrackets();
      ((data['brackets'] as List).first as Map)['maintMarginRatio'] = value;
      expect(() => mapMarginRiskTiers(data, 'BTCUSDT'), throwsFormatException);
    });
  }
  test('server cumulative offsets need not imply exact tier continuity', () {
    final data = marginBrackets();
    ((data['brackets'] as List).last as Map)['cum'] = '1.4';
    expect(mapMarginRiskTiers(data, 'BTCUSDT').last.cumulative, md('1.4'));
    ((data['brackets'] as List).last as Map)['cum'] = '3.1';
    expect(() => mapMarginRiskTiers(data, 'BTCUSDT'), throwsFormatException);
  });
  test('exact original ID and terms match history', () {
    expect(matchMarginHistory([marginHistoryRow()], marginRecord(), marginClock), marginClock);
    expect(
      matchMarginHistory([marginHistoryRow(reference: 'different')], marginRecord(), marginClock),
      null,
    );
    expect(matchMarginHistory([], marginRecord(), marginClock), null);
  });
  for (final entry in <String, Object?>{
    'symbol': 'ETHUSDT',
    'positionSide': 'LONG',
    'asset': 'BNB',
    'amount': '11',
    'type': 2,
    'deltaType': 'TRADE',
    'time': marginClock.millisecondsSinceEpoch - 30001,
  }.entries) {
    test('same reference wrong ${entry.key} never proves success', () {
      final row = marginHistoryRow()..[entry.key] = entry.value;
      expect(() => matchMarginHistory([row], marginRecord(), marginClock), throwsFormatException);
    });
  }
  test('duplicate exact ID and more than 500 rows do not prove success', () {
    expect(
      () =>
          matchMarginHistory([marginHistoryRow(), marginHistoryRow()], marginRecord(), marginClock),
      throwsFormatException,
    );
    expect(
      () => matchMarginHistory(List.filled(501, marginHistoryRow()), marginRecord(), marginClock),
      throwsFormatException,
    );
  });
  test('journal roundtrip preserves frozen terms but rejects foreign fields', () {
    final record = marginRecord();
    expect(decodeWalletOperations(encodeWalletOperations([record])).single.terms, record.terms);
    final json = record.toJson();
    json['terms'] = {...record.terms, 'signature': 'secret'};
    expect(() => WalletOperationRecord.fromJson(json), throwsFormatException);
  });
}
