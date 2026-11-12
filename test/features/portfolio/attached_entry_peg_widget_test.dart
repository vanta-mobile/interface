import '../../support/order_mode_widget.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/data/order_recovery_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/attached_entry_peg.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_attachment.dart';
import 'package:vanta/features/portfolio/domain/order_query.dart';
import 'package:vanta/features/portfolio/domain/order_recovery.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/portfolio/application/order_recovery_provider.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/attached_order.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/order_recovery.dart';
import '../../support/trade_fixture.dart';

import '../../support/live_order_widget.dart';
import '../../support/order_confirmation_widget.dart';

void main() {
  Future<void> visible(WidgetTester tester, String key) async {
    final scroll = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(Key(key)), 180, scrollable: scroll);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    if (await toggleOrderMode(tester, key)) return;
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    if (key == 'live-order-quantity') await selectLiveBase(tester);
    await visible(tester, key);
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    openLiveOrder(tester.element(find.byType(Navigator).first), 'BTCUSDT');
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
  }

  AppLocalizations messages(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
  Future<void> choose(WidgetTester tester, String label) async {
    await tap(tester, 'attached-entry-pricing');
    await tester.scrollUntilVisible(
      find.text(label),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    final item = find.text(label).last;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  Future<void> priceMode(WidgetTester tester, String side) async {
    await tap(tester, 'attached-$side-mode');
    final price = find
        .text(
          AppLocalizations.of(tester.element(find.byType(LiveOrderScreen))).attachedOrderPriceMode,
        )
        .last;
    await tester.ensureVisible(price);
    await tester.tap(price);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await field(tester, 'live-order-quantity', '0.001');
    await field(tester, 'live-order-price', '80000');
    await tap(tester, 'live-order-attached');
    await tap(tester, 'attached-tp-enabled');
    await priceMode(tester, 'tp');
    await field(tester, 'attached-tp-price', '81000');
  }

  LiveOrderResult verified() => LiveOrderResult(
    strategy: AttachedOrderSnapshot(
      strategyId: '9876',
      status: 'WORKING',
      legs: const [
        AttachedOrderLeg(sequence: 1, status: 'NEW', orderId: '100'),
        AttachedOrderLeg(sequence: 2, status: 'PENDING_NEW'),
      ],
    ),
  );

  for (final language in ['en', 'zh']) {
    testWidgets(
      'BBO selection/review/unknown query retains level at 320/large/landscape $language',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final repository =
            (TestLiveOrderRepository()..context = liveContext(bid: '80000', ask: '80000'))
              ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(language),
          identityRepository: identity,
          liveOrderRepository: repository,
          liveClock: () => liveOrderClock,
        );
        await open(tester, container);
        expect(find.byKey(const Key('attached-entry-pricing')), findsNothing);
        await fill(tester);
        final l10n = messages(tester);
        await choose(tester, l10n.attachedEntryQueue(20));
        final selectedText = find.text(l10n.attachedEntryQueue(20)).last;
        expect(tester.renderObject<RenderParagraph>(selectedText).didExceedMaxLines, false);
        final textRect = tester.getRect(selectedText);
        final buttonRect = tester.getRect(find.byKey(const Key('attached-entry-pricing')));
        expect(textRect.top, greaterThanOrEqualTo(buttonRect.top));
        expect(textRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
        expect(find.byKey(const Key('live-order-price')), findsNothing);
        await tap(tester, 'live-order-read'); // Refresh preserves all selected terms.
        await visible(tester, 'attached-entry-pricing');
        expect(
          tester
              .widget<DropdownButton<String>>(find.byKey(const Key('attached-entry-pricing')))
              .value,
          'QUEUE_20',
        );
        await tap(tester, 'live-order-review');
        final dialog = find.byType(OrderConfirmationDialog);
        expect(
          find.descendant(of: dialog, matching: find.text(l10n.attachedEntryQueue(20))),
          findsOneWidget,
        );
        expect(find.descendant(of: dialog, matching: find.text('0')), findsNothing);
        expect(repository.submits, 0);
        expect(tester.takeException(), null);
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(tester.takeException(), null);
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        await tap(tester, 'live-order-review');
        final confirm = find.byKey(const Key('live-order-confirm'));
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        await dismissOrderConfirmation(tester);
        expect(repository.submits, 1);
        final original = repository.lastIntent!;
        expect(original.draft.attachment!.entryPeg, AttachedEntryPeg.queue20);
        expect(original.draft.price, '');
        await visible(tester, 'attached-entry-pricing');
        expect(
          tester
              .widget<DropdownButton<String>>(find.byKey(const Key('attached-entry-pricing')))
              .onChanged,
          null,
        );
        repository.result = verified();
        await tap(tester, 'live-order-recheck');
        expect(repository.submits, 1);
        expect(repository.checks, 1);
        expect(repository.lastIntent!.clientOrderId, original.clientOrderId);
        expect(repository.lastIntent!.draft.attachment!.entryPeg, AttachedEntryPeg.queue20);
        expect(find.text(l10n.attachedOrderVerified), findsOneWidget);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
    testWidgets(
      'fixed price survives BBO and market/attachment toggles; no accidental zero $language',
      (tester) async {
        final identity = TestIdentityRepository()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final repository = (TestLiveOrderRepository()
          ..context = liveContext(bid: '80000', ask: '80000'));
        final container = setup(
          tester,
          width: 320,
          scale: 1.5,
          language: Locale(language),
          identityRepository: identity,
          liveOrderRepository: repository,
          liveClock: () => liveOrderClock,
        );
        await open(tester, container);
        await fill(tester);
        final l10n = messages(tester);
        await choose(tester, l10n.attachedEntryCounterparty(3));
        await tap(tester, 'live-order-attached');
        await visible(tester, 'live-order-price');
        expect(
          tester.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
          '80000',
        );
        expect(find.byKey(const Key('attached-entry-pricing')), findsNothing);
        await tap(tester, 'live-order-attached');
        await chooseOrderExecution(tester, true);
        expect(find.byKey(const Key('attached-entry-pricing')), findsNothing);
        await tap(tester, 'live-order-review');
        expect(find.text(l10n.attachedEntryPegTiming), findsNothing);
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        await chooseOrderExecution(tester, false);
        await choose(tester, l10n.attachedEntryFixed);
        await visible(tester, 'live-order-price');
        expect(
          tester.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
          '80000',
        );
        expect(repository.submits, 0);
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
    testWidgets('internal verification preserves durable BBO pricing $language', (tester) async {
      final record = OrderRecoveryRecord(
        query: OrderQuery.capture(attachedIntent(peg: AttachedEntryPeg.counterparty10)),
        createdAt: liveOrderClock,
      );
      final journal = MemoryOrderRecoveryJournal(records: [record]);
      addTearDown(journal.close);
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final repository = TestOrderRecoveryRepository(journal)..result = verified();
      final container = setup(
        tester,
        width: 320,
        scale: 1.5,
        language: Locale(language),
        identityRepository: identity,
        recoveryJournal: journal,
        recoveryRepository: repository,
      );
      await launch(tester, container);
      expect(repository.calls, 0);
      await container.read(orderRecoveryProvider.notifier).query(record.key);
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(repository.latestQuery!.draft.attachment!.entryPeg, AttachedEntryPeg.counterparty10);
      expect(journal.snapshot.records, isEmpty);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
