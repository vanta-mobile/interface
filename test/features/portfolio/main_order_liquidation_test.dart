import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity_preview.dart';
import 'package:vanta/features/portfolio/domain/main_order_liquidation.dart';
import 'package:vanta/features/portfolio/domain/main_order_liquidation_solver.dart';
import 'package:vanta/features/portfolio/domain/main_order_post_trade.dart';
import 'package:vanta/features/portfolio/domain/main_order_price_assumption.dart';
import 'package:vanta/features/portfolio/domain/main_order_revaluation.dart';
import 'package:vanta/features/portfolio/domain/position_margin_adjustment.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';
import '../../support/main_order_revaluation.dart';

Rational r(String n) => d(n).toRational();

class _Scenario {
  _Scenario({
    bool hedge = false,
    bool isolated = false,
    String wallet = '10',
    String? fee = '0.001',
    Map<String, dynamic>? payload,
    this.indices,
    Map<String, String> marks = const {'BTCUSDT': '100'},
    String last = '100',
    Map<String, List<MarginRiskTier>>? tiers,
  }) {
    raw = payload ?? capacityAccountPayload(hedge: hedge, isolated: isolated);
    final asset = (raw['assets'] as List).first as Map;
    asset['availableBalance'] = wallet;
    asset['crossWalletBalance'] = wallet;
    asset['crossUnPnl'] = '0';
    asset['initialMargin'] = '0';
    final c = capacityContext(
      hedge: hedge,
      isolated: isolated,
      payload: raw,
      assetMode: indices == null ? FuturesAssetMode.single : FuturesAssetMode.multi,
    );
    snapshot = withRevaluationFacts(
      assembledCapacity(context: c, payload: raw, indices: indices),
      takerFee: fee == null ? null : d(fee),
      tiers: tiers,
    );
    valuation = revalueMainOrderCapacity(
      snapshot: snapshot,
      marks: revaluationMarks(marks),
      references: {for (final s in marks.keys) s: revaluationReference(symbol: s, last: last)},
      indices: indices,
      now: liveOrderClock,
    );
  }
  late final Map<String, dynamic> raw;
  late final MainOrderCapacitySnapshot snapshot;
  late final MainOrderRevaluation valuation;
  final AssetIndexSnapshot? indices;

  MainOrderPostTrade? post({bool buy = true, String amount = '1', LiveOrderDraft? draft}) {
    final order = draft ?? liveDraft(buy: buy, price: '100');
    final prices = MainOrderPriceAssumption.resolve(valuation.context, order);
    return mainOrderPostTrade(
      snapshot: snapshot,
      context: valuation.context,
      draft: order,
      quantity: d(amount),
      cost: valuation.exposure.cost(
        buy: order.buy,
        quantity: d(amount),
        marginPrice: prices.margin,
        lossPrice: prices.loss,
      ),
    );
  }

  Rational? liquidation({bool buy = true, String amount = '1', LiveOrderDraft? draft}) {
    final order = draft ?? liveDraft(buy: buy, price: '100');
    final prices = MainOrderPriceAssumption.resolve(valuation.context, order);
    return mainOrderLiquidation(
      snapshot: snapshot,
      valuation: valuation,
      context: valuation.context,
      draft: order,
      quantity: d(amount),
      cost: valuation.exposure.cost(
        buy: order.buy,
        quantity: d(amount),
        marginPrice: prices.margin,
        lossPrice: prices.loss,
      ),
    );
  }
}

Map<String, dynamic> _positionPayload({
  String q = '1',
  bool isolated = false,
  String isoWallet = '10',
}) {
  final raw = capacityAccountPayload(isolated: isolated);
  raw['positions'] = [
    {...capacityPosition(quantity: q, isolated: isolated), 'isolatedWallet': isoWallet},
  ];
  return raw;
}

