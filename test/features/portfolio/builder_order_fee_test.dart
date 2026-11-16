import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/builder_order_preflight.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/builder_order_fee.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';

import '../../support/live_order.dart';
import '../../support/attached_order.dart';

void main() {
  BuilderCommissionRates rates(String maker, String taker) =>
      BuilderCommissionRates(maker: Decimal.parse(maker), taker: Decimal.parse(taker));
  test('total targets are converted to additional rates, with exact decimal arithmetic', () {
    final crypto = rates('0', '0.0004');
    expect(crypto.feeFor(liveDraft(market: true)), Decimal.parse('0.0001'));
    expect(
      crypto.feeFor(liveDraft(timeInForce: LiveOrderTimeInForce.ioc)),
      Decimal.parse('0.0001'),
    );
    expect(
      crypto.feeFor(liveDraft(timeInForce: LiveOrderTimeInForce.postOnly)),
      Decimal.parse('0.00015'),
    );
    expect(crypto.feeFor(liveDraft()), Decimal.parse('0.0001'));
    expect(
      crypto.feeFor(liveDraft(timeInForce: LiveOrderTimeInForce.hidden)),
      Decimal.parse('0.0001'),
    );
    final rwa = rates('0', '0.000125');
    expect(rwa.feeFor(liveDraft(market: true)), Decimal.parse('0.000375'));
    expect(rwa.feeFor(liveDraft()), Decimal.parse('0.00015'));
    expect(
      rates('0.000149999999999999', '0.0004').feeFor(liveDraft()),
      Decimal.parse('0.000000000000000001'),
    );
  });
  test('all possible fills remain within both budgets across rates and policies', () {
    for (final maker in ['0', '0.00005', '0.00015']) {
      for (final taker in ['0', '0.000125', '0.0004', '0.0005']) {
        final r = rates(maker, taker);
        final fee = r.feeFor(liveDraft());
        expect(r.maker + fee <= Decimal.parse('0.00015'), true);
        expect(r.taker + fee <= Decimal.parse('0.0005'), true);
      }
    }
  });
  test('a post-only strategy still budgets its taker-capable protection legs', () {
    final r = rates('0', '0.0004');
    final draft = attachedIntent(policy: LiveOrderTimeInForce.postOnly).draft;
    expect(r.feeFor(draft), Decimal.parse('0.0001'));
    expect(
      rates('0', '0.000125').feeFor(attachedIntent(market: true).draft),
      Decimal.parse('0.000375'),
    );
    expect(rates('0', '0.000125').feeFor(attachedIntent().draft), Decimal.parse('0.00015'));
  });
  test('Group B taker costs are blocked without preventing a maker-only order', () {
    final r = rates('0', '0.001');
    expect(
      () => r.feeFor(liveDraft(market: true)),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderFeeAboveBudget')),
    );
    expect(() => r.feeFor(liveDraft()), throwsA(isA<AccountReadFailure>()));
    expect(
      () => r.feeFor(attachedIntent(policy: LiveOrderTimeInForce.postOnly).draft),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(
      r.feeFor(liveDraft(timeInForce: LiveOrderTimeInForce.postOnly)),
      Decimal.parse('0.00015'),
    );
  });
  test('zero remaining budget stays zero and sizing never understates exchange cost', () {
    expect(rates('0.00015', '0.0005').feeFor(liveDraft()), Decimal.zero);
    expect(builderSizingTakerFee(Decimal.parse('0.000125')), Decimal.parse('0.0005'));
    expect(builderSizingTakerFee(Decimal.parse('0.001')), Decimal.parse('0.001'));
  });
  test('missing, malformed, cross-symbol or float commission payloads cannot set fees', () {
    final valid = <String, Object?>{
      'symbol': 'BTCUSDT',
      'makerCommissionRate': '0',
      'takerCommissionRate': '0.0004',
    };
    expect(mapBuilderCommissionRates(valid, 'BTCUSDT').taker, Decimal.parse('0.0004'));
    for (final bad in [
      null,
      <String, Object?>{},
      {...valid, 'symbol': 'ETHUSDT'},
      {...valid, 'makerCommissionRate': null},
      {...valid, 'makerCommissionRate': '-0.01'},
      {...valid, 'takerCommissionRate': 0.0004},
      {...valid, 'takerCommissionRate': 'NaN'},
      {...valid, 'takerCommissionRate': '1'},
    ]) {
      expect(() => mapBuilderCommissionRates(bad, 'BTCUSDT'), throwsFormatException);
    }
  });
}
