import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';

import '../../support/live_order.dart';

void main() {
  for (final short in [false, true]) {
    for (final hedge in [false, true]) {
      test('close direction and parameters: short=$short hedge=$hedge', () {
        final intent = liveCloseIntent(short: short, hedge: hedge);
        expect(intent.context.validate(intent.draft), null);
        expect(intent.side, short ? 'BUY' : 'SELL');
        expect(intent.positionSide, hedge ? (short ? 'SHORT' : 'LONG') : 'BOTH');
        expect(intent.parameters['reduceOnly'], hedge ? null : 'true');
        for (final key in ['price', 'timeInForce', 'stopPrice', 'closePosition']) {
          expect(intent.parameters.containsKey(key), false, reason: key);
        }
      });
    }
  }
  test('ordinary one-way reduce-only cannot increase or reverse a position', () {
    final context = liveCloseContext();
    expect(context.validate(liveDraft(buy: false, reduceOnly: true)), null);
    expect(context.validate(liveDraft(reduceOnly: true)), 'liveClosePositionChanged');
    expect(
      context.validate(liveDraft(buy: false, reduceOnly: true, quantity: '0.011')),
      'liveCloseTooLarge',
    );
    final intent = liveCloseIntent(reduceOnly: true, market: false);
    expect(intent.parameters['reduceOnly'], 'true');
    expect(intent.parameters['price'], '80000');
    expect(intent.parameters['timeInForce'], 'GTC');
  });
  test('hedge reduction requires explicit original side and omits reduceOnly', () {
    final context = liveCloseContext(hedge: true);
    expect(context.validate(liveDraft(buy: false, reduceOnly: true)), 'liveOrderReduceHedge');
    expect(
      context.validate(liveDraft(buy: false, closingSide: 'BOTH')),
      'liveClosePositionChanged',
    );
    expect(context.validate(liveDraft(buy: true, closingSide: 'LONG')), 'liveClosePositionChanged');
    expect(
      context.validate(liveDraft(buy: true, closingSide: 'SHORT')),
      'liveClosePositionChanged',
    );
    expect(liveCloseIntent(hedge: true, market: false).parameters['reduceOnly'], null);
  });
  test('missing, zero, wrong mode and direction cannot close', () {
    final draft = liveDraft(buy: false, market: true, closingSide: 'BOTH');
    expect(liveContext().validate(draft), 'liveClosePositionChanged');
    expect(liveCloseContext(quantity: '0').validate(draft), 'liveClosePositionChanged');
    expect(liveCloseContext(short: true).validate(draft), 'liveClosePositionChanged');
    expect(
      liveCloseContext().validate(liveDraft(buy: false, closingSide: 'LONG')),
      'liveClosePositionChanged',
    );
  });
  test('only one-way reduction is exempt from minimum notional', () {
    // A very low buy limit still respects price ticks and the side-specific percent bound.
    final short = liveCloseContext(short: true);
    final draft = liveDraft(buy: true, price: '100', reduceOnly: true);
    expect(short.validate(draft), null);
    expect(short.validate(liveDraft(buy: true, price: '100')), 'liveOrderNotionalFilter');
    expect(
      liveCloseContext(
        short: true,
        hedge: true,
      ).validate(liveDraft(buy: true, price: '100', closingSide: 'SHORT')),
      'liveOrderNotionalFilter',
    );
    expect(
      short.validate(liveDraft(buy: true, price: '100.01', reduceOnly: true)),
      'liveOrderPriceFilter',
    );
    expect(
      short.validate(liveDraft(buy: true, quantity: '0.0011', reduceOnly: true)),
      'liveOrderQuantityFilter',
    );
  });
  test('reduction amount and over-close checks preserve decimal precision', () {
    final context = liveCloseContext();
    expect(
      context.validate(
        liveDraft(buy: false, closingSide: 'BOTH', quantity: '0.010000000000000001'),
      ),
      'liveCloseTooLarge',
    );
    for (final text in ['0', '-0.001', '1e-3', 'NaN']) {
      expect(
        context.validate(liveDraft(buy: false, closingSide: 'BOTH', quantity: text)),
        'liveOrderInvalidQuantity',
        reason: text,
      );
    }
  });
  test('fractions floor to market or limit lattice, retaining dust', () {
    final context = liveCloseContext(quantity: '0.0109');
    expect(context.closeFraction('BOTH', 25, market: true).toString(), '0.002');
    expect(context.closeFraction('BOTH', 100, market: true).toString(), '0.01');
    expect(context.closeFraction('BOTH', 0, market: true), Decimal.zero);
    expect(context.closeFraction('BOTH', 101, market: true), Decimal.zero);
    expect(context.closeFraction('LONG', 50, market: true), Decimal.zero);
    final rule = OrderQuantityRule(
      minimum: Decimal.parse('0.003'),
      maximum: Decimal.parse('10'),
      step: Decimal.parse('0.002'),
    );
    expect(rule.floor(Decimal.parse('0.008')).toString(), '0.007');
    expect(rule.floor(Decimal.parse('0.002')), Decimal.zero);
    final big = liveCloseContext(quantity: '150');
    final marketAmount = big.closeFraction('BOTH', 100, market: true).toString();
    expect(marketAmount, '150');
    expect(
      big.validate(
        liveDraft(buy: false, market: true, closingSide: 'BOTH', quantity: marketAmount),
      ),
      'liveOrderQuantityFilter',
    );
    expect(big.validate(liveDraft(buy: false, closingSide: 'BOTH', quantity: marketAmount)), null);
  });
  test('close PnL uses bid for long, ask for short, and entered limit', () {
    final long = liveCloseIntent(), short = liveCloseIntent(short: true);
    expect(long.context.estimatedClosePnl(long.draft).toString(), '4.995');
    expect(short.context.estimatedClosePnl(short.draft).toString(), '-5.005');
    final limit = liveCloseIntent(market: false);
    expect(limit.context.estimatedClosePnl(limit.draft).toString(), '5');
    final noBook = liveContext(positions: long.context.positions);
    expect(noBook.estimatedClosePnl(long.draft), null);
    expect(noBook.estimatedClosePnl(liveDraft()), null);
  });
  test('position mapping preserves exact signed amount and immutable rows', () {
    final context = liveCloseContext(short: true, quantity: '0.010000000000000001');
    final mapped = mapLiveOrderPositions(
      livePositionPayload(context),
      context.symbol,
      context.mode,
    );
    expect(mapped['BOTH']!.quantity.toString(), '-0.010000000000000001');
    expect(mapped['BOTH']!.entryPrice.toString(), '79000');
    expect(() => mapped.clear(), throwsUnsupportedError);
    expect(() => context.positions.clear(), throwsUnsupportedError);
    final hedge = liveCloseContext(hedge: true, short: true);
    expect(
      mapLiveOrderPositions(livePositionPayload(hedge), hedge.symbol, hedge.mode).keys,
      unorderedEquals(['LONG', 'SHORT']),
    );
  });
  test('position mapper rejects malformed, incomplete and contradictory positions', () {
    final context = liveCloseContext();
    for (final change in <void Function(List<Map<String, dynamic>>)>[
      (p) => p.single['positionAmt'] = 0.01,
      (p) => p.single['positionAmt'] = '1e-2',
      (p) => p.single['positionAmt'] = 'NaN',
      (p) => p.single['entryPrice'] = '0',
      (p) => p.single['symbol'] = 'ETHUSDT',
      (p) => p.add({...p.single}),
      (p) => p.single['positionSide'] = 'LONG',
    ]) {
      final payload = livePositionPayload(context);
      change(payload);
      expect(
        () => mapLiveOrderPositions(payload, context.symbol, context.mode),
        throwsFormatException,
      );
    }
    final hedge = liveCloseContext(hedge: true);
    final payload = livePositionPayload(hedge);
    payload.first['positionAmt'] = '-0.01';
    expect(() => mapLiveOrderPositions(payload, hedge.symbol, hedge.mode), throwsFormatException);
    payload.first['positionAmt'] = '0.01';
    payload.last['positionAmt'] = '0.01';
    expect(() => mapLiveOrderPositions(payload, hedge.symbol, hedge.mode), throwsFormatException);
    expect(
      () => mapLiveOrderPositions(
        livePositionPayload(context),
        context.symbol,
        FuturesPositionMode.hedge,
      ),
      throwsFormatException,
    );
  });
  test('close book requires positive sizes, correct symbol and non-crossed prices', () {
    final payload = <String, dynamic>{
      'symbol': 'BTCUSDT',
      'bidPrice': '79999',
      'askPrice': '80001',
      'bidQty': '0.001',
      'askQty': '0.001',
    };
    expect(mapLiveCloseBook(payload, 'BTCUSDT').ask.toString(), '80001');
    for (final entry in <String, dynamic>{
      'symbol': 'ETHUSDT',
      'bidPrice': '80002',
      'askPrice': 80001.0,
      'bidQty': '0',
      'askQty': '-1',
    }.entries) {
      expect(
        () => mapLiveCloseBook({...payload, entry.key: entry.value}, 'BTCUSDT'),
        throwsFormatException,
        reason: entry.key,
      );
    }
  });
  test('query verifies reduction flags and retains independent check timestamp', () {
    final intent = liveCloseIntent();
    final payload = liveQueryPayload(intent, status: 'FILLED');
    expect(mapLiveOrderQuery(payload, intent, checkedAt: liveOrderClock).checkedAt, liveOrderClock);
    for (final entry in <String, dynamic>{
      'reduceOnly': false,
      'closePosition': true,
      'side': 'BUY',
      'positionSide': 'LONG',
    }.entries) {
      expect(
        () => mapLiveOrderQuery({...payload, entry.key: entry.value}, intent),
        throwsFormatException,
        reason: entry.key,
      );
    }
    payload.remove('reduceOnly');
    expect(() => mapLiveOrderQuery(payload, intent), throwsFormatException);
    final hedge = liveCloseIntent(hedge: true);
    expect(mapLiveOrderQuery(liveQueryPayload(hedge), hedge).status, 'NEW');
  });
}