void main() {
  test('buy and sell are independent post-fill hypotheses including the actual fee', () {
    final s = _Scenario();
    expect(s.liquidation(), r('90.1') / r('0.995'));
    expect(s.liquidation(buy: false), r('109.9') / r('1.005'));
    expect(s.snapshot.account.positions.single.quantity, Decimal.zero);
    // At the long boundary: post-fee wallet + unrealized PnL = maintenance.
    final price = s.liquidation()!;
    expect(r('9.9') + price - r('100'), price * r('0.005'));
  });
  test('signed zero fee is valid; missing or malformed fee never means zero', () {
    expect(_Scenario(fee: '0').liquidation(), r('90') / r('0.995'));
    for (final fee in <String?>[null, '-0.01', '1']) {
      expect(_Scenario(fee: fee).liquidation(), null);
    }
  });
  test('same-side fills use a weighted entry value without early rounding', () {
    final s = _Scenario(
      payload: _positionPayload(q: '2'),
      wallet: '50',
    );
    final post = s.post(
      amount: '1',
      draft: liveDraft(price: '101'),
    )!;
    expect(post.quantity, d('3'));
    expect(post.entryValue, r('301'));
    expect(post.crossWalletChange, r('-0.101'));
    expect(
      s.liquidation(
        amount: '1',
        draft: liveDraft(price: '101'),
      ),
      r('251.101') / r('2.985'),
    );
  });
  test('partial reduction realizes PnL while preserving the residual entry', () {
    final s = _Scenario(
      payload: _positionPayload(q: '2'),
      wallet: '50',
    );
    final post = s.post(
      buy: false,
      amount: '0.5',
      draft: liveDraft(buy: false, price: '110'),
    )!;
    expect(post.quantity, d('1.5'));
    expect(post.entryValue, r('150'));
    expect(post.crossWalletChange, r('4.945'));
    expect(
      s.liquidation(
        buy: false,
        amount: '0.5',
        draft: liveDraft(buy: false, price: '110'),
      ),
      r('95.055') / r('1.4925'),
    );
  });
  test('exact close has no residual liquidation estimate', () {
    final s = _Scenario(payload: _positionPayload());
    expect(s.post(buy: false)!.quantity, Decimal.zero);
    expect(s.liquidation(buy: false), null);
  });
  test('one-way reversal realizes only the closed amount and starts a new entry', () {
    final s = _Scenario(payload: _positionPayload(), wallet: '30');
    final post = s.post(
      buy: false,
      amount: '2',
      draft: liveDraft(buy: false, price: '110'),
    )!;
    expect(post.quantity, d('-1'));
    expect(post.entryValue, r('-110'));
    expect(post.crossWalletChange, r('9.78'));
    expect(
      s.liquidation(
        buy: false,
        amount: '2',
        draft: liveDraft(buy: false, price: '110'),
      ),
      r('149.78') / r('1.005'),
    );
  });
  test('isolated opening uses allocated margin and excludes unrelated cross wealth', () {
    for (final wallet in ['10', '50000']) {
      final s = _Scenario(isolated: true, wallet: wallet);
      expect(s.post()!.isolatedWallet, r('10'));
      expect(s.liquidation(), r('90') / r('0.995'));
    }
  });
  test('isolated partial reductions release proportional collateral for both signs', () {
    for (final q in ['2', '-2']) {
      final s = _Scenario(
        isolated: true,
        payload: _positionPayload(q: q, isolated: true, isoWallet: '20'),
      );
      final post = s.post(buy: q.startsWith('-'), amount: '0.5')!;
      expect(post.isolatedWallet, r('15'));
      expect(post.quantity.abs(), d('1.5'));
    }
  });
  test('isolated loss exceeding released collateral reduces the remaining wallet', () {
    final s = _Scenario(
      isolated: true,
      payload: _positionPayload(q: '2', isolated: true, isoWallet: '20'),
    );
    final post = s.post(
      buy: false,
      amount: '0.5',
      draft: liveDraft(buy: false, price: '80'),
    )!;
    expect(post.isolatedWallet, r('10')); // 15 retained, 5 of the loss uncovered by release.
  });
  test('isolated reversal allocates the new leg after releasing the old one', () {
    final s = _Scenario(isolated: true, payload: _positionPayload(isolated: true, isoWallet: '10'));
    final post = s.post(
      buy: false,
      amount: '2',
      draft: liveDraft(buy: false, price: '90'),
    )!;
    expect(post.quantity, d('-1'));
    expect(post.entryValue, r('-90'));
    expect(post.isolatedWallet, r('19')); // 9 new margin + 10 adverse opening loss.
  });
  test('cross hedge includes the unchanged opposite leg; isolated hedge does not', () {
    for (final isolated in [false, true]) {
      final raw = capacityAccountPayload(hedge: true, isolated: isolated);
      raw['positions'] = [
        capacityPosition(side: 'LONG', isolated: isolated),
        {
          ...capacityPosition(side: 'SHORT', quantity: '-0.5', isolated: isolated),
          'isolatedWallet': '5',
        },
      ];
      final s = _Scenario(hedge: true, isolated: isolated, payload: raw);
      expect(s.liquidation(), isolated ? r('90') / r('0.995') : r('40.1') / r('0.4925'));
    }
  });
  test('other-contract Mark PnL and maintenance affect cross liquidation', () {
    final raw = capacityAccountPayload();
    (raw['positions'] as List).add(capacityPosition(symbol: 'ETHUSDT', quantity: '1'));
    final s = _Scenario(payload: raw, marks: {'BTCUSDT': '100', 'ETHUSDT': '120'}, last: '80');
    // Other position +20 Mark PnL, maintenance 0.6. Last-only sizing PnL is -20.
    expect(s.valuation.assets['USDT']!.crossPnl, d('-20'));
    expect(s.valuation.assets['USDT']!.crossMarkPnl, d('20'));
    expect(s.liquidation(), r('70.7') / r('0.995'));
  });
  test('multi-asset collateral uses signed quantities and current bid/ask rates', () {
    for (final bnb in ['0.01', '-0.01']) {
      final raw = capacityAccountPayload();
      (raw['assets'] as List).add({
        ...capacityAsset(asset: 'BNB'),
        'crossWalletBalance': bnb,
        'crossUnPnl': '0',
        'initialMargin': '0',
      });
      final s = _Scenario(payload: raw, indices: capacityIndices());
      final other = bnb.startsWith('-') ? r('-3.1') : r('3');
      expect(s.liquidation(), (r('90.1') - other) / r('0.995'));
    }
  });
  test('non-margin collateral is excluded without requiring a missing rate', () {
    final raw = capacityAccountPayload();
    (raw['assets'] as List).add({
      ...capacityAsset(asset: 'UNKNOWN'),
      'marginAvailable': false,
      'crossWalletBalance': '999999',
    });
    expect(
      _Scenario(payload: raw, indices: capacityIndices()).liquidation(),
      r('90.1') / r('0.995'),
    );
  });
  test('blank and zero-percent inputs have no synthetic liquidation price', () {
    final s = _Scenario();
    for (final percent in <int?>[null, 0]) {
      final p = MainOrderCapacityPreview(
        snapshot: s.snapshot,
        valuation: s.valuation,
        draft: liveDraft(price: '100'),
        unit: OrderSizeUnit.base,
        input: '',
        percent: percent,
      );
      expect(p.buy.liquidation, null);
      expect(p.sell.liquidation, null);
    }
  });
  test('preview production path attaches both prices and hides invalid or oversized amounts', () {
    final s = _Scenario(wallet: '20');
    final p = MainOrderCapacityPreview(
      snapshot: s.snapshot,
      valuation: s.valuation,
      draft: liveDraft(price: '100'),
      unit: OrderSizeUnit.base,
      input: '1',
    );
    expect(p.buy.liquidation, r('80.1') / r('0.995'));
    expect(p.sell.liquidation, r('119.9') / r('1.005'));
    final tooLarge = MainOrderCapacityPreview(
      snapshot: s.snapshot,
      valuation: s.valuation,
      draft: liveDraft(price: '100'),
      unit: OrderSizeUnit.base,
      input: '500',
    );
    expect(tooLarge.buy.liquidation, null);
  });
  test('market, conditional and explicit trailing hypotheses use their own entry prices', () {
    final s = _Scenario(wallet: '30');
    final market = liveDraft(market: true, price: '');
    expect(s.post(draft: market)!.executionPrice, d('101.05'));
    final conditional = LiveOrderDraft(
      buy: true,
      market: true,
      quantity: '1',
      price: '',
      trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '110'),
    );
    expect(s.post(draft: conditional)!.executionPrice, d('110'));
    final trailing = LiveOrderDraft(
      buy: true,
      market: true,
      quantity: '1',
      price: '',
      trailing: const LiveOrderTrailing(callbackRate: '1', activationPrice: '95'),
    );
    expect(s.post(draft: trailing)!.executionPrice, d('95'));
    final autoTrailing = LiveOrderDraft(
      buy: true,
      market: true,
      quantity: '1',
      price: '',
      trailing: const LiveOrderTrailing(callbackRate: '1'),
    );
    expect(s.liquidation(draft: autoTrailing), null);
  });

  group('exact piecewise liquidation solver', () {
    final tiers = [
      MarginRiskTier(floor: d('0'), cap: d('1000'), rate: d('0.005'), cumulative: d('0')),
      MarginRiskTier(floor: d('1000'), cap: d('100000'), rate: d('0.01'), cumulative: d('5')),
    ];
    Rational? solve({
      String q = '1',
      String entry = '100',
      String wallet = '10',
      String other = '0',
      String bid = '1',
      String ask = '1',
      List<LiquidationLeg>? legs,
      List<MarginRiskTier>? risk,
    }) => solveMainOrderLiquidation(
      legs: legs ?? [LiquidationLeg(quantity: r(q), entryValue: r(entry))],
      tiers: risk ?? tiers,
      wallet: r(wallet),
      otherEquityLessMaintenance: r(other),
      otherMaintenance: Rational.zero,
      bidRate: r(bid),
      askRate: r(ask),
      mark: r('100'),
    );
    test('candidate exactly on a tier floor is validated in the higher tier', () {
      expect(solve(q: '10', entry: '1100', wallet: '105'), r('100'));
    });
    test('candidate can cross the currently occupied risk tier', () {
      expect(solve(q: '10', entry: '1200', wallet: '10'), r('1185') / r('9.9'));
    });
    test('risk notional cap is not treated as unlimited', () {
      expect(solve(q: '1', entry: '200000', wallet: '10'), null);
    });
    test('liability branch uses ask for negative collateral equity', () {
      // Equity at the root is negative; +10 USD from other collateral supports it.
      final price = solve(q: '1', entry: '100', wallet: '0', other: '10', bid: '0.9', ask: '1.1')!;
      expect(price, r('100') / r('1.0945'));
      expect((price - r('100')) * r('1.1') + r('10'), price * r('0.005') * r('1.1'));
    });
    test('equal hedge sizes can still liquidate as gross maintenance grows', () {
      expect(
        solve(
          wallet: '1',
          legs: [
            LiquidationLeg(quantity: r('1'), entryValue: r('100')),
            LiquidationLeg(quantity: r('-1'), entryValue: r('-100')),
          ],
        ),
        r('100'),
      );
    });
    test('no positive root and fully absent legs are unknown', () {
      expect(solve(wallet: '200'), null);
      expect(solve(legs: []), null);
    });
    test('discontinuous, missing and invalid tiers do not yield a guessed price', () {
      expect(solve(risk: []), null);
      expect(
        solve(
          risk: [
            tiers.first,
            MarginRiskTier(floor: d('1000'), cap: d('2000'), rate: d('0.01'), cumulative: d('0')),
          ],
        ),
        null,
      );
      expect(solve(bid: '2', ask: '1'), null);
    });
    test('all operations retain precision beyond a double mantissa', () {
      final price = solve(
        q: '1',
        entry: '100000000000000001',
        wallet: '10000000000000000',
        risk: [
          MarginRiskTier(
            floor: d('0'),
            cap: d('100000000000000000000000'),
            rate: d('0.005'),
            cumulative: d('0'),
          ),
        ],
      );
      expect(price, r('90000000000000001') / r('0.995'));
    });
  });
}
