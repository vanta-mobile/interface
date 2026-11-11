import '../../support/order_confirmation_widget.dart';
import '../../support/order_mode_widget.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/presentation/order_confirmation_dialog.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> visible(WidgetTester tester, String key) async {
    final scroll = find
        .descendant(of: find.byKey(const Key('live-order-page')), matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(Key(key)), 180, scrollable: scroll);
    await Scrollable.ensureVisible(tester.element(find.byKey(Key(key))), alignment: .5);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    if (await toggleOrderMode(tester, key)) return;
    await visible(tester, key);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String key, String value) async {
    await visible(tester, key);
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  String input(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
  AppLocalizations messages(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
  Future<void> market(WidgetTester tester) async {
    await chooseOrderExecution(tester, true);
  }

  Future<void> preview(WidgetTester tester, String quantity) async {
    await visible(tester, 'live-order-size-preview');
    expect(
      find.descendant(
        of: find.byKey(const Key('live-order-size-preview')),
        matching: find.text('$quantity BTC'),
      ),
      findsOneWidget,
    );
  }

  Future<void> cancel(WidgetTester tester) async {
    await tester.tap(find.text(messages(tester).cancel));
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    TestLiveOrderRepository repository, {
    String locale = 'en',
    double width = 430,
    double scale = 1,
    String? closingSide,
  }) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      width: width,
      scale: scale,
      language: Locale(locale),
      identityRepository: identity,
      liveOrderRepository: repository,
      liveClock: () => liveOrderClock,
    );
    await launch(tester, container);
    final context = tester.element(find.byType(Navigator).first);
    if (closingSide == null) {
      openLiveOrder(context, 'BTCUSDT');
    } else {
      openLiveClose(context, 'BTCUSDT', closingSide);
    }
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
    return container;
  }

  Future<void> dispose(WidgetTester tester, ProviderContainer container) async {
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('production defaults quote blank, valid Last limit, BUY/GTC; trigger/trailing Mark', (
    tester,
  ) async {
    final repository = TestLiveOrderRepository();
    final container = await open(tester, repository);
    await visible(tester, 'live-order-unit-quote');
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('live-order-unit-quote'))).selected,
      true,
    );
    await visible(tester, 'live-order-quantity');
    expect(input(tester, 'live-order-quantity'), '');
    await visible(tester, 'live-order-price');
    expect(input(tester, 'live-order-price'), '80001');
    expect(find.text(messages(tester).liveAmountInvalid), findsNothing);
    await field(tester, 'live-order-quantity', '160');
    await tap(tester, 'live-order-review');
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    await dismissOrderConfirmation(tester);
    expect(repository.lastIntent!.draft.buy, true);
    expect(repository.lastIntent!.draft.timeInForce, LiveOrderTimeInForce.gtc);
    expect(repository.lastIntent!.draft.market, false);
    await tap(tester, 'live-order-conditional');
    await visible(tester, 'live-order-trigger-basis');
    expect(
      tester
          .widget<DropdownButton<LiveOrderTriggerBasis>>(
            find.byKey(const Key('live-order-trigger-basis')),
          )
          .value,
      LiveOrderTriggerBasis.mark,
    );
    await tap(tester, 'live-order-trailing');
    await visible(tester, 'live-trailing-basis');
    expect(
      tester
          .widget<DropdownButton<LiveOrderTriggerBasis>>(
            find.byKey(const Key('live-trailing-basis')),
          )
          .value,
      LiveOrderTriggerBasis.mark,
    );
    expect(input(tester, 'live-trailing-activation'), '');
    await visible(tester, 'live-trailing-rate');
    expect(input(tester, 'live-trailing-rate'), '');
    await dispose(tester, container);
  });
  testWidgets('unit switches preserve independent raw inputs and limit changes recalculate', (
    tester,
  ) async {
    final container = await open(tester, TestLiveOrderRepository());
    await field(tester, 'live-order-quantity', '160.000');
    await field(tester, 'live-order-price', '80000');
    await preview(tester, '0.002');
    await tap(tester, 'live-order-unit-base');
    await visible(tester, 'live-order-quantity');
    expect(input(tester, 'live-order-quantity'), '');
    await field(tester, 'live-order-quantity', '0.0030');
    await tap(tester, 'live-order-unit-quote');
    expect(input(tester, 'live-order-quantity'), '160.000');
    await field(tester, 'live-order-price', '81000');
    await preview(tester, '0.001');
    await tap(tester, 'live-order-unit-base');
    expect(input(tester, 'live-order-quantity'), '0.0030');
    await dispose(tester, container);
  });
  testWidgets(
    'market uses ask/bid; missing quote blocks with amount preserved; refresh recalculates',
    (tester) async {
      final repository = TestLiveOrderRepository()
        ..context = liveContext(ask: '80001', bid: '79999');
      final container = await open(tester, repository);
      await field(tester, 'live-order-quantity', '160');
      await market(tester);
      await preview(tester, '0.001');
      await visible(tester, 'live-order-direction');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('live-order-direction')),
          matching: find.text(messages(tester).short),
        ),
      );
      await tester.pumpAndSettle();
      await preview(tester, '0.002');
      repository.context = liveContext(ask: '80001');
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-order-review');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('main-order-capacity-sell')),
          matching: find.text(messages(tester).liveAmountReferenceUnavailable),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('main-order-review-sell'))).onPressed,
        null,
      );
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('main-order-review-buy'))).onPressed,
        isNotNull,
      );
      await visible(tester, 'live-order-quantity');
      expect(input(tester, 'live-order-quantity'), '160');
      repository.context = liveContext(bid: '80001', ask: '80002');
      await tap(tester, 'live-order-read');
      await preview(tester, '0.001');
      expect(repository.submits, 0);
      await dispose(tester, container);
    },
  );
  testWidgets(
    'confirmation cancellation preserves amount; unknown disables units and rechecks exact base',
    (tester) async {
      final repository = TestLiveOrderRepository()
        ..context = liveContext(ask: '80000', bid: '79999')
        ..result = const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
      final container = await open(tester, repository);
      await field(tester, 'live-order-quantity', '80.000');
      await market(tester);
      await tap(tester, 'live-order-review');
      final dialog = find.byType(OrderConfirmationDialog);
      expect(find.descendant(of: dialog, matching: find.text('0.001 BTC')), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('80 USDT')), findsWidgets);
      await cancel(tester);
      expect(repository.submits, 0);
      await tap(tester, 'live-order-review');
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      await dismissOrderConfirmation(tester);
      final original = repository.lastIntent!;
      expect(original.parameters['quantity'], '0.001');
      expect(original.parameters['quantityUnit'], null);
      await visible(tester, 'live-order-unit-base');
      expect(
        tester.widget<ChoiceChip>(find.byKey(const Key('live-order-unit-base'))).onSelected,
        null,
      );
      expect(input(tester, 'live-order-quantity'), '80.000');
      repository.context = liveContext(ask: '40000');
      repository.result = LiveOrderResult(
        orderId: '12345',
        status: 'NEW',
        executedQuantity: Decimal.zero,
      );
      await tap(tester, 'live-order-recheck');
      expect(repository.submits, 1);
      expect(repository.checks, 1);
      expect(repository.lastIntent!.clientOrderId, original.clientOrderId);
      expect(repository.lastIntent!.draft.quantity, '0.001');
      await dispose(tester, container);
    },
  );
  for (final edit in [null, '', '79000']) {
    testWidgets('first later valid Last seeds once; user edit retained: $edit', (tester) async {
      final repository = TestLiveOrderRepository()..context = liveContext(lastPrice: null);
      final container = await open(tester, repository);
      await visible(tester, 'live-order-price');
      expect(input(tester, 'live-order-price'), '');
      if (edit != null) {
        await field(tester, 'live-order-price', '79000');
        await field(tester, 'live-order-price', edit);
      }
      repository.context = liveContext(lastPrice: '81000');
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-order-price');
      expect(input(tester, 'live-order-price'), edit ?? '81000');
      repository.context = liveContext(lastPrice: '82000');
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-order-price');
      expect(input(tester, 'live-order-price'), edit ?? '81000');
      await dispose(tester, container);
    });
  }
  testWidgets('close defaults base; choosing fraction exits quote and preserves dormant quote', (
    tester,
  ) async {
    final repository = TestLiveOrderRepository()..context = liveCloseContext();
    final container = await open(tester, repository, closingSide: 'BOTH');
    await visible(tester, 'live-order-unit-base');
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('live-order-unit-base'))).selected, true);
    await tap(tester, 'live-order-unit-quote');
    await field(tester, 'live-order-quantity', '80');
    await tap(tester, 'live-close-fraction-50');
    await visible(tester, 'live-order-unit-base');
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('live-order-unit-base'))).selected, true);
    expect(input(tester, 'live-order-quantity'), '0.005');
    await tap(tester, 'live-order-unit-quote');
    expect(input(tester, 'live-order-quantity'), '80');
    await dispose(tester, container);
  });
  testWidgets('quote amount drives attached PnL conversion and full protected base quantity', (
    tester,
  ) async {
    final repository = TestLiveOrderRepository()..context = liveContext(ask: '80000', bid: '80000');
    final container = await open(tester, repository);
    await field(tester, 'live-order-price', '80000');
    await field(tester, 'live-order-quantity', '160');
    await tap(tester, 'live-order-attached');
    await tap(tester, 'attached-tp-enabled');
    await field(tester, 'attached-tp-price', '+2');
    await tap(tester, 'live-order-review');
    expect(
      find.descendant(
        of: find.byType(OrderConfirmationDialog),
        matching: find.textContaining('≥ 81000 USDT'),
      ),
      findsOneWidget,
    );
    await cancel(tester);
    await field(tester, 'live-order-quantity', '320');
    await tap(tester, 'live-order-review');
    expect(
      find.descendant(
        of: find.byType(OrderConfirmationDialog),
        matching: find.textContaining('≥ 80500 USDT'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    await dismissOrderConfirmation(tester);
    expect(repository.lastIntent!.draft.quantity, '0.004');
    expect(repository.lastIntent!.draft.attachment!.takeProfit!.price, '80500');
    await dispose(tester, container);
  });
  testWidgets(
    'new account snapshot while reviewing invalidates old confirmation without resigning size',
    (tester) async {
      final repository = TestLiveOrderRepository()..context = liveContext(ask: '80000');
      final container = await open(tester, repository);
      await field(tester, 'live-order-quantity', '160');
      await market(tester);
      await tap(tester, 'live-order-review');
      repository.context = liveContext(ask: '80001');
      await container.read(liveOrderProvider.notifier).load('BTCUSDT');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(OrderConfirmationDialog), matching: find.text('0.002 BTC')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      await dismissOrderConfirmation(tester);
      expect(repository.submits, 0);
      await preview(tester, '0.001');
      await dispose(tester, container);
    },
  );
  testWidgets('refused signing preserves quote, limit, unit and editable retry', (tester) async {
    final repository = TestLiveOrderRepository()
      ..failure = const AccountReadFailure('authWalletRejected');
    final container = await open(tester, repository);
    await field(tester, 'live-order-quantity', '160.000');
    await field(tester, 'live-order-price', '80000');
    await tap(tester, 'live-order-review');
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    await dismissOrderConfirmation(tester);
    expect(repository.submits, 1);
    await visible(tester, 'live-order-unit-quote');
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('live-order-unit-quote'))).selected,
      true,
    );
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('live-order-unit-quote'))).onSelected,
      isNotNull,
    );
    expect(input(tester, 'live-order-quantity'), '160.000');
    await visible(tester, 'live-order-price');
    expect(input(tester, 'live-order-price'), '80000');
    await dispose(tester, container);
  });
  testWidgets('clearing a seeded Last limit remains empty after refresh', (tester) async {
    final repository = TestLiveOrderRepository();
    final container = await open(tester, repository);
    await field(tester, 'live-order-price', '');
    repository.context = liveContext(lastPrice: '81000');
    await tap(tester, 'live-order-read');
    await visible(tester, 'live-order-price');
    expect(input(tester, 'live-order-price'), '');
    await dispose(tester, container);
  });
  testWidgets('invalid quote amount stays visible and never enables review', (tester) async {
    final repository = TestLiveOrderRepository();
    final container = await open(tester, repository);
    for (final value in ['1e3', '-80', '0.001']) {
      await field(tester, 'live-order-quantity', value);
      await visible(tester, 'live-order-review');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      await visible(tester, 'live-order-quantity');
      expect(input(tester, 'live-order-quantity'), value);
    }
    expect(repository.submits, 0);
    await dispose(tester, container);
  });
  for (final locale in ['en', 'zh']) {
    testWidgets('quote preview and review narrow enlarged, landscape and tablet $locale', (
      tester,
    ) async {
      final repository = TestLiveOrderRepository()
        ..context = liveContext(ask: '80000', bid: '79999');
      final container = await open(tester, repository, locale: locale, width: 320, scale: 1.5);
      await field(tester, 'live-order-quantity', '160');
      await field(tester, 'live-order-price', '80000');
      for (final size in [const Size(320, 844), const Size(844, 390), const Size(768, 1024)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await preview(tester, '0.002');
        await tap(tester, 'live-order-review');
        expect(find.byType(OrderConfirmationDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(OrderConfirmationDialog),
            matching: find.text('0.002 BTC'),
          ),
          findsOneWidget,
        );
        await cancel(tester);
        expect(tester.takeException(), null);
      }
      await dispose(tester, container);
    });
  }
}
