import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/application/order_cancellation_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/batch_order_cancellation.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

const bulkKey = Key('cancel-all-open-orders');
const confirmKey = Key('confirm-batch-cancel');

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
      expect(tester.widget<OutlinedButton>(find.byKey(bulkKey)).onPressed, null);
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
      await launch(tester, container);
      await container.read(openOrdersReadProvider.notifier).refresh();
      await tester.pumpAndSettle();
      await openConfirmation(tester);
      final dialog = find.byType(AlertDialog);
      for (final text in [
        accountAddress,
        'BTCUSDT',
        'ETHUSDT',
        'Snapshot: 2 orders across 2 symbols',
      ]) {
        expect(find.descendant(of: dialog, matching: find.text(text)), findsOneWidget);
      }
      expect(find.textContaining('including orders added on other devices'), findsOneWidget);
      await tester.tap(find.text('Keep order'));
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
    await launch(tester, container);
    await container.read(openOrdersReadProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-orders-current-symbol')));
    await tester.pumpAndSettle();
    await openConfirmation(tester);
    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.text('BTCUSDT')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('ETHUSDT')), findsNothing);
    expect(find.text('Snapshot: 1 order across 1 symbol'), findsOneWidget);
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
    await launch(tester, container);
    await container.read(openOrdersReadProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await openConfirmation(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(batch.cancelled, ['BTCUSDT']);
    expect(find.text('Outcome unconfirmed. Check status before retrying.'), findsOneWidget);
    expect(find.text('Not submitted'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(bulkKey)).onPressed, null);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('cancel-order-BTCUSDT-1917641')))
          .onPressed,
      null,
    );
    expect(tester.widget<FilledButton>(find.byKey(const Key('read-open-orders'))).onPressed, null);
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
    await launch(tester, container);
    await container.read(openOrdersReadProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await openConfirmation(tester);
    await confirm(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(batch.cancelled, ['BTCUSDT']);
    expect(find.text('Processing; outcome not yet verified'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(bulkKey)).onPressed, null);
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
      await launch(tester, container);
      await container.read(openOrdersReadProvider.notifier).refresh();
      await tester.pumpAndSettle();
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
