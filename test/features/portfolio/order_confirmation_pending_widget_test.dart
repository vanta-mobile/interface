import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/presentation/app_toast.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/main_order_refresh_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/main_order_live_pricing.dart';

void main() {
  for (final stage in [MainOrderRefreshStage.account, MainOrderRefreshStage.capacity]) {
    testWidgets('confirmation waits for $stage and shows a concrete failure only after click', (
      tester,
    ) async {
      final f = MainOrderLiveFixture();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final gate = Completer<void>();
      try {
        await tester.runAsync(f.open);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: f.container,
            child: MaterialApp(
              theme: vantaTheme(),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: LiveOrderScreen(symbol: 'BTCUSDT', embedded: true),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('live-order-price')), '100');
        await tester.enterText(find.byKey(const Key('live-order-quantity')), '10');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final review = find.byKey(const Key('main-order-review-buy'));
        await tester.ensureVisible(review);
        await tester.tap(review);
        await tester.runAsync(f.flush);
        await tester.pumpAndSettle();
        if (stage == MainOrderRefreshStage.account) f.orders.readGate = gate;
        if (stage == MainOrderRefreshStage.capacity) f.capacities.gate = gate;
        final polling = f.container
            .read(mainOrderRefreshProvider.notifier)
            .refresh('BTCUSDT', background: true, reconnectPrices: false);
        await tester.runAsync(f.flush);
        await tester.pump();
        final dialog = find.byType(OrderConfirmationDialog);
        final l = AppLocalizations.of(tester.element(dialog));
        expect(find.descendant(of: dialog, matching: find.textContaining('刷新')), findsNothing);
        expect(
          find.descendant(of: dialog, matching: find.byType(CircularProgressIndicator)),
          findsNothing,
        );
        final confirm = find.byKey(const Key('live-order-confirm'));
        await tester.tap(confirm);
        await tester.pump();
        expect(
          find.descendant(of: confirm, matching: find.byType(CircularProgressIndicator)),
          findsOneWidget,
        );
        await tester.tap(confirm);
        await tester.pump();
        const failure = AccountReadFailure(
          'accountDataInvalid',
          reasonKey: 'orderResponseMalformed',
          details: ApiErrorDetails(
            cause: ApiErrorCause.invalidResponse,
            endpoint: '/fapi/v3/accountWithJoinMargin',
          ),
        );
        if (stage == MainOrderRefreshStage.account) f.orders.readFailure = failure;
        if (stage == MainOrderRefreshStage.capacity) f.capacities.failure = failure;
        gate.complete();
        expect(await polling, isFalse);
        await tester.pumpAndSettle();
        expect(f.orders.submits, 0);
        expect(dialog, findsOneWidget);
        final toast = find.byKey(const Key('app-toast'));
        expect(
          find.descendant(
            of: toast,
            matching: find.textContaining('/fapi/v3/accountWithJoinMargin'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: toast, matching: find.textContaining(l.accountDataInvalid)),
          findsNothing,
        );
        expect(
          find.descendant(of: confirm, matching: find.byType(CircularProgressIndicator)),
          findsNothing,
        );
        await tester.pump(const Duration(seconds: 5));
        expect(toast, findsOneWidget);
        expect(f.orders.submits, 0);
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        AppToast.dismiss();
        f.container.read(mainOrderRefreshProvider.notifier).stop();
        await tester.pumpWidget(const SizedBox());
        await f.close();
      }
    });
  }
}
