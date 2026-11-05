import 'package:flutter_test/flutter_test.dart';
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
  test('noncontinuous cumulative offsets rejected', () {
    final data = marginBrackets();
    ((data['brackets'] as List).last as Map)['cum'] = '1.4';
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
