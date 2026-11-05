import '../../support/order_mode_widget.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/presentation/live_order_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
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

  Future<void> field(WidgetTester tester, String key, String value) async {
    if (key == 'live-order-quantity') await selectLiveBase(tester);
    await visible(tester, key);
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(LiveOrderScreen)));
  Future<void> open(WidgetTester tester, ProviderContainer container, {String? side}) async {
    await launch(tester, container);
    final context = tester.element(find.byType(Navigator).first);
    if (side == null) {
      openLiveOrder(context, 'BTCUSDT');
    } else {
      openLiveClose(context, 'BTCUSDT', side);
    }
    await tester.pumpAndSettle();
    await tap(tester, 'live-order-read');
    await tap(tester, 'live-order-trailing');
  }

  Future<void> dispose(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  for (final language in ['en', 'zh']) {
    for (final explicit in [false, true]) {
      testWidgets(
        'trailing review, preserved fields and unknown recovery, 320/large/landscape: $language $explicit',
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
          expect(find.byKey(const Key('live-order-conditional')), findsNothing);
          expect(find.byKey(const Key('live-order-price')), findsNothing);
          await field(tester, 'live-trailing-rate', '1.25');
          await field(tester, 'live-order-quantity', '0.001');
          await tap(tester, 'live-trailing-basis');
          await tester.tap(find.text(l10n(tester).openOrdersMarkPrice).last);
          await tester.pumpAndSettle();
          if (explicit) await field(tester, 'live-trailing-activation', '79000');
          expect(find.byKey(const Key('live-order-type')), findsNothing);
          await tap(tester, 'live-order-review');
          final messages = l10n(tester), dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget);
          expect(find.descendant(of: dialog, matching: find.text('1.25%')), findsOneWidget);
          expect(
            find.descendant(of: dialog, matching: find.text(messages.openOrdersTrailingStop)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: dialog, matching: find.text(messages.liveTrailingBuy)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: dialog, matching: find.text(messages.liveTrailingDefault)),
            explicit ? findsNothing : findsOneWidget,
          );
          expect(tester.takeException(), null);
          tester.view.physicalSize = const Size(844, 390);
          await tester.pumpAndSettle();
          expect(tester.takeException(), null);
          await tester.tap(find.text(messages.cancel));
          await tester.pumpAndSettle();
          await tap(tester, 'live-order-read');
          await visible(tester, 'live-trailing-rate');
          expect(text(tester, 'live-trailing-rate'), '1.25');
          await visible(tester, 'live-trailing-activation');
          expect(text(tester, 'live-trailing-activation'), explicit ? '79000' : '');
          expect(repository.submits, 0);
          await tap(tester, 'live-order-review');
          await tester.tap(find.byKey(const Key('live-order-confirm')));
          await tester.pumpAndSettle();
          expect(repository.lastIntent!.draft.trailing!.callbackRate, '1.25');
          expect(repository.lastIntent!.parameters['activationPrice'], explicit ? '79000' : null);
          for (final key in [
            'price',
            'stopPrice',
            'timeInForce',
            'priceProtect',
            'closePosition',
          ]) {
            expect(repository.lastIntent!.parameters.containsKey(key), false);
          }
          final id = repository.lastIntent!.clientOrderId;
          await expectOrderModeLocked(tester);
          await visible(tester, 'live-trailing-rate');
          expect(
            tester.widget<TextField>(find.byKey(const Key('live-trailing-rate'))).readOnly,
            true,
          );
          repository.result = LiveOrderResult(
            orderId: '12345',
            status: 'FILLED',
            executedQuantity: Decimal.parse('0.001'),
          );
          await tap(tester, 'live-order-recheck');
          expect(repository.lastIntent!.clientOrderId, id);
          expect(repository.lastIntent!.draft.trailing!.callbackRate, '1.25');
          expect(repository.submits, 1);
          expect(repository.checks, 1);
          expect(identity.wallets, 0);
          expect(tester.takeException(), null);
          await dispose(tester, container);
        },
      );
    }
    for (final hedge in [false, true]) {
      for (final short in [false, true]) {
        testWidgets(
          'trailing close keeps side and displays direction rules: $language $hedge $short',
          (tester) async {
            final identity = TestIdentityRepository()..restored = signingIdentity;
            final repository = TestLiveOrderRepository()
              ..context = liveCloseContext(short: short, hedge: hedge);
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
            await open(tester, container, side: hedge ? (short ? 'SHORT' : 'LONG') : 'BOTH');
            await field(tester, 'live-trailing-rate', '0.1');
            await tap(tester, 'live-close-fraction-50');
            await tap(tester, 'live-order-review');
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(
              find.text(short ? l10n(tester).liveTrailingBuy : l10n(tester).liveTrailingSell),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const Key('live-order-confirm')));
            await tester.pumpAndSettle();
            expect(repository.lastIntent!.parameters['side'], short ? 'BUY' : 'SELL');
            expect(
              repository.lastIntent!.parameters['positionSide'],
              hedge ? (short ? 'SHORT' : 'LONG') : 'BOTH',
            );
            expect(repository.lastIntent!.parameters['quantity'], '0.005');
            expect(repository.lastIntent!.parameters['reduceOnly'], hedge ? null : 'true');
            expect(
              repository.lastIntent!.context.estimatedClosePnl(repository.lastIntent!.draft),
              null,
            );
            expect(tester.takeException(), null);
            await dispose(tester, container);
          },
        );
      }
    }
  }
  testWidgets(
    'trailing fields survive capability loss and return; disabling omits dormant fields',
    (tester) async {
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
      await field(tester, 'live-trailing-rate', '5.1');
      await field(tester, 'live-order-quantity', '0.001');
      await visible(tester, 'live-order-review');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      await field(tester, 'live-trailing-rate', '1');
      await field(tester, 'live-trailing-activation', '79000');
      repository.context = liveContext(orderTypes: {'LIMIT', 'MARKET'});
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-order-review');
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('live-order-review'))).onPressed,
        null,
      );
      repository.context = liveContext();
      await tap(tester, 'live-order-read');
      await visible(tester, 'live-trailing-rate');
      expect(text(tester, 'live-trailing-rate'), '1');
      await tap(tester, 'live-order-trailing');
      expect(find.byKey(const Key('live-trailing-activation')), findsNothing);
      await tap(tester, 'live-order-review');
      await tester.tap(find.byKey(const Key('live-order-confirm')));
      await tester.pumpAndSettle();
      expect(repository.lastIntent!.parameters['type'], 'MARKET');
      for (final key in ['activationPrice', 'callbackRate', 'workingType', 'stopPrice']) {
        expect(repository.lastIntent!.parameters.containsKey(key), false);
      }
      expect(tester.takeException(), null);
      await dispose(tester, container);
    },
  );
  testWidgets('fixed-condition inputs are retained but never sent by trailing mode', (
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
    await tap(tester, 'live-order-trailing');
    await tap(tester, 'live-order-conditional');
    await field(tester, 'live-order-trigger-price', '81000');
    await tap(tester, 'live-order-trigger-protect');
    await tap(tester, 'live-order-trailing');
    await field(tester, 'live-trailing-rate', '1');
    await field(tester, 'live-order-quantity', '0.001');
    await tap(tester, 'live-order-review');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('live-order-confirm')));
    await tester.pumpAndSettle();
    expect(repository.lastIntent!.draft.trigger, null);
    expect(repository.lastIntent!.parameters['type'], 'TRAILING_STOP_MARKET');
    expect(repository.lastIntent!.parameters.containsKey('stopPrice'), false);
    expect(repository.lastIntent!.parameters.containsKey('priceProtect'), false);
    expect(tester.takeException(), null);
    await dispose(tester, container);
  });
}
