import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/live_order_trailing.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/presentation/live_order_trailing_controls.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_terms.dart';
import 'package:vanta/features/trade/presentation/trade_theme.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(width: 202, child: child)),
  ),
);

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('trailing form shows design fields and fills callback presets', (tester) async {
    final rate = TextEditingController(text: '1'), activation = TextEditingController();
    addTearDown(rate.dispose);
    addTearDown(activation.dispose);
    var inputs = 0;
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => LiveOrderTrailingControls(
          enabled: true,
          rate: rate,
          activation: activation,
          basis: LiveOrderTriggerBasis.mark,
          onBasis: (_) {},
          onInput: () => setState(() => inputs++),
        ),
      ),
    );
    expect(find.text('Callback rate'), findsOneWidget);
    expect(find.text('Activation price'), findsOneWidget);
    expect(find.text('Mark'), findsOneWidget);
    expect(find.byKey(const Key('live-trailing-basis')), findsOneWidget);
    bool selected(String preset) =>
        tester.widget<Text>(find.text('$preset%')).style?.color == TradeColors.text;
    expect(selected('1'), isTrue);
    expect(selected('2'), isFalse);

    await tester.tap(find.byKey(const Key('live-trailing-rate-2')));
    await tester.pump();
    expect(rate.text, '2');
    expect(inputs, 1);
    expect(selected('2'), isTrue);
    expect(selected('1'), isFalse);
  });

  testWidgets('disabled trailing form ignores presets', (tester) async {
    final rate = TextEditingController(text: '1'), activation = TextEditingController();
    addTearDown(rate.dispose);
    addTearDown(activation.dispose);
    await _pump(
      tester,
      LiveOrderTrailingControls(
        enabled: false,
        rate: rate,
        activation: activation,
        basis: LiveOrderTriggerBasis.mark,
        onBasis: (_) {},
        onInput: () {},
      ),
    );
    await tester.tap(find.byKey(const Key('live-trailing-rate-2')));
    await tester.pump();
    expect(rate.text, '1');
  });

  for (final activation in [null, '3.55']) {
    testWidgets('trailing confirmation follows design order, activation $activation', (
      tester,
    ) async {
      final intent = liveIntent(
        market: true,
        trailing: LiveOrderTrailing(
          callbackRate: '2.0',
          activationPrice: activation,
          basis: LiveOrderTriggerBasis.mark,
        ),
      );
      await _pump(tester, OrderConfirmationTerms(intent: intent, direction: 'Long'));
      expect(find.text('Order type'), findsNothing);
      expect(find.text('Tracking price basis'), findsNothing);
      expect(find.text('2.0%'), findsOneWidget);
      expect(find.text('Market Price'), findsOneWidget);
      final rate = _top(tester, 'Callback rate'), price = _top(tester, 'Order price');
      expect(rate, lessThan(price));
      expect(price, lessThan(_top(tester, 'Order Qty')));
      if (activation == null) {
        expect(find.text('Activation price'), findsNothing);
      } else {
        expect(find.text('Mark 3.55 USDT'), findsOneWidget);
        final activationTop = _top(tester, 'Activation price');
        expect(activationTop, greaterThan(rate));
        expect(activationTop, lessThan(price));
      }
    });
  }
}
