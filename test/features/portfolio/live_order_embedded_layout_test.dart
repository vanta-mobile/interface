import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';
import 'package:vanta/features/portfolio/domain/live_order_capacity.dart';
import 'package:vanta/features/portfolio/domain/live_order_opening_cost.dart';
import 'package:vanta/features/portfolio/domain/live_order_rules.dart';
import 'package:vanta/features/portfolio/domain/live_order_size.dart';
import 'package:vanta/features/portfolio/domain/main_order_capacity_preview.dart';
import 'package:vanta/features/portfolio/presentation/live_order_embedded_controls.dart';
import 'package:vanta/features/portfolio/presentation/live_order_embedded_inputs.dart';
import 'package:vanta/features/trade/presentation/widgets/trade_option_sheet.dart';
import 'package:vanta/features/portfolio/presentation/main_order_direction_card.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/main_order_capacity.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 220, child: child)),
);

void main() {
  testWidgets('price steps stay on the tick and off-tick prices snap down first', (tester) async {
    final price = TextEditingController(text: '100.0');
    addTearDown(price.dispose);
    var edits = 0;
    await tester.pumpWidget(
      _app(
        EmbeddedPriceField(
          controller: price,
          asset: 'USDT',
          tick: Decimal.parse('0.1'),
          enabled: true,
          onChanged: () => edits++,
          onBbo: () {},
        ),
      ),
    );
    await tester.tap(find.byTooltip('Increase price'));
    expect(price.text, '100.1');
    await tester.tap(find.byTooltip('Decrease price'));
    expect(price.text, '100');
    price.text = '100.07';
    await tester.tap(find.byTooltip('Decrease price'));
    expect(price.text, '100');
    price.text = '100.07';
    await tester.tap(find.byTooltip('Increase price'));
    expect(price.text, '100.1');
    expect(edits, 4);
  });

  testWidgets('BBO replaces the price with a level picker and its sheet note', (tester) async {
    final price = TextEditingController(text: '100');
    addTearDown(price.dispose);
    var picks = 0;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => EmbeddedPriceField(
            controller: price,
            asset: 'USDT',
            tick: Decimal.parse('0.1'),
            enabled: true,
            onChanged: () {},
            bboSelected: true,
            onBbo: () {},
            bboLevel: 'Queue 1',
            onBboLevel: () {
              picks++;
              showTradeOptionSheet(
                context,
                title: 'BBO Mode',
                selected: 'Queue 1',
                footer: 'note',
                options: const [(value: 'Queue 1', label: 'Queue 1', description: null)],
              );
            },
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('live-order-price')), findsNothing);
    expect(find.byTooltip('Increase price'), findsNothing);
    expect(find.text('BBO mode'), findsOneWidget);
    await tester.tap(find.byKey(const Key('live-order-bbo-level')));
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(find.text('BBO Mode'), findsOneWidget);
    expect(find.text('note'), findsOneWidget);
  });

  testWidgets('direction card rounds margin up and maximum down without throwing', (tester) async {
    final data = capacityContext();
    final rule = OrderQuantityRule(
      minimum: Decimal.parse('0.001'),
      maximum: Decimal.fromInt(100),
      step: Decimal.parse('0.001'),
    );
    var reviewed = false;
    await tester.pumpWidget(
      _app(
        MainOrderDirectionCard(
          data: data,
          unit: OrderSizeUnit.quote,
          buy: true,
          hasSize: true,
          onReview: () => reviewed = true,
          value: MainOrderSidePreview(
            capacity: LiveOrderSideCapacity(
              buy: true,
              maximum: Decimal.parse('0.0016789'),
              conversionPrice: Decimal.fromInt(100),
              rule: rule,
            ),
            cost: LiveOrderOpeningCost(
              initialMargin: Rational.fromInt(1, 3),
              openingLoss: Decimal.parse('0.0001'),
              openingQuantity: Decimal.parse('0.001'),
              reservedNotionalAfter: Decimal.zero,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), null);
    expect(
      tester.widget<Text>(find.byKey(const Key('main-order-cost-buy'))).textSpan!.toPlainText(),
      '0.34 USDT',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('main-order-maximum-buy'))).textSpan!.toPlainText(),
      '0.16 USDT',
    );
    await tester.tap(find.byKey(const Key('main-order-review-buy')));
    expect(reviewed, true);
  });

  testWidgets('option sheet resolves the chosen value and dismisses to null', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showTradeOptionSheet(
              context,
              title: 'Select Unit Type',
              selected: 'USDT',
              options: const [
                (value: 'USDT', label: 'USDT', description: null),
                (value: 'BTC', label: 'BTC', description: 'Base asset'),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Select Unit Type'), findsOneWidget);
    expect(find.text('Base asset'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trade-option-BTC')));
    await tester.pumpAndSettle();
    expect(result, 'BTC');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(result, null);
  });

  testWidgets('check row toggles and stays inert when disabled', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              EmbeddedCheckRow(
                key: const Key('enabled-row'),
                label: 'Reduce only',
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
              const EmbeddedCheckRow(label: 'Hidden Order', value: false, onChanged: null),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Reduce only'));
    await tester.pump();
    expect(value, true);
    await tester.tap(find.text('Hidden Order'));
    await tester.pump();
    expect(tester.takeException(), null);
  });
}
