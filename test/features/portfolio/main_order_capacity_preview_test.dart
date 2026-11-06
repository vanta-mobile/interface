import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity_preview.dart';

import '../../support/live_order.dart';
import '../../support/main_order_capacity.dart';

void main() {
  for (final unit in OrderSizeUnit.values) {
    test('percentage uses independent maxima without round-tripping quote input $unit', () {
      final value = MainOrderCapacityPreview(
        snapshot: assembledCapacity(),
        draft: liveDraft(price: '101'),
        unit: unit,
        input: 'ignored',
        percent: 20,
      );
      expect(value.buy.quantity, Decimal.parse('1.801'));
      expect(value.sell.quantity, Decimal.parse('1.98'));
      expect(value.buy.displayInput(unit), unit == OrderSizeUnit.base ? '1.801' : '181.901');
      expect(value.sell.displayInput(unit), unit == OrderSizeUnit.base ? '1.98' : '199.98');
      expect(value.buy.size!.quantity, '1.801');
      expect(value.buy.failure, null);
    });
    test(
      'zero percent overrides dormant manual input and leaves all financial previews blank $unit',
      () {
        final value = MainOrderCapacityPreview(
          snapshot: assembledCapacity(),
          draft: liveDraft(price: '100'),
          unit: unit,
          input: '2',
          percent: 0,
        );
        expect(value.buy.quantity, null);
        expect(value.buy.notional, null);
        expect(value.buy.cost, null);
        expect(value.buy.displayInput(unit), '');
        expect(value.buy.capacity!.maximum, Decimal.fromInt(10));
      },
    );
  }
  test('market 100 percent converts each quantity with its own book reference', () {
    final value = MainOrderCapacityPreview(
      snapshot: assembledCapacity(),
      draft: liveDraft(market: true, price: ''),
      unit: OrderSizeUnit.quote,
      input: '',
      percent: 100,
    );
    expect(value.buy.quantity, Decimal.parse('8.964'));
    expect(value.sell.quantity, Decimal.parse('9.174'));
    expect(value.buy.displayInput(OrderSizeUnit.quote), '905.364');
    expect(value.sell.displayInput(OrderSizeUnit.quote), '908.226');
    expect(value.buy.capacity!.maximumQuote, Decimal.parse('905.364'));
  });
  test('tiny percentage remains known zero quantity without a fictional cost', () {
    final payload = capacityAccountPayload();
    (payload['assets'] as List).single['availableBalance'] = '0.03';
    final value = MainOrderCapacityPreview(
      snapshot: assembledCapacity(payload: payload),
      draft: liveDraft(price: '100'),
      unit: OrderSizeUnit.base,
      input: '',
      percent: 1,
    );
    // max 0.003 is below min notional, so it is known zero capacity.
    expect(value.buy.quantity, Decimal.zero);
    expect(value.buy.cost, null);
    expect(value.buy.size!.quantity, '0');
    expect(value.buy.failure!.key, 'liveOrderInvalidQuantity');
  });
  MainOrderCapacityPreview preview({
    String input = '',
    bool quote = false,
    LiveOrderDraft? draft,
  }) => MainOrderCapacityPreview(
    snapshot: assembledCapacity(),
    draft: draft ?? liveDraft(price: '100'),
    unit: quote ? OrderSizeUnit.quote : OrderSizeUnit.base,
    input: input,
  );
  test('blank input has independent known maxima without a synthetic order cost', () {
    final value = preview();
    for (final side in [value.buy, value.sell]) {
      expect(side.capacity!.maximum, Decimal.fromInt(10));
      expect(side.quantity, null);
      expect(side.notional, null);
      expect(side.cost, null);
      expect(side.failure, null);
    }
  });
  test('limit side changes retain entered loss and independent maxima', () {
    final value = preview(
      input: '2',
      draft: liveDraft(price: '101'),
    );
    expect(value.buy.capacity!.maximum, Decimal.parse('9.009'));
    expect(value.sell.capacity!.maximum, Decimal.parse('9.9'));
    expect(value.buy.cost!.total, Decimal.parse('22.2').toRational());
    expect(value.sell.cost!.total, Decimal.parse('20.2').toRational());
    expect(value.buy.failure, null);
    expect(value.sell.failure, null);
  });
  test('market quote input resolves both sides independently from ask and bid', () {
    final value = preview(
      input: '101',
      quote: true,
      draft: liveDraft(market: true, price: ''),
    );
    expect(value.buy.quantity, Decimal.one);
    expect(value.sell.quantity, Decimal.parse('1.02'));
    expect(value.buy.capacity!.maximum, Decimal.parse('8.964'));
    expect(value.sell.capacity!.maximum, Decimal.parse('9.174'));
    expect(value.buy.cost!.total, Decimal.parse('11.155').toRational());
    expect(value.sell.cost!.total, Decimal.parse('11.118').toRational());
    expect(value.buy.notional, Decimal.fromInt(100));
    expect(value.sell.notional, Decimal.fromInt(102));
  });
  test('base manual input keeps identical quantities and direction-specific opening cost', () {
    final payload = capacityAccountPayload();
    (payload['positions'] as List)[0] = capacityPosition(quantity: '5');
    final context = capacityContext(payload: payload);
    final value = MainOrderCapacityPreview(
      snapshot: assembledCapacity(context: context, payload: payload),
      draft: liveDraft(price: '100'),
      unit: OrderSizeUnit.base,
      input: '2',
    );
    expect(value.buy.quantity, value.sell.quantity);
    expect(value.buy.cost!.total, Decimal.fromInt(20).toRational());
    expect(value.sell.cost!.total, Decimal.zero.toRational());
    expect(value.buy.capacity!.maximum, Decimal.fromInt(10));
    expect(value.sell.capacity!.maximum, Decimal.fromInt(20));
  });
  test('known zero contract capacity displays zero and blank cost stays unknown', () {
    final value = MainOrderCapacityPreview(
      snapshot: assembledCapacity(
        contractCap: SymbolOpenableNotional(
          symbol: 'BTCUSDT',
          leverage: 10,
          receivedAt: liveOrderClock,
          remaining: Decimal.zero,
        ),
      ),
      draft: liveDraft(price: '100'),
      unit: OrderSizeUnit.base,
      input: '',
    );
    expect(value.buy.capacity!.maximum, Decimal.zero);
    expect(value.sell.capacity!.maximum, Decimal.zero);
    expect(value.buy.cost, null);
    expect(value.buy.failure, null);
  });
  test('over-capacity quantity preserves numeric preview and reports safe warning', () {
    final value = preview(input: '11');
    expect(value.buy.quantity, Decimal.fromInt(11));
    expect(value.buy.cost!.total, Decimal.fromInt(110).toRational());
    expect(value.buy.failure!.key, 'liveCapacityAboveMaximum');
    expect(value.sell.failure!.key, 'liveCapacityAboveMaximum');
  });
  for (final input in ['0', '-1', '1e2', 'NaN']) {
    test('invalid base quantity retains maxima but has no fictional cost $input', () {
      final value = preview(input: input);
      expect(value.buy.capacity, isNotNull);
      expect(value.buy.quantity, null);
      expect(value.buy.cost, null);
      expect(value.buy.failure!.key, 'liveOrderInvalidQuantity');
    });
  }
  test('quote input below step retains zero-order distinction', () {
    final value = preview(input: '0.000001', quote: true);
    expect(value.buy.capacity, isNotNull);
    expect(value.buy.quantity, null);
    expect(value.buy.failure!.key, 'liveAmountBelowStep');
  });
  test('invalid price leaves capacity unknown rather than zero', () {
    final value = preview(
      input: '2',
      draft: liveDraft(price: ''),
    );
    expect(value.buy.capacity, null);
    expect(value.buy.cost, null);
    expect(value.buy.failure!.key, 'liveOrderInvalidPrice');
  });
  test('ordinary queue peg has independent book-based directional maxima', () {
    final value = preview(
      draft: liveDraft(price: '', peg: LiveOrderPeg.queue),
    );
    expect(value.buy.capacity!.maximum, Decimal.parse('10.101'));
    expect(value.sell.capacity!.maximum, Decimal.parse('9.9'));
    expect(value.buy.failure, null);
    expect(value.sell.failure, null);
  });
  test('reducing flows do not consume the opening capacity model', () {
    final value = preview(draft: liveDraft(reduceOnly: true));
    expect(value.buy.capacity, null);
    expect(value.buy.failure!.key, 'liveClosePositionChanged');
  });
  test('opposite entry cost does not validate exits resolved for the selected side', () {
    final value = preview(
      input: '2',
      draft: liveDraft(
        price: '100',
        attachment: const LiveOrderAttachment(
          takeProfit: AttachedExit(kind: LiveOrderTriggerKind.takeProfit, price: '110'),
        ),
      ),
    );
    expect(value.buy.cost!.total, Decimal.fromInt(20).toRational());
    expect(value.sell.cost!.total, Decimal.fromInt(20).toRational());
    expect(value.sell.failure, null);
  });
}
