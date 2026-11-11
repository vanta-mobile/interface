import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/presentation/app_toast.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/live_order_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/live_order.dart';

LiveOrderIntent _intent(LiveOrderDraft draft) => LiveOrderIntent(
  context: liveContext(),
  draft: draft,
  clientOrderId: 'vanta-test-123',
  revision: 0,
);

Future<void> _open(
  WidgetTester tester,
  LiveOrderIntent intent,
  Future<OrderSubmissionOutcome> Function() submit, {
  Size size = const Size(393, 852),
  double scale = 1,
  String language = 'en',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(AppToast.dismiss);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => OrderConfirmationDialog(intent: intent, submit: submit),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(OrderConfirmationDialog)));

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(OrderConfirmationDialog), matching: finder);

void main() {
  testWidgets('market long shows design rows; pending spins and success toasts and closes', (
    tester,
  ) async {
    final gate = Completer<OrderSubmissionOutcome>();
    var calls = 0;
    await _open(tester, _intent(liveDraft(market: true, price: '')), () {
      calls++;
      return gate.future;
    });
    final l10n = _l10n(tester);
    expect(_inDialog(find.text(l10n.orderConfirmTitle)), findsOneWidget);
    expect(_inDialog(find.text('BTCUSDT')), findsOneWidget);
    expect(_inDialog(find.text(l10n.orderConfirmMarketPrice)), findsOneWidget);
    expect(_inDialog(find.text('0.001 BTC')), findsOneWidget);
    // The direction tag and the confirm button share the label.
    expect(_inDialog(find.text(l10n.orderConfirmBuy)), findsNWidgets(2));
    expect(_inDialog(find.text(l10n.orderConfirmTakeProfit)), findsNothing);

    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pump();
    expect(calls, 1);
    expect(_inDialog(find.byType(CircularProgressIndicator)), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('live-order-confirm')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(confirm.onPressed, isNull);
    await tester.tap(find.byKey(const Key('live-order-confirm')), warnIfMissed: false);
    await tester.tap(find.byKey(const Key('live-order-cancel')), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(OrderConfirmationDialog), findsOneWidget);

    gate.complete(const OrderSubmissionOutcome(OrderSubmissionKind.success));
    await tester.pumpAndSettle();
    expect(find.byType(OrderConfirmationDialog), findsNothing);
    expect(find.text(l10n.orderConfirmSubmitted), findsOneWidget);
    AppToast.dismiss();
  });

  testWidgets('failure toasts the API message and keeps the dialog for another decision', (
    tester,
  ) async {
    await _open(
      tester,
      _intent(liveDraft(buy: false)),
      () async => const OrderSubmissionOutcome(
        OrderSubmissionKind.failed,
        AccountReadFailure('accountNetwork'),
      ),
    );
    final l10n = _l10n(tester);
    expect(_inDialog(find.text(l10n.orderConfirmSell)), findsNWidgets(2));
    expect(_inDialog(find.text('80000 USDT')), findsOneWidget);
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(OrderConfirmationDialog), findsOneWidget);
    expect(find.byKey(const Key('app-toast')), findsOneWidget);
    expect(_inDialog(find.byType(CircularProgressIndicator)), findsNothing);
    AppToast.dismiss();
    await tester.pump();
    await tester.tap(find.byKey(const Key('live-order-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(OrderConfirmationDialog), findsNothing);
  });

  testWidgets('unknown and unsent outcomes toast their cause without closing', (tester) async {
    var outcome = const OrderSubmissionOutcome(OrderSubmissionKind.unknown);
    await _open(tester, _intent(liveDraft()), () async => outcome);
    final l10n = _l10n(tester);
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining(l10n.liveOrderOutcomeUnknown), findsOneWidget);
    expect(find.byType(OrderConfirmationDialog), findsOneWidget);
    outcome = const OrderSubmissionOutcome(OrderSubmissionKind.notSubmitted);
    AppToast.dismiss();
    await tester.pump();
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.orderConfirmExpired), findsOneWidget);
    expect(find.byType(OrderConfirmationDialog), findsOneWidget);
    AppToast.dismiss();
  });

  testWidgets('TP/SL rows follow direction and basis', (tester) async {
    await _open(
      tester,
      _intent(
        liveDraft(
          market: true,
          price: '',
          attachment: const LiveOrderAttachment(
            takeProfit: AttachedExit(
              kind: LiveOrderTriggerKind.takeProfit,
              price: '81000',
              basis: LiveOrderTriggerBasis.last,
            ),
            stopLoss: AttachedExit(kind: LiveOrderTriggerKind.stop, price: '79000'),
          ),
        ),
      ),
      () async => const OrderSubmissionOutcome(OrderSubmissionKind.success),
    );
    final l10n = _l10n(tester);
    expect(_inDialog(find.text(l10n.orderConfirmTakeProfit)), findsOneWidget);
    expect(_inDialog(find.text(l10n.orderConfirmStopLoss)), findsOneWidget);
    expect(_inDialog(find.text('${l10n.openOrdersLastPrice} ≥ 81000 USDT')), findsOneWidget);
    expect(_inDialog(find.text('${l10n.openOrdersMarkPrice} ≤ 79000 USDT')), findsOneWidget);
  });

  testWidgets('selected advanced settings appear as extra rows', (tester) async {
    await _open(
      tester,
      _intent(
        liveDraft(
          price: '',
          peg: LiveOrderPeg.counterparty,
          timeInForce: LiveOrderTimeInForce.ioc,
          reduceOnly: true,
          trigger: const LiveOrderTrigger(
            kind: LiveOrderTriggerKind.stop,
            price: '81000',
            basis: LiveOrderTriggerBasis.mark,
            protect: true,
          ),
        ),
      ),
      () async => const OrderSubmissionOutcome(OrderSubmissionKind.success),
    );
    final l10n = _l10n(tester);
    expect(_inDialog(find.text(l10n.attachedEntryCounterparty(1))), findsOneWidget);
    expect(_inDialog(find.text(l10n.liveOrderPolicyIoc)), findsOneWidget);
    expect(_inDialog(find.text(l10n.reduceOnly)), findsOneWidget);
    expect(_inDialog(find.text('${l10n.openOrdersMarkPrice} ≥ 81000 USDT')), findsOneWidget);
    expect(_inDialog(find.text(l10n.liveOrderTriggerProtect)), findsOneWidget);
    expect(_inDialog(find.text(l10n.openOrdersStopLimit)), findsOneWidget);
    // Reducing orders label the close direction.
    expect(_inDialog(find.text(l10n.liveCloseLong)), findsNothing);
    expect(_inDialog(find.text(l10n.liveCloseShort)), findsNWidgets(2));
  });

  for (final (size, scale, language) in [
    (const Size(320, 844), 1.5, 'zh'),
    (const Size(844, 390), 1.0, 'en'),
    (const Size(768, 1024), 1.3, 'en'),
  ]) {
    testWidgets('fits $size at ${scale}x $language', (tester) async {
      await _open(
        tester,
        _intent(
          liveDraft(
            buy: false,
            reduceOnly: true,
            attachment: const LiveOrderAttachment(
              takeProfit: AttachedExit(kind: LiveOrderTriggerKind.takeProfit, price: '79000'),
              stopLoss: AttachedExit(kind: LiveOrderTriggerKind.stop, price: '81000'),
            ),
          ),
        ),
        () async => const OrderSubmissionOutcome(OrderSubmissionKind.success),
        size: size,
        scale: scale,
        language: language,
      );
      expect(tester.takeException(), isNull);
      final confirm = find.byKey(const Key('live-order-confirm'));
      await tester.ensureVisible(confirm);
      expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }
}
