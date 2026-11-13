import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/application/order_cancellation_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_order_card.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/batch_order_cancellation.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/workspace_navigation.dart';

const bulkKey = Key('cancel-all-open-orders');
const confirmKey = Key('confirm-batch-cancel');

/// Open orders live in the Open tab of the Futures account section below the
/// trade workspace (0a18176, docs/implementation.md 2026-11-11).
Future<void> showOpenOrders(WidgetTester tester, ProviderContainer container) async {
  await launch(tester, container);
  await revealFuturesAccountTabs(tester);
  await container.read(openOrdersReadProvider.notifier).refresh();
  await tester.pumpAndSettle();
}

/// The redesigned Cancel all bottom sheet that holds [confirmKey].
Finder sheet() =>
    find.ancestor(of: find.byKey(confirmKey), matching: find.byType(SingleChildScrollView)).first;

VoidCallback? bulkAction(WidgetTester tester) =>
    tester.widget<TextButton>(find.byKey(bulkKey)).onPressed;

Future<void> openConfirmation(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(bulkKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(bulkKey));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(confirmKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(confirmKey));
}

void main() {
  for (final signedIn in [false, true]) {
    testWidgets('bulk action disabled before live read; signed in: $signedIn', (tester) async {
      final identity = TestIdentityRepository()..restored = signedIn ? signingIdentity : null;
      final batch = TestBatchCancellationRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        openOrdersRepository: TestOpenOrdersRepository(),
        batchCancellationRepository: batch,
      );
      await launch(tester, container);
      await revealFuturesAccountTabs(tester);
      expect(bulkAction(tester), null);
      expect(batch.cancelled, isEmpty);
      expect(container.read(openOrdersReadProvider).account, null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }

  testWidgets(
    'confirmation shows wallet, exact symbol scope and snapshot count; keep sends nothing',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final batch = TestBatchCancellationRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        openOrdersRepository: TestOpenOrdersRepository(),
        batchCancellationRepository: batch,
        language: const Locale('en'),
      );
      await showOpenOrders(tester, container);
      await openConfirmation(tester);
      // Figma 331:67880: title, warning mark, question and the two actions only.
      expect(
        find.descendant(
          of: sheet(),
          matching: find.text('Are you sure you want to cancel all perpetual orders?'),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: sheet(), matching: find.text('Cancel all')), findsOneWidget);
      expect(
        find.descendant(of: sheet(), matching: find.textContaining('Snapshot:')),
        findsNothing,
      );
      await tester.tap(find.descendant(of: sheet(), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(batch.cancelled, isEmpty);
      expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('current-symbol scope cancels only confirmed symbol and preserves other orders', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final batch = TestBatchCancellationRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: TestOpenOrdersRepository(),
      batchCancellationRepository: batch,
      language: const Locale('en'),
    );
    await showOpenOrders(tester, container);
    await tester.ensureVisible(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    await openConfirmation(tester);
    expect(
      find.descendant(
        of: sheet(),
        matching: find.text('Are you sure you want to cancel all BTCUSDT orders?'),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: sheet(), matching: find.textContaining('ETHUSDT')), findsNothing);

    await confirm(tester);
    await tester.pumpAndSettle();
    expect(batch.cancelled, ['BTCUSDT']);
    expect(find.text('No open orders at last check'), findsOneWidget);
    expect(container.read(openOrdersReadProvider).account!.orders.single.symbol, 'ETHUSDT');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('unknown result locks actions; GET recheck never submits untouched symbols', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final batch = TestBatchCancellationRepository()
      ..results['BTCUSDT'] = const BatchSymbolCancellation(
        symbol: 'BTCUSDT',
        submitted: true,
        failure: AccountReadFailure('accountNetwork'),
      );
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: TestOpenOrdersRepository(),
      batchCancellationRepository: batch,
      language: const Locale('en'),
    );
    await showOpenOrders(tester, container);
    await openConfirmation(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(batch.cancelled, ['BTCUSDT']);
    expect(find.text('Outcome unconfirmed. Check status before retrying.'), findsOneWidget);
    expect(find.text('Not submitted'), findsOneWidget);
    expect(bulkAction(tester), null);
    expect(
      tester
          .widget<OpenOrderChipButton>(find.byKey(const Key('cancel-order-BTCUSDT-1917641')))
          .onPressed,
      null,
    );
    expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
    batch.results.remove('BTCUSDT');
    await tester.ensureVisible(find.byKey(const Key('recheck-batch-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recheck-batch-cancel')));
    await tester.pumpAndSettle();
    expect(batch.checked, ['BTCUSDT']);
    expect(batch.cancelled, ['BTCUSDT']);
    expect(find.byKey(const Key('recheck-batch-cancel')), findsNothing);
    expect(find.text('Not submitted'), findsOneWidget);
    expect(container.read(openOrdersReadProvider).account!.orders.single.symbol, 'ETHUSDT');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('stop lets current request settle and prevents the next submission', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final batch = TestBatchCancellationRepository()..gates['BTCUSDT'] = Completer<void>();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: TestOpenOrdersRepository(),
      batchCancellationRepository: batch,
      language: const Locale('en'),
    );
    await showOpenOrders(tester, container);
    await openConfirmation(tester);
    await confirm(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(batch.cancelled, ['BTCUSDT']);
    expect(find.text('Processing; outcome not yet verified'), findsOneWidget);
    expect(bulkAction(tester), null);
    await tester.ensureVisible(find.byKey(const Key('stop-batch-cancel')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('stop-batch-cancel')));
    await tester.pump();
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('stop-batch-cancel'))).onPressed,
      null,
    );
    batch.gates['BTCUSDT']!.complete();
    await tester.pumpAndSettle();
    expect(batch.cancelled, ['BTCUSDT']);
    expect(find.text('Further submissions stopped. Check each symbol’s result.'), findsOneWidget);
    expect(find.text('Not submitted'), findsOneWidget);
    expect(container.read(openOrdersReadProvider).account!.orders.single.symbol, 'ETHUSDT');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final variant in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('bulk confirmation and result fit ${variant.$1}x${variant.$2} ${variant.$4}', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final batch = TestBatchCancellationRepository()
        ..results['BTCUSDT'] = const BatchSymbolCancellation(symbol: 'BTCUSDT', submitted: true);
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        openOrdersRepository: TestOpenOrdersRepository(),
        batchCancellationRepository: batch,
        width: variant.$1,
        scale: variant.$3,
        language: Locale(variant.$4),
      );
      tester.view.physicalSize = Size(variant.$1, variant.$2);
      await showOpenOrders(tester, container);
      await openConfirmation(tester);
      expect(tester.takeException(), null);
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      final report = container.read(orderCancellationProvider).batch;
      container.read(localeProvider.notifier).select(variant.$4 == 'en' ? 'zh' : 'en');
      await tester.pumpAndSettle();
      expect(container.read(orderCancellationProvider).batch, same(report));
      expect(find.byKey(const Key('recheck-batch-cancel')), findsOneWidget);
      expect(batch.cancelled, ['BTCUSDT']);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
