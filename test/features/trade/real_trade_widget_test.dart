import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/live_order_form.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/positions_panel.dart';

import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';
import '../../support/workspace_navigation.dart';

void main() {
  for (final locale in ['en', 'zh']) {
    for (final spec in [(390.0, 844.0, 1.0), (320.0, 700.0, 1.5), (844.0, 390.0, 1.5)]) {
      testWidgets('real Trade form preserves draft and book price $locale $spec', (t) async {
        final f = NavigationFixture(t, language: locale, width: spec.$1, scale: spec.$3);
        t.view.physicalSize = Size(spec.$1, spec.$2);
        await launch(t, f.container);
        await selectWorkspace(t, chart: false);
        expect(find.byType(PositionsPanel), findsNothing);
        expect(find.byKey(const Key('enter-demo')), findsNothing);
        f.expectNoAccountMutation();
        // Use the real context controller with a synthetic signed repository.
        await f.container.read(liveOrderProvider.notifier).load('BTCUSDT');
        await t.pumpAndSettle();
        expect(find.byType(LiveOrderForm), findsOneWidget);
        final input = find.byKey(const Key('live-order-quantity'));
        await t.ensureVisible(input);
        await t.enterText(input, '75.123456');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await t.pumpAndSettle();
        await selectWorkspace(t, chart: true);
        await selectWorkspace(t, chart: false);
        expect(t.widget<TextField>(input).controller!.text, '75.123456');
        f.container.read(orderPriceProvider.notifier).setPrice('79999.1');
        await t.pumpAndSettle();
        expect(
          t.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
          '79999.1',
        );
        f.orders.readFailure = const AccountReadFailure(
          'accountNetwork',
          details: ApiErrorDetails(message: 'Synthetic read failed'),
        );
        await f.container.read(liveOrderProvider.notifier).load('BTCUSDT');
        await t.pumpAndSettle();
        expect(t.widget<TextField>(input).controller!.text, '75.123456');
        expect(find.text('Synthetic read failed'), findsOneWidget);
        f.expectNoAccountMutation(contextReads: 2);
        f.container.read(symbolProvider.notifier).select('ETHUSDT');
        await t.pumpAndSettle();
        expect(find.byType(LiveOrderForm), findsNothing);
        expect(find.byKey(const Key('trade-pending-quantity')), findsOneWidget);
        expect(f.container.read(orderPriceProvider), '');
        expect(t.takeException(), null);
        await f.close(t);
      });
    }
  }
}
