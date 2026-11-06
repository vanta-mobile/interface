import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/main_order_price_assumption.dart';

import '../../support/live_order.dart';

LiveOrderContext prices({
  String mark = '100',
  String? bid = '99',
  String? ask = '101',
  int? precision = 2,
  bool hedge = false,
}) {
  final original = liveContext();
  final payload = liveExchangePayload();
  (payload['symbols'] as List).single['pricePrecision'] = precision;
  return LiveOrderContext(
    address: original.address,
    rules: mapLiveOrderRules(payload, 'BTCUSDT'),
    mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay,
    marginMode: original.marginMode,
    leverage: original.leverage,
    markPrice: Decimal.parse(mark),
    receivedAt: original.receivedAt,
    positions: const {},
    bid: bid == null ? null : Decimal.parse(bid),
    ask: ask == null ? null : Decimal.parse(ask),
  );
}

void main() {
  for (final (buy, limit, margin, loss) in [
    (true, '110', '110', '110'),
    (true, '90', '90', '90'),
    (false, '110', '110', '110'),
    (false, '90', '100', '90'),
  ]) {
    test('limit margin and loss references $buy $limit', () {
      final result = MainOrderPriceAssumption.resolve(prices(), liveDraft(buy: buy, price: limit));
      expect(result.margin, Decimal.parse(margin));
      expect(result.loss, Decimal.parse(loss));
    });
  }
  test('sell limit margin can use a better bid while loss retains entered limit', () {
    final result = MainOrderPriceAssumption.resolve(
      prices(bid: '105', ask: '106'),
      liveDraft(buy: false, price: '90'),
    );
    expect(result.margin, Decimal.fromInt(105));
    expect(result.loss, Decimal.fromInt(90));
  });
  for (final hedge in [true, false]) {
    test(
      'market buy buffers ask then floors at declared precision, either position mode $hedge',
      () {
        final result = MainOrderPriceAssumption.resolve(
          prices(hedge: hedge),
          liveDraft(market: true, price: ''),
        );
        expect(result.margin, Decimal.parse('101.05'));
        expect(result.loss, result.margin);
        // 0.1 tick is distinct from the exchange's 2-place display precision.
        expect(prices().rules.acceptsPrice(result.margin), false);
      },
    );
  }
  test('market sell uses bid without buffer or tick rounding', () {
    final result = MainOrderPriceAssumption.resolve(
      prices(bid: '99.123456789'),
      liveDraft(buy: false, market: true, price: ''),
    );
    expect(result.margin, Decimal.parse('99.123456789'));
    expect(result.loss, result.margin);
  });
  test('buffer calculation preserves integers beyond binary exact range', () {
    final result = MainOrderPriceAssumption.resolve(
      prices(
        mark: '9007199254740993',
        bid: '9007199254740992',
        ask: '9007199254740993.000000000000000001',
        precision: 18,
      ),
      liveDraft(market: true, price: ''),
    );
    expect(result.margin, Decimal.parse('9011702854368363.496500000000000001'));
  });
  test('market buy floors rather than rounding up at precision zero', () {
    final result = MainOrderPriceAssumption.resolve(
      prices(ask: '101.99', precision: 0),
      liveDraft(market: true, price: ''),
    );
    expect(result.margin, Decimal.fromInt(102));
  });
  for (final buy in [true, false]) {
    test('missing same-side book reference uses explicit mark fallback $buy', () {
      final result = MainOrderPriceAssumption.resolve(
        prices(bid: null, ask: null),
        liveDraft(market: true, price: '', buy: buy),
      );
      expect(result.margin, Decimal.parse(buy ? '100.05' : '100'));
    });
  }
  test('missing precision blocks only market buy assumption without inventing tick precision', () {
    final context = prices(precision: null);
    expect(
      () => MainOrderPriceAssumption.resolve(context, liveDraft(market: true, price: '')),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveCapacityPriceUnavailable'),
      ),
    );
    expect(
      MainOrderPriceAssumption.resolve(context, liveDraft(price: '100')).margin,
      Decimal.fromInt(100),
    );
    expect(
      MainOrderPriceAssumption.resolve(
        context,
        liveDraft(market: true, buy: false, price: ''),
      ).margin,
      Decimal.fromInt(99),
    );
  });
  for (final kind in LiveOrderTriggerKind.values) {
    for (final market in [false, true]) {
      test(
        'conditional reference is current cost assumption, not trigger fill prediction $kind $market',
        () {
          final result = MainOrderPriceAssumption.resolve(
            prices(),
            liveDraft(
              market: market,
              price: market ? '' : '98',
              trigger: LiveOrderTrigger(kind: kind, price: '120'),
            ),
          );
          expect(result.margin, Decimal.parse(market ? '101.05' : '98'));
          expect(result.loss, Decimal.parse(market ? '101.05' : '98'));
        },
      );
    }
  }
  test('trailing uses current market reference rather than activation price', () {
    final result = MainOrderPriceAssumption.resolve(
      prices(),
      liveDraft(
        market: true,
        price: '',
        trailing: const LiveOrderTrailing(callbackRate: '1', activationPrice: '150'),
      ),
    );
    expect(result.margin, Decimal.parse('101.05'));
  });
  for (final (peg, buy, margin, loss) in [
    (LiveOrderPeg.counterparty, true, '101', '101'),
    (LiveOrderPeg.counterparty, false, '100', '99'),
    (LiveOrderPeg.queue, true, '99', '99'),
    (LiveOrderPeg.queue, false, '101', '101'),
  ]) {
    test('ordinary BBO uses selected current book with limit cost branches $peg $buy', () {
      final result = MainOrderPriceAssumption.resolve(
        prices(),
        liveDraft(price: '', peg: peg, buy: buy),
      );
      expect(result.margin, Decimal.parse(margin));
      expect(result.loss, Decimal.parse(loss));
    });
  }
  for (final invalid in ['', '0', '-1', 'NaN', '1e2']) {
    test('invalid entered limit cannot become a free reference $invalid', () {
      expect(
        () => MainOrderPriceAssumption.resolve(prices(), liveDraft(price: invalid)),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveOrderInvalidPrice')),
      );
    });
  }
  for (final raw in [-1, 81, 1.5, '2', true]) {
    test('invalid declared precision fails at the exchange boundary $raw', () {
      final payload = liveExchangePayload();
      (payload['symbols'] as List).single['pricePrecision'] = raw;
      expect(() => mapLiveOrderRules(payload, 'BTCUSDT'), throwsFormatException);
    });
  }
  test('crossed or nonpositive market facts cannot produce cost references', () {
    for (final data in [
      prices(mark: '0'),
      prices(bid: '0'),
      prices(ask: '0'),
      prices(bid: '102'),
    ]) {
      expect(
        () => MainOrderPriceAssumption.resolve(data, liveDraft(market: true, price: '')),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid')),
      );
    }
  });
  test('floor underflow is unavailable rather than a zero-cost execution', () {
    expect(
      () => MainOrderPriceAssumption.resolve(
        prices(mark: '0.001', bid: null, ask: null, precision: 0),
        liveDraft(market: true, price: ''),
      ),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'liveCapacityPriceUnavailable'),
      ),
    );
  });
}
