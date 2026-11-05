import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/attached_exit_input.dart';
import 'package:vanta/features/portfolio/domain/attached_order.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/live_order.dart';

LiveOrderContext exampleContext({int leverage = 5, String? bid = '100', String? ask = '100'}) {
  final base = liveContext();
  return LiveOrderContext(
    address: base.address,
    rules: base.rules,
    mode: base.mode,
    marginMode: base.marginMode,
    leverage: leverage,
    markPrice: Decimal.parse('100'),
    receivedAt: base.receivedAt,
    positions: base.positions,
    funds: base.funds,
    lastPrice: Decimal.parse('101'),
    bid: bid == null ? null : Decimal.parse(bid),
    ask: ask == null ? null : Decimal.parse(ask),
  );
}

void main() {
  for (final buy in [true, false]) {
    for (final kind in LiveOrderTriggerKind.values) {
      for (final mode in AttachedExitInputMode.values) {
        test('PRD exact conversion and gross preview $buy $kind $mode', () {
          final tp = kind == LiveOrderTriggerKind.takeProfit;
          final expected = buy ? (tp ? '105' : '98') : (tp ? '95' : '102');
          final input = AttachedExitInput(
            kind: kind,
            mode: mode,
            value: switch (mode) {
              AttachedExitInputMode.pnl => tp ? '+10' : '-4',
              AttachedExitInputMode.roi => tp ? '+25' : '-10',
              AttachedExitInputMode.price => expected,
            },
          );
          final result = input.resolve(
            exampleContext(),
            liveDraft(buy: buy, quantity: '2', price: '100'),
          );
          expect(result.failure, null);
          expect(result.exit.price, expected);
          expect(result.exit.basis, LiveOrderTriggerBasis.mark);
          expect(result.exit.market, true);
          expect(result.pnl, Decimal.parse(tp ? '10' : '-4'));
          expect(result.roi, Decimal.parse(tp ? '25' : '-10'));
        });
      }
    }
  }
  test('manual limit changes PnL estimate while keeping the stop threshold', () {
    final result = const AttachedExitInput(
      kind: LiveOrderTriggerKind.stop,
      value: '-4',
      execution: AttachedExitExecution.manualLimit,
      limitPrice: '97.5',
    ).resolve(exampleContext(), liveDraft(quantity: '2', price: '100'));
    expect(result.failure, null);
    expect(result.exit.price, '98');
    expect(result.exit.executionPrice, '97.5');
    expect(result.pnl, Decimal.parse('-5'));
    expect(result.roi, Decimal.parse('-12.5'));
  });
  test('automatic limit equals trigger, with no hidden manual price', () {
    final result = const AttachedExitInput(
      kind: LiveOrderTriggerKind.takeProfit,
      value: '10',
      execution: AttachedExitExecution.automaticLimit,
      limitPrice: '1',
    ).resolve(exampleContext(), liveDraft(quantity: '2', price: '100'));
    expect(result.failure, null);
    expect(result.exit.price, '105');
    expect(result.exit.executionPrice, '105');
    expect(result.exit.limitPrice, null);
  });
  test('repeating division aligns once using rational arithmetic', () {
    final result = const AttachedExitInput(
      kind: LiveOrderTriggerKind.takeProfit,
      value: '1',
    ).resolve(exampleContext(), liveDraft(quantity: '3', price: '100'));
    expect(result.failure, null);
    expect(result.exit.price, '100.3');
    expect(result.pnl, Decimal.parse('0.9'));
    expect(result.roi, Decimal.parse('1.5'));
  });
  test('raw target recomputes when quantity, entry reference, direction or leverage changes', () {
    const pnl = AttachedExitInput(kind: LiveOrderTriggerKind.takeProfit, value: '10');
    final data = exampleContext();
    expect(pnl.resolve(data, liveDraft(quantity: '2', price: '100')).exit.price, '105');
    expect(pnl.resolve(data, liveDraft(quantity: '4', price: '100')).exit.price, '102.5');
    expect(pnl.resolve(data, liveDraft(quantity: '2', price: '110')).exit.price, '115');
    expect(pnl.resolve(data, liveDraft(buy: false, quantity: '2', price: '100')).exit.price, '95');
    const roi = AttachedExitInput(
      kind: LiveOrderTriggerKind.takeProfit,
      mode: AttachedExitInputMode.roi,
      value: '25',
    );
    expect(
      roi.resolve(exampleContext(leverage: 10), liveDraft(quantity: '2', price: '100')).exit.price,
      '102.5',
    );
  });
  test('entry reference uses buy ask / sell bid and conditional market trigger', () {
    final data = exampleContext(bid: '99', ask: '101');
    expect(attachedEntryReference(data, liveDraft(market: true)), Decimal.parse('101'));
    expect(attachedEntryReference(data, liveDraft(buy: false, market: true)), Decimal.parse('99'));
    expect(
      attachedEntryReference(
        data,
        liveDraft(
          market: true,
          trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '110'),
        ),
      ),
      Decimal.parse('110'),
    );
    expect(
      attachedEntryReference(
        data,
        liveDraft(
          price: '95',
          trigger: const LiveOrderTrigger(kind: LiveOrderTriggerKind.stop, price: '110'),
        ),
      ),
      Decimal.parse('95'),
    );
  });
  for (final mode in [AttachedExitInputMode.pnl, AttachedExitInputMode.roi]) {
    for (final value in ['', '0', '-0.00', 'NaN', '1e5', '--4', '1.2.3', '-10', '1' * 81]) {
      test('invalid positive target cannot become take profit $mode $value', () {
        final result = AttachedExitInput(
          kind: LiveOrderTriggerKind.takeProfit,
          mode: mode,
          value: value,
        ).resolve(exampleContext(), liveDraft(quantity: '2', price: '100'));
        expect(result.failure, 'attachedOrderTargetSign');
      });
    }
    test('positive stop loss target cannot be submitted $mode', () {
      final result = AttachedExitInput(
        kind: LiveOrderTriggerKind.stop,
        mode: mode,
        value: '+4',
      ).resolve(exampleContext(), liveDraft(quantity: '2', price: '100'));
      expect(result.failure, 'attachedOrderTargetSign');
    });
  }
  test('unknown quote, quantity and leverage keep derived price unavailable', () {
    const input = AttachedExitInput(kind: LiveOrderTriggerKind.takeProfit, value: '10');
    for (final data in [exampleContext(ask: null), exampleContext(leverage: 0)]) {
      expect(
        input.resolve(data, liveDraft(market: true, quantity: '2')).failure,
        'attachedOrderPreviewUnavailable',
      );
    }
    expect(
      input.resolve(exampleContext(), liveDraft(quantity: '', price: '100')).failure,
      'attachedOrderPreviewUnavailable',
    );
  });
  for (final limit in ['', '0', '-1', 'NaN']) {
    test('manual limit must be explicit and positive $limit', () {
      expect(
        AttachedExitInput(
          kind: LiveOrderTriggerKind.stop,
          value: '-4',
          execution: AttachedExitExecution.manualLimit,
          limitPrice: limit,
        ).resolve(exampleContext(), liveDraft(quantity: '2', price: '100')).failure,
        'attachedOrderLimitRequired',
      );
    });
  }
  test('user prices are validated as entered; they are never rounded', () {
    const price = AttachedExitInput(
      kind: LiveOrderTriggerKind.takeProfit,
      mode: AttachedExitInputMode.price,
      value: '105.01',
    );
    expect(
      price.resolve(exampleContext(), liveDraft(quantity: '2', price: '100')).failure,
      'liveOrderTriggerFilter',
    );
    const limit = AttachedExitInput(
      kind: LiveOrderTriggerKind.stop,
      value: '-4',
      execution: AttachedExitExecution.manualLimit,
      limitPrice: '97.51',
    );
    expect(
      limit.resolve(exampleContext(), liveDraft(quantity: '2', price: '100')).failure,
      'liveOrderPriceFilter',
    );
  });
  test('closing advanced settings removes the manual limit from effective terms', () {
    const input = AttachedExitInput(
      kind: LiveOrderTriggerKind.stop,
      value: '-4',
      execution: AttachedExitExecution.manualLimit,
      limitPrice: '97.5',
    );
    final market = input
        .withExecution(AttachedExitExecution.market)
        .resolve(exampleContext(), liveDraft(quantity: '2', price: '100'));
    expect(market.exit.market, true);
    expect(market.exit.limitPrice, null);
    expect(input.limitPrice, '97.5');
  });
}
