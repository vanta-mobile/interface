import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/strategy_execution_mapper.dart';
import 'package:vanta/features/portfolio/domain/attached_entry_peg.dart';
import 'package:vanta/features/portfolio/domain/strategy_execution.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';

import '../../support/attached_order.dart';
import '../../support/live_order.dart';
import '../../support/strategy_execution.dart';

void main() {
  late StrategyExecutionFixture fixture;
  setUp(() => fixture = StrategyExecutionFixture());
  StrategyLegExecution map(Map<String, dynamic> row, {int sequence = 1}) => mapStrategyLegExecution(
    row,
    query: fixture.query,
    sequence: sequence,
    orderId: '${99 + sequence}',
    checkedAt: liveOrderClock,
  );
  test('cancellation retains partial execution and exact reported quote amount', () {
    final result = map(fixture.order(1));
    expect(result.status, 'CANCELED');
    expect(result.executed, Decimal.parse('0.0004'));
    expect(result.quoteAmount, Decimal.parse('32.000000000000000001'));
    expect(result.averagePrice, Decimal.parse('80000'));
    expect(result.termsChanged, false);
  });
  test('server resized quantity is reported separately from original strategy quantity', () {
    final row = fixture.order(2)..['origQty'] = '0.0004';
    final result = map(row, sequence: 2);
    expect(result.quantity, Decimal.parse('0.0004'));
    expect(result.termsChanged, true);
    expect(result.executed, Decimal.zero);
    expect(fixture.query.order.protectedQuantity, '0.001');
  });
  test(
    'missing optional quote/average remains unknown; quantity times price is not substituted',
    () {
      final row = fixture.order(1)
        ..remove('cumQuote')
        ..remove('avgPrice');
      final result = map(row);
      expect(result.quoteAmount, null);
      expect(result.averagePrice, null);
      expect(result.executed, Decimal.parse('0.0004'));
    },
  );
  for (final pair in [('STOP_MARKET', 'MARKET'), ('TAKE_PROFIT_MARKET', 'MARKET')]) {
    test('transformed ${pair.$1} shows triggering independent of zero fills', () {
      final seq = pair.$1 == 'STOP_MARKET' ? 3 : 2;
      final row = fixture.order(seq)..['type'] = pair.$2;
      final result = map(row, sequence: seq);
      expect(result.triggered, true);
      expect(result.executed, Decimal.zero);
    });
  }
  test('untransformed filled conditional still proves triggering through actual execution', () {
    final row = fixture.order(2)
      ..['status'] = 'FILLED'
      ..['executedQty'] = '0.001'
      ..['cumQuote'] = '81'
      ..['avgPrice'] = '81000';
    expect(map(row, sequence: 2).triggered, true);
  });
  test('ordinary BBO engine price is not compared against the strategy zero sentinel', () {
    fixture = StrategyExecutionFixture(intent: attachedIntent(peg: AttachedEntryPeg.queue1));
    expect(map(fixture.order(1)).termsChanged, false);
    final row = fixture.order(1)..['pegPriceType'] = 'COUNTERPARTY_1';
    expect(() => map(row), throwsFormatException);
  });
  final badIdentity = <String, Object?>{
    'orderId': '101',
    'clientOrderId': 'other-1',
    'symbol': 'ETHUSDT',
    'side': 'SELL',
    'positionSide': 'LONG',
    'reduceOnly': true,
    'closePosition': true,
    'origType': 'MARKET',
    'type': 'MARKET',
    'timeInForce': 'IOC',
    'status': 'SENSITIVE RAW',
    'time': -1,
    'updateTime': 1.5,
  };
  for (final change in badIdentity.entries) {
    test('cannot associate a different or malformed order ${change.key}', () {
      final row = fixture.order(1)..[change.key] = change.value;
      expect(() => map(row), throwsFormatException);
    });
  }
  for (final change in <String, Object?>{
    'origQty': '0',
    'executedQty': '0.002',
    'cumQuote': '-1',
    'avgPrice': 'NaN',
    'price': 80000,
    'updateTime': 1,
    'status': 'NEW',
  }.entries) {
    test('inconsistent or inexact execution ${change.key} rejected', () {
      final row = fixture.order(1)..[change.key] = change.value;
      expect(() => map(row), throwsFormatException);
    });
  }
  for (final status in ['PARTIALLY_FILLED', 'FILLED']) {
    for (final filled in ['0', '0.001']) {
      test('execution quantity/status invariant $status $filled', () {
        final row = fixture.order(1)
          ..['status'] = status
          ..['executedQty'] = filled
          ..['cumQuote'] = filled == '0' ? '0' : '80'
          ..['avgPrice'] = filled == '0' ? '0' : '80000';
        if (status == 'FILLED' && filled == '0.001') {
          expect(map(row).executed, Decimal.parse('0.001'));
        } else {
          expect(() => map(row), throwsFormatException);
        }
      });
    }
  }
  for (final field in ['workingType', 'priceProtect']) {
    test('exit trigger basis must still match $field', () {
      final row = fixture.order(2)..[field] = field == 'workingType' ? 'CONTRACT_PRICE' : true;
      expect(() => map(row, sequence: 2), throwsFormatException);
    });
  }
  test('changed fixed price is explicit rather than misreported as original terms', () {
    final row = fixture.order(1)..['price'] = '80001';
    expect(map(row).termsChanged, true);
  });
  for (final execution in [
    AttachedExitExecution.manualLimit,
    AttachedExitExecution.automaticLimit,
  ]) {
    for (final kind in LiveOrderTriggerKind.values) {
      test('actual triggered limit exit is independent of unfilled strategy $execution $kind', () {
        final exit = AttachedExit(
          kind: kind,
          price: kind == LiveOrderTriggerKind.stop ? '79000' : '81000',
          execution: execution,
          limitPrice: execution == AttachedExitExecution.manualLimit ? '80000' : null,
        );
        fixture = StrategyExecutionFixture(
          intent: attachedIntent(
            protection: LiveOrderAttachment(
              takeProfit: kind == LiveOrderTriggerKind.takeProfit ? exit : null,
              stopLoss: kind == LiveOrderTriggerKind.stop ? exit : null,
            ),
          ),
        );
        final row = fixture.order(2)
          ..['type'] = 'LIMIT'
          ..['origQty'] = '0.0004';
        final result = map(row, sequence: 2);
        expect(result.triggered, true);
        expect(result.executed, Decimal.zero);
        expect(result.termsChanged, true);
        expect(result.originalType, kind == LiveOrderTriggerKind.stop ? 'STOP' : 'TAKE_PROFIT');
        expect(
          result.price,
          Decimal.parse(execution == AttachedExitExecution.manualLimit ? '80000' : exit.price),
        );
      });
    }
  }
  for (final field in ['origQty', 'executedQty', 'price']) {
    test('negative ordinary execution field $field is rejected', () {
      final row = fixture.order(1)..[field] = '-0.0001';
      expect(() => map(row), throwsFormatException);
    });
  }
}
