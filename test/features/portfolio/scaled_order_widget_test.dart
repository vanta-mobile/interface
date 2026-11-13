import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/scaled_order_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/presentation/scaled_order_screen.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/scaled_order.dart';
import '../../support/scaled_order_widget.dart';
import '../../support/trade_fixture.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('scaled preview/confirmation/unknown query, 320 text1.5 and landscape $language', (
      tester,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final repository = TestScaledRepository()..unknown = true;
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
      final l10n = messages(tester);
      expect(tester.widget<TextField>(find.byKey(const Key('scaled-low'))).controller!.text, '');
      await fill(tester);
      expect(find.text('0.003'), findsNWidgets(2));
      expect(find.text('0.002'), findsOneWidget);
      expect(find.text('37.5%'), findsNWidgets(2));
      expect(find.text('639 USDT'), findsOneWidget);
      await tap(tester, 'scaled-review');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text(l10n.scaledRule)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.scaledOrderNumber(3)),
        ),
        findsOneWidget,
      );
      expect(repository.posts, isEmpty);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const Key('scaled-quantity'))).controller!.text,
        '0.008',
      );
      await tap(tester, 'scaled-review');
      await tester.ensureVisible(find.byKey(const Key('scaled-confirm')));
      await tester.tap(find.byKey(const Key('scaled-confirm')));
      await tester.pumpAndSettle();
      expect(repository.posts.length, 1);
      // Settled unknown scaled orders no longer lock input (docs/implementation.md,
      // 2026-11-11 "Make order records observational and nonblocking").
      expect(tester.widget<TextField>(find.byKey(const Key('scaled-low'))).enabled, true);
      expect(container.read(scaledOrderProvider).needsRecheck, true);
      await visible(tester, 'scaled-recheck');
      expect(find.text(l10n.liveOrderOutcomeUnknown), findsOneWidget);
      tester.view.physicalSize = const Size(844, 320);
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      repository.unknown = false;
      await tap(tester, 'scaled-recheck');
      expect(repository.posts.length, 1);
      expect(repository.checks.length, 1);
      expect(container.read(scaledOrderProvider).items.skip(1).every((i) => !i.submitted), true);
      expect(
        tester.widget<TextField>(find.byKey(const Key('scaled-quantity'))).controller!.text,
        '0.008',
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
    });
  }
  testWidgets('refused signature keeps input and displays safe reason', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestScaledRepository()
      ..failure = const AccountReadFailure('authWalletRejected');
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await fill(tester);
    await tap(tester, 'scaled-review');
    await tester.tap(find.byKey(const Key('scaled-confirm')));
    await tester.pumpAndSettle();
    expect(repository.posts, isEmpty);
    expect(tester.widget<TextField>(find.byKey(const Key('scaled-low'))).controller!.text, '79000');
    expect(container.read(scaledOrderProvider).items.first.failure?.key, 'authWalletRejected');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
  testWidgets('leaving the page during signing stops POST and all unsent children', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestScaledRepository()..signingGate = Completer<void>();
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await fill(tester);
    await tap(tester, 'scaled-review');
    await tester.tap(find.byKey(const Key('scaled-confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(scaledOrderProvider).busy, true);
    Navigator.of(tester.element(find.byType(ScaledOrderScreen))).pop();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(scaledOrderProvider).stopRequested, true);
    repository.signingGate!.complete();
    await tester.pumpAndSettle();
    expect(repository.posts, isEmpty);
    expect(container.read(scaledOrderProvider).busy, false);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
  testWidgets('wallet change clears form and results, empty inputs on reconnect', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestScaledRepository();
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await fill(tester);
    identity.events.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scaled-low')), findsNothing);
    await container.read(authProvider.notifier).bootstrap();
    await tester.pumpAndSettle();
    await tap(tester, 'scaled-read');
    expect(tester.widget<TextField>(find.byKey(const Key('scaled-low'))).controller!.text, '');
    expect(identity.wallets, 0);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });

  testWidgets('stop button retains sent result and leaves four unsent children', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestScaledRepository()..queryGate = Completer<void>();
    final container = setup(
      tester,
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await fill(tester);
    await field(tester, 'scaled-count', '5');
    await tap(tester, 'scaled-sell');
    await tap(tester, 'scaled-review');
    final l10n = messages(tester);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(l10n.scaledOrderNumber(5))),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('scaled-confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.posts.length, 1);
    expect(repository.posts.single.side, 'SELL');
    await tap(tester, 'scaled-stop', settle: false);
    expect(container.read(scaledOrderProvider).stopRequested, true);
    repository.queryGate!.complete();
    await tester.pumpAndSettle();
    expect(repository.posts.length, 1);
    expect(container.read(scaledOrderProvider).items.skip(1).length, 4);
    expect(container.read(scaledOrderProvider).items.skip(1).every((i) => !i.submitted), true);
    expect(container.read(scaledOrderProvider).items.first.result?.status, 'NEW');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}
