import '../../support/order_mode_widget.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/identity_repository.dart';
import '../../support/aster_account.dart';
import '../../support/live_order.dart';
import '../../support/trade_fixture.dart';

import '../../support/live_order_widget.dart';

void main() {
  Future<void> visible(WidgetTester tester, String key) async {
    final scrollable = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(Key(key)), 180, scrollable: scrollable);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    if (await toggleOrderMode(tester, key)) return;
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, ProviderContainer container, {bool close = false}) async {
    await launch(tester, container);
    final context = tester.element(find.byType(Navigator).first);
    if (close) {
      openLiveClose(context, 'BTCUSDT', 'BOTH');
    } else {
      openLiveOrder(context, 'BTCUSDT');
    }
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
  }

  AppLocalizations messages(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));

  Future<void> setMarket(WidgetTester tester, bool value) async {
    await chooseOrderExecution(tester, value);
  }

  String label(AppLocalizations l10n, LiveOrderTimeInForce policy) => switch (policy) {
    LiveOrderTimeInForce.gtc => l10n.liveOrderPolicyGtc,
    LiveOrderTimeInForce.ioc => l10n.liveOrderPolicyIoc,
    LiveOrderTimeInForce.postOnly => l10n.liveOrderPolicyPostOnly,
    LiveOrderTimeInForce.hidden => l10n.liveOrderPolicyHidden,
  };

  Future<void> select(WidgetTester tester, LiveOrderTimeInForce policy) async {
    final text = label(messages(tester), policy);
    await tap(tester, 'live-order-policy');
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await visible(tester, 'live-order-quantity');
    await selectLiveBase(tester);
    await tester.enterText(find.byKey(const Key('live-order-quantity')), '0.001');
    await visible(tester, 'live-order-price');
    await tester.enterText(find.byKey(const Key('live-order-price')), '80000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  for (final language in ['en', 'zh']) {
    for (final policy in [
      LiveOrderTimeInForce.ioc,
      LiveOrderTimeInForce.postOnly,
      LiveOrderTimeInForce.hidden,
    ]) {
      testWidgets(
        '${policy.wire} review, cancel and unknown recovery at enlarged narrow/landscape: $language',
        (tester) async {
          final identity = TestIdentityRepository()..restored = signingIdentity;
          final repository = TestLiveOrderRepository()
            ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
          addTearDown(identity.dispose);
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
          await select(tester, policy);
          await fill(tester);
          final l10n = messages(tester);
          await tap(tester, 'live-order-review');
          expect(
            find.descendant(of: find.byType(AlertDialog), matching: find.text(label(l10n, policy))),
            findsOneWidget,
          );
          expect(tester.takeException(), null);
          tester.view.physicalSize = const Size(844, 390);
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          await tester.tap(find.text(l10n.cancel));
          await tester.pumpAndSettle();
          expect(repository.submits, 0);
          expect(
            tester
                .widget<DropdownButton<LiveOrderTimeInForce>>(
                  find.byKey(const Key('live-order-policy')),
                )
                .value,
            policy,
          );
          await tap(tester, 'live-order-review');
          await tester.tap(find.byKey(const Key('live-order-confirm')));
          await tester.pumpAndSettle();
          expect(repository.lastIntent!.draft.timeInForce, policy);
          expect(repository.submits, 1);
          expect(
            tester
                .widget<DropdownButton<LiveOrderTimeInForce>>(
                  find.byKey(const Key('live-order-policy')),
                )
                .onChanged,
            null,
          );
          final id = repository.lastIntent!.clientOrderId;
          repository.result = LiveOrderResult(
            orderId: '12345',
            status: 'EXPIRED',
            executedQuantity: Decimal.zero,
          );
          await tap(tester, 'live-order-recheck');
          expect(repository.lastIntent!.clientOrderId, id);
          expect(repository.lastIntent!.draft.timeInForce, policy);
          expect(repository.checks, 1);
          expect(repository.submits, 1);
          expect(identity.wallets, 0);
          expect(tester.takeException(), null);
          await dispose(tester, container);
        },
      );
    }

    testWidgets('Hidden dedicated close keeps direction and policy: $language', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestLiveOrderRepository()..context = liveCloseContext();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        language: Locale(language),
        identityRepository: identity,
        liveOrderRepository: repository,
        liveClock: () => liveOrderClock,
      );
      await open(tester, container, close: true);
      await setMarket(tester, false);
      await select(tester, LiveOrderTimeInForce.hidden);
      await fill(tester);
      await tap(tester, 'live-order-review');
      final l10n = messages(tester);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.liveOrderPolicyHidden),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      expect(repository.lastIncludeFunds, false);
      expect(repository.lastIntent!.parameters['reduceOnly'], 'true');
      expect(repository.lastIntent!.parameters['side'], 'SELL');
      expect(repository.lastIntent!.parameters['timeInForce'], 'HIDDEN');
      expect(tester.takeException(), null);
      await dispose(tester, container);
    });
  }

  testWidgets('unsupported refreshed policy keeps input and requires an explicit new selection', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestLiveOrderRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await select(tester, LiveOrderTimeInForce.postOnly);
    await fill(tester);
    repository.context = liveContext(policies: {LiveOrderTimeInForce.gtc});
    await tap(tester, 'live-order-read');
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-price'))).controller!.text,
      '80000',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('live-order-quantity'))).controller!.text,
      '0.001',
    );
    expect(
      tester
          .widget<DropdownButton<LiveOrderTimeInForce>>(find.byKey(const Key('live-order-policy')))
          .value,
      null,
    );
    await visible(tester, 'live-order-review');
    expect(tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed, null);
    await visible(tester, 'live-order-policy');
    final fixed = tester.widget<DropdownButton<LiveOrderTimeInForce>>(
      find.byKey(const Key('live-order-policy')),
    );
    expect(fixed.onChanged, null);
    expect(fixed.items, isEmpty);
    await chooseOrderMode(tester, LiveOrderEntryMode.limit);
    await visible(tester, 'live-order-review');
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
      isNotNull,
    );
    expect(repository.submits, 0);
    await dispose(tester, container);
  });

  testWidgets('market round trip keeps the limit selection but sends no limit-only fields', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestLiveOrderRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      language: const Locale('en'),
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await open(tester, container);
    await select(tester, LiveOrderTimeInForce.hidden);
    await fill(tester);
    await setMarket(tester, true);
    expect(find.byKey(const Key('live-order-policy')), findsNothing);
    await setMarket(tester, false);
    await visible(tester, 'live-order-policy');
    expect(
      tester
          .widget<DropdownButton<LiveOrderTimeInForce>>(find.byKey(const Key('live-order-policy')))
          .value,
      LiveOrderTimeInForce.hidden,
    );
    await setMarket(tester, true);
    await tap(tester, 'live-order-review');
    final l10n = messages(tester);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(l10n.liveOrderPolicy)),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    expect(repository.lastIntent!.draft.market, true);
    expect(repository.lastIntent!.parameters.containsKey('timeInForce'), false);
    expect(repository.lastIntent!.parameters.containsKey('price'), false);
    expect(tester.takeException(), null);
    await dispose(tester, container);
  });
}
