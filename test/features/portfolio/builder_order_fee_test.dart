import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/domain/builder_authorization.dart';
import 'package:vanta/features/portfolio/data/builder_order_preflight.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/builder_order_fee.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';

import '../../support/live_order.dart';
import '../../support/attached_order.dart';

void main() {
  test('fixed taker rate applies to market, GTC, IOC, and hidden orders', () {
    final rates = const BuilderCommissionRates();
    expect(rates.feeFor(liveDraft(market: true)), VantaBuilder.takerRate);
    expect(
      rates.feeFor(liveDraft(timeInForce: LiveOrderTimeInForce.ioc)),
      VantaBuilder.takerRate,
    );
    expect(rates.feeFor(liveDraft()), VantaBuilder.takerRate);
    expect(
      rates.feeFor(liveDraft(timeInForce: LiveOrderTimeInForce.hidden)),
      VantaBuilder.takerRate,
    );
  });
  test('fixed maker rate applies only to strictly post-only orders with no exits', () {
    final rates = const BuilderCommissionRates();
    expect(
      rates.feeFor(liveDraft(timeInForce: LiveOrderTimeInForce.postOnly)),
      VantaBuilder.makerRate,
    );
  });
  test('post-only entry with exits uses taker rate because exits may fill as taker', () {
    final rates = const BuilderCommissionRates();
    final draft = attachedIntent(policy: LiveOrderTimeInForce.postOnly).draft;
    expect(rates.feeFor(draft), VantaBuilder.takerRate);
    expect(rates.feeFor(attachedIntent(market: true).draft), VantaBuilder.takerRate);
    expect(rates.feeFor(attachedIntent().draft), VantaBuilder.takerRate);
  });
  test('builderSizingTakerFee adds builder rate on top of exchange base rate', () {
    expect(builderSizingTakerFee(Decimal.parse('0.000125')), Decimal.parse('0.000625'));
    expect(builderSizingTakerFee(Decimal.parse('0.001')), Decimal.parse('0.0015'));
    expect(builderSizingTakerFee(Decimal.zero), VantaBuilder.takerRate);
  });
  test('an expired fee quote fails closed before dispatch', () {
    final q = BuilderOrderQuote(Decimal.zero, VantaBuilder.approvalCap, lifetime: Duration.zero);
    expect(
      q.checkFresh,
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderFeeQuoteExpired')),
    );
  });
}
