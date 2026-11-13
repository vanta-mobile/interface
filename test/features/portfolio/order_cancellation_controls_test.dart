import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/open_orders_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_order_card.dart';
import 'package:vanta/features/trade/application/providers.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/order_cancellation.dart';
import '../../support/trade_fixture.dart';
import '../../support/workspace_navigation.dart';

/// Open orders live in the Open tab of the Futures account section below the
/// trade workspace (0a18176, docs/implementation.md 2026-11-11).
Future<void> _showOpenOrders(WidgetTester tester, ProviderContainer container) async {
  await launch(tester, container);
  await revealFuturesAccountTabs(tester);
  await container.read(openOrdersReadProvider.notifier).refresh();
  await tester.pumpAndSettle();
}

/// The centred Open Orders confirmation that holds [confirmKey].
Finder _prompt() => find
    .ancestor(of: find.byKey(const Key('confirm-order-cancel')), matching: find.byType(Material))
    .last;

void main() {
  const cancelKey = Key('cancel-order-BTCUSDT-1917641');

  testWidgets('confirmation shows account and order; keeping order sends no cancellation', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final cancellation = TestOrderCancellationRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: TestOpenOrdersRepository(),
      orderCancellationRepository: cancellation,
      language: const Locale('en'),
    );
    await _showOpenOrders(tester, container);
    await tester.ensureVisible(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm-order-cancel')), findsOneWidget);
    expect(find.descendant(of: _prompt(), matching: find.text(accountAddress)), findsOneWidget);
    expect(
      find.descendant(of: _prompt(), matching: find.text('BTCUSDT · 1917641')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _prompt(), matching: find.textContaining('unfilled remainder')),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: _prompt(), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(cancellation.cancels, 0);
    expect(container.read(openOrdersReadProvider).account!.orders.length, 2);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('confirmed action disables repeats and a filled result is not labelled cancelled', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final cancellation = TestOrderCancellationRepository()
      ..gate = Completer<void>()
      ..result = const OrderCancellationResult(
        resolution: OrderResolution(symbol: 'BTCUSDT', orderId: '1917641', status: 'FILLED'),
      );
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: TestOpenOrdersRepository(),
      orderCancellationRepository: cancellation,
      language: const Locale('en'),
    );
    await _showOpenOrders(tester, container);
    await tester.ensureVisible(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-order-cancel')));
    await tester.pump();
    expect(cancellation.cancels, 1);
    expect(tester.widget<OpenOrderChipButton>(find.byKey(cancelKey)).onPressed, null);
    // The trade page has no manual read button any more; Cancel all is the
    // other open-order write and must also be locked.
    expect(
      tester.widget<TextButton>(find.byKey(const Key('cancel-all-open-orders'))).onPressed,
      null,
    );
    cancellation.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(cancelKey), findsNothing);
    expect(find.textContaining('fully filled. It was not cancelled'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('unknown result preserves order; recheck has no duplicate cancellation', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final cancellation = TestOrderCancellationRepository()
      ..result = const OrderCancellationResult(failure: AccountReadFailure('accountNetwork'));
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: TestOpenOrdersRepository(),
      orderCancellationRepository: cancellation,
      language: const Locale('en'),
    );
    await _showOpenOrders(tester, container);
    await tester.ensureVisible(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-order-cancel')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cancellation outcome is unconfirmed'), findsOneWidget);
    expect(tester.widget<OpenOrderChipButton>(find.byKey(cancelKey)).onPressed, null);
    cancellation.result = const OrderCancellationResult(
      resolution: OrderResolution(symbol: 'BTCUSDT', orderId: '1917641', status: 'CANCELED'),
    );
    await tester.ensureVisible(find.byKey(const Key('recheck-order-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recheck-order-cancel')));
    await tester.pumpAndSettle();
    expect(cancellation.checks, 1);
    expect(cancellation.cancels, 1);
    expect(find.byKey(cancelKey), findsNothing);
  });

  testWidgets('account switch while dialog is open prevents cancellation', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final cancellation = TestOrderCancellationRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      openOrdersRepository: TestOpenOrdersRepository(),
      orderCancellationRepository: cancellation,
    );
    await _showOpenOrders(tester, container);
    await tester.ensureVisible(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cancelKey));
    await tester.pumpAndSettle();
    identity.events.add(null);
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-order-cancel')));
    await tester.pumpAndSettle();
    expect(cancellation.cancels, 0);
  });

  for (final variant in [(360.0, 844.0, 1.5, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('confirmation and unknown state fit ${variant.$1}x${variant.$2} ${variant.$4}', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final cancellation = TestOrderCancellationRepository()
        ..result = const OrderCancellationResult();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        openOrdersRepository: TestOpenOrdersRepository(),
        orderCancellationRepository: cancellation,
        width: variant.$1,
        scale: variant.$3,
        language: Locale(variant.$4),
      );
      tester.view.physicalSize = Size(variant.$1, variant.$2);
      await _showOpenOrders(tester, container);
      await tester.ensureVisible(find.byKey(cancelKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(cancelKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.ensureVisible(find.byKey(const Key('confirm-order-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-order-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-cancel-result')), findsOneWidget);
      expect(tester.takeException(), null);
      container.read(localeProvider.notifier).select(variant.$4 == 'en' ? 'zh' : 'en');
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
