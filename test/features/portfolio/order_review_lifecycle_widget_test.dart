import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/application/order_review_activity_provider.dart';
import 'package:vanta/features/portfolio/presentation/live_order_review.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';
import '../../support/main_order_live_pricing.dart';

void main() {
  for (final stage in [MainOrderRefreshStage.account, MainOrderRefreshStage.capacity]) {
    testWidgets('review cancels in-flight $stage polling, ignores its late result and opens once', (
      tester,
    ) async {
      final f = MainOrderLiveFixture();
      try {
        await tester.runAsync(f.open);
        final controller = f.container.read(liveOrderProvider.notifier);
        final intent = controller.prepare(
          'BTCUSDT',
          liveDraft(quantity: '0.1', price: '100'),
          pricingContext: f.valuation.context,
        )!;
        final oldGate = Completer<void>();
        if (stage == MainOrderRefreshStage.account) f.orders.readGate = oldGate;
        if (stage == MainOrderRefreshStage.capacity) f.capacities.gate = oldGate;
        final polling = f.container
            .read(mainOrderRefreshProvider.notifier)
            .refresh('BTCUSDT', reconnectPrices: false, background: true);
        await tester.runAsync(f.flush);
        expect(f.container.read(mainOrderRefreshProvider).stage, stage);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: f.container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => FilledButton(
                    onPressed: () {
                      unawaited(reviewLiveOrder(context, ref, intent));
                      unawaited(reviewLiveOrder(context, ref, intent));
                    },
                    child: const Text('Review'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        expect(await polling, false);
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(f.container.read(orderReviewActivityProvider), 1);
        expect(f.container.read(mainOrderRefreshProvider).loading, false);
        final retained = f.container.read(liveOrderProvider);
        oldGate.complete();
        await tester.runAsync(f.flush);
        await tester.pumpAndSettle();
        expect(f.container.read(liveOrderProvider), same(retained));
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(f.orders.submits, 0);
        await tester.tap(find.byKey(const Key('live-order-cancel')));
        await tester.pumpAndSettle();
        expect(f.container.read(orderReviewActivityProvider), 0);
        expect(tester.takeException(), isNull);
      } finally {
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        f.disposeContainer();
        await f.close();
      }
    });
  }
}
