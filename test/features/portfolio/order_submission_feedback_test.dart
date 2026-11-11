import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/presentation/app_toast.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/features/portfolio/application/symbol_settings_activity.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/portfolio/presentation/live_order_mode_selector.dart';
import 'package:vanta/features/portfolio/application/main_order_allocation_provider.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';
import '../../support/main_order_live_pricing.dart';

Widget _app(Widget child, {String language = 'en'}) => MaterialApp(
  theme: vantaTheme(),
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  tearDown(AppToast.dismiss);

  for (final language in ['en', 'zh']) {
    for (final kind in [OrderSubmissionKind.failed, OrderSubmissionKind.unknown]) {
      testWidgets('$kind retains concrete error and dialog until manual dismissal in $language', (
        tester,
      ) async {
        var submissions = 0;
        const reason = 'Margin is insufficient.';
        const failure = AccountReadFailure(
          'accountReadFailed',
          code: -2019,
          details: ApiErrorDetails(message: reason, status: 400),
        );
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => OrderConfirmationDialog(
                    intent: liveIntent(),
                    submit: () async {
                      submissions++;
                      return OrderSubmissionOutcome(kind, failure);
                    },
                  ),
                ),
                child: const Text('Review'),
              ),
            ),
            language: language,
          ),
        );
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('live-order-confirm')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(minutes: 5));
        expect(submissions, 1);
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(find.textContaining(reason), findsOneWidget);
        expect(find.textContaining('-2019'), findsOneWidget);
        final l = AppLocalizations.of(tester.element(find.byType(OrderConfirmationDialog)));
        expect(find.textContaining(l.liveOrderOutcomeUnknown), findsNothing);
        await tester.tap(find.byKey(const Key('app-toast-close')));
        await tester.pump();
        expect(find.textContaining(reason), findsNothing);
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(submissions, 1);
        await tester.tap(find.byKey(const Key('live-order-close')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('explicit parameter rejection keeps the reason and draft without unknown feedback', (
    tester,
  ) async {
    final f = MainOrderLiveFixture();
    const reason =
        "Mandatory parameter 'firstDrivenId' was not sent, was empty/null, or malformed.";
    f.orders.result = const LiveOrderResult(
      rejected: true,
      failure: AccountReadFailure(
        'accountReadFailed',
        code: -1102,
        details: ApiErrorDetails(message: reason, status: 400),
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    try {
      await tester.runAsync(f.open);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: _app(
            const SingleChildScrollView(child: LiveOrderScreen(symbol: 'BTCUSDT', embedded: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final quantity = find.byKey(const Key('live-order-quantity'));
      await tester.enterText(find.byKey(const Key('live-order-price')), '100');
      await tester.enterText(quantity, '10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final review = find.byKey(const Key('main-order-review-buy'));
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.runAsync(f.flush);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      expect(f.orders.submits, 1);
      expect(find.byType(OrderConfirmationDialog), findsOneWidget);
      final toast = find.byKey(const Key('app-toast'));
      expect(find.descendant(of: toast, matching: find.textContaining(reason)), findsOneWidget);
      expect(find.descendant(of: toast, matching: find.textContaining('-1102')), findsOneWidget);
      final l = AppLocalizations.of(tester.element(find.byType(OrderConfirmationDialog)));
      expect(find.textContaining(l.liveOrderOutcomeUnknown), findsNothing);
      expect(tester.widget<TextField>(quantity).controller!.text, '10');
      expect(f.container.read(symbolSettingsActivityProvider).busy, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox());
      await f.close();
    }
  });

  testWidgets('trading form hides recovery notice and pending record does not lock the form', (
    tester,
  ) async {
    final f = MainOrderLiveFixture();
    try {
      await tester.runAsync(f.open);
      final journal = f.container.read(orderRecoveryJournalProvider);
      final record = OrderRecoveryRecord(
        query: OrderQuery.capture(liveIntent()),
        createdAt: liveOrderClock,
      );
      await tester.runAsync(() => journal.prepare(record));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: f.container,
          child: _app(
            const SingleChildScrollView(child: LiveOrderScreen(symbol: 'BTCUSDT', embedded: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
      expect(find.text(l.orderRecoveryTitle), findsNothing);
      expect(find.text(l.orderRecoveryPending), findsNothing);
      expect(journal.snapshot.records.single.key, record.key);
      expect(f.container.read(pendingWalletOrdersProvider).single.key, record.key);
      expect(f.container.read(symbolSettingsActivityProvider).recoveryBlocked, isFalse);
      expect(
        tester.widget<LiveOrderModeSelector>(find.byType(LiveOrderModeSelector)).enabled,
        isTrue,
      );
      expect(f.container.read(mainOrderAllocationProvider.notifier).editable, isTrue);
      expect(f.orders.submits, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await f.close();
    }
  });
}
