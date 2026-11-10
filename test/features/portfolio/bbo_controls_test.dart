import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/live_order_draft.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/presentation/live_order_pricing.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

void main() {
  for (final postOnly in [false, true]) {
    testWidgets('BBO switch defaults and choices postOnly=$postOnly', (tester) async {
      LiveOrderPeg? selection;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return LiveOrderPricing(
                  selected: selection,
                  enabled: true,
                  postOnly: postOnly,
                  onChanged: (value) => setState(() => selection = value),
                );
              },
            ),
          ),
        ),
      );
      final toggle = find.byKey(const Key('live-order-bbo'));
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      expect(find.byKey(const Key('live-order-pricing')), findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(selection, postOnly ? LiveOrderPeg.queue : LiveOrderPeg.counterparty);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('live-order-pricing')),
      );
      expect(
        dropdown.items!.map((item) => item.value),
        postOnly ? ['QUEUE_1'] : ['COUNTERPARTY_1', 'QUEUE_1'],
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(selection, null);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(selection, postOnly ? LiveOrderPeg.queue : LiveOrderPeg.counterparty);
    });
  }

  test('Post Only rejects opposing BBO for either direction', () {
    for (final buy in [false, true]) {
      for (final peg in LiveOrderPeg.values) {
        final draft = LiveOrderDraft(
          buy: buy,
          market: false,
          quantity: '1',
          price: '',
          timeInForce: LiveOrderTimeInForce.postOnly,
          peg: peg,
        );
        expect(draft.validPegShape, peg == LiveOrderPeg.queue);
      }
    }
  });
}
