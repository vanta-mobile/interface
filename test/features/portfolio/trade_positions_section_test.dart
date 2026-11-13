import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/application/trading_agent_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/aster_open_orders_mapper.dart';
import 'package:vanta/features/portfolio/application/live_order_provider.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/live_order_time_in_force.dart';
import 'package:vanta/features/portfolio/domain/live_order_trigger.dart';
import 'package:vanta/features/portfolio/domain/order_cancellation.dart';
import 'package:vanta/features/portfolio/presentation/position_tpsl_screen.dart';
import 'package:vanta/features/portfolio/presentation/trade_position_card.dart';

import '../../support/aster_account.dart';
import '../../support/aster_open_orders.dart';
import '../../support/identity_repository.dart';
import '../../support/live_order.dart';
import '../../support/order_cancellation.dart';
import '../../support/position_risk.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';

final _units = mapAsterContractUnits(contractPayload());
final _received = DateTime.utc(2026, 11, 2, 12, 30);

Future<TradingAgentStore> _activeStore() async {
  final store = MemoryTradingAgentStorage().store(DateTime.now);
  final agent = await store.prepare(
    signingIdentity.id,
    accountAddress,
    DateTime.now().add(const Duration(days: 30)),
  );
  await store.setStatus(agent, TradingAgentStatus.unknown);
  await store.setStatus(agent, TradingAgentStatus.active);
  return store;
}

Future<TestIdentityRepository> _launch(
  WidgetTester tester, {
  TestLiveOrderRepository? live,
  TestOrderCancellationRepository? cancellation,
  bool exits = true,
  double width = 390,
}) async {
  final identity = TestIdentityRepository()..restored = signingIdentity;
  addTearDown(identity.dispose);
  // Its funds read supplies the single-asset mode the cross ratio needs.
  live ??= TestLiveOrderRepository()..context = liveCloseContext();
  final risk = TestPositionRiskRepository()
    ..result = mapPositionRisk(
      [
        positionRiskRow()
          ..['positionAmt'] = '0.01'
          ..['entryPrice'] = '79000'
          ..['markPrice'] = '77250'
          ..['liquidationPrice'] = '72000'
          ..['marginType'] = 'cross'
          ..['unRealizedProfit'] = '10'
          ..['notional'] = '800'
          ..['leverage'] = '10',
      ],
      address: accountAddress,
      receivedAt: _received,
      units: _units,
    );
  final account = TestAsterAccountRepository()
    ..result = mapAsterAccount(
      {
        ...accountPayload(),
        'assets': [
          {
            'asset': 'USDT',
            'walletBalance': '120',
            'crossWalletBalance': '120',
            'crossUnPnl': '5',
            'marginAvailable': true,
          },
        ],
        'positions': [
          {
            'symbol': 'BTCUSDT',
            'positionSide': 'BOTH',
            'positionAmt': '0.01',
            'entryPrice': '79000',
            'maintMargin': '2.5',
            'isolated': false,
          },
        ],
      },
      address: accountAddress,
      receivedAt: _received,
      units: _units,
    );
  final orders = TestOpenOrdersRepository()
    ..result = mapAsterOpenOrders(
      [
        if (exits) ...[
          openOrder(id: 1, type: 'TAKE_PROFIT_MARKET', side: 'SELL', origQty: '0', price: '0')
            ..addAll({'stopPrice': '90000', 'closePosition': true}),
          openOrder(id: 2, type: 'STOP_MARKET', side: 'SELL', origQty: '0.005', price: '0')
            ..addAll({'stopPrice': '75000', 'reduceOnly': true}),
        ],
      ],
      address: accountAddress,
      receivedAt: _received,
      units: _units,
    );
  final container = setup(
    tester,
    width: width,
    identityRepository: identity,
    positionRiskRepository: risk,
    asterAccountRepository: account,
    openOrdersRepository: orders,
    orderCancellationRepository: cancellation,
    liveOrderRepository: live,
    liveClock: () => liveOrderClock,
    tradingAgentStore: await tester.runAsync(_activeStore),
    language: const Locale('en'),
  );
  await launch(tester, container);
  for (var i = 0; i < 50 && container.read(tradingAgentProvider).isLoading; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await container.read(liveOrderProvider.notifier).load('BTCUSDT');
  final tab = find.byKey(const Key('futures-account-tab-1'));
  // Silent reads can still change the page height; settle before scrolling.
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    tab,
    250,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('futures-workspace')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    tab,
    250,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('futures-workspace')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
  return identity;
}

/// Logging out cancels the snapshots' expiry timers before the test ends.
Future<void> _logout(WidgetTester tester, TestIdentityRepository identity) async {
  identity.events.add(null);
  await tester.pumpAndSettle();
  // Lets the toast and any throttled automatic read timer run out.
  await tester.pump(const Duration(seconds: 6));
}

const _card = Key('trade-position-BTCUSDT-BOTH');

/// TP/SL opens the existing-orders list; Add TP/SL opens the form.
Future<void> _openTpSlForm(WidgetTester tester) async {
  final action = find.byKey(const Key('trade-position-action-0-BTCUSDT-BOTH'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byType(PositionTpSlListScreen), findsOneWidget);
  await tester.tap(find.byKey(const Key('position-tpsl-add')));
  await tester.pumpAndSettle();
  expect(find.byType(PositionTpSlScreen), findsOneWidget);
}

void main() {
  testWidgets('the Positions tab reads silently and shows the designed card', (tester) async {
    final identity = await _launch(tester);
    expect(find.text('Positions (1)'), findsOneWidget);
    expect(find.byKey(_card), findsOneWidget);
    Finder inCard(Finder finder) => find.descendant(of: find.byKey(_card), matching: finder);
    // Single-asset cross: 2.5 maintenance / (120 + 5) cross equity.
    expect(inCard(find.text('2.00%')), findsOneWidget);
    // 2% of the 270° arc turns the left-pointing needle back by 39.6°.
    final needle = tester.widget<Transform>(find.byKey(const Key('trade-position-margin-needle')));
    expect(
      needle.transform.getRotation().entry(1, 0),
      moreOrLessEquals(math.sin((2 * 2.7 - 45) * math.pi / 180)),
    );
    expect(inCard(find.textContaining('+10', findRichText: true)), findsWidgets);
    expect(inCard(find.text(r'$79,000')), findsOneWidget);
    expect(inCard(find.text(r'$72,000')), findsOneWidget);
    expect(inCard(find.textContaining('90,000', findRichText: true)), findsOneWidget);
    expect(inCard(find.text('Partial TP/SL (1)')), findsOneWidget);
    expect(inCard(find.textContaining('75,000', findRichText: true)), findsOneWidget);
    // Mark 77,250 has covered a quarter of entry 79,000 → liquidation 72,000.
    final bar = tester.getSize(find.byKey(const Key('trade-position-liquidation-bar')));
    final fill = tester.getSize(find.byKey(const Key('trade-position-liquidation-fill')));
    expect(bar.height, 6);
    expect(fill.width, moreOrLessEquals(bar.width / 4));
    // Cross positions have no margin adjustment entry.
    expect(find.byKey(const Key('trade-position-margin-BTCUSDT-BOTH')), findsNothing);
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('TP/SL places an entire-close take profit and returns', (tester) async {
    final live = TestLiveOrderRepository()..context = liveCloseContext();
    final identity = await _launch(tester, live: live);
    await _openTpSlForm(tester);

    await tester.tap(find.byKey(const ValueKey('position-tab-PositionTpSlScope.entire')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('position-tpsl-amount')), findsNothing);
    expect(find.byKey(const Key('position-tpsl-tp-limit')), findsNothing);
    await tester.enterText(find.byKey(const Key('position-tpsl-tp-price')), '82000');
    await tester.pumpAndSettle();
    // 0.01 BTC from 79,000 to 82,000.
    expect(find.widgetWithText(TextField, '+30.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('position-tpsl-confirm')));
    await tester.pumpAndSettle();
    expect(live.submits, 1);
    final draft = live.lastIntent!.draft;
    expect(draft.entireClose, isTrue);
    expect(draft.buy, isFalse);
    expect(draft.trigger?.kind, LiveOrderTriggerKind.takeProfit);
    expect(draft.trigger?.price, '82000');
    expect(find.byType(PositionTpSlScreen), findsNothing);
    // The form returns to the existing-orders list.
    expect(find.byType(PositionTpSlListScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('position-tpsl-back')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(TradePositionCard),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('futures-workspace')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byType(TradePositionCard), findsOneWidget);
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('TP/SL amount slider follows the trade-workspace slider rules', (tester) async {
    final live = TestLiveOrderRepository()..context = liveCloseContext();
    final identity = await _launch(tester, live: live);
    await _openTpSlForm(tester);
    final slider = find.byKey(const Key('position-tpsl-percent'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    String amount() =>
        tester.widget<TextField>(find.byKey(const Key('position-tpsl-amount'))).controller!.text;
    final box = tester.getRect(slider);
    // Between stops: a whole-unit amount, not a snapped percentage.
    await tester.tapAt(Offset(box.left + 6 + (box.width - 12) * 0.3, box.center.dy));
    await tester.pumpAndSettle();
    final partial = amount();
    expect(partial, isNot(contains('.')));
    expect(partial, isNotEmpty);
    // Dragging to the end selects the whole position.
    await tester.dragFrom(Offset(box.left + 6, box.center.dy), Offset(box.width + 20, 0));
    await tester.pumpAndSettle();
    final whole = amount();
    expect(Decimal.parse(whole) > Decimal.parse(partial), isTrue);
    expect(tester.getSemantics(slider).value, '100%');
    // A typed amount moves the thumb to its share of the position value.
    await tester.enterText(
      find.byKey(const Key('position-tpsl-amount')),
      '${(Decimal.parse(whole) / Decimal.fromInt(2)).toDecimal(scaleOnInfinitePrecision: 8)}',
    );
    await tester.pumpAndSettle();
    expect(tester.getSemantics(slider).value, '50%');
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('TP/SL keeps input and sends nothing without a trigger or amount', (tester) async {
    final live = TestLiveOrderRepository()..context = liveCloseContext();
    final identity = await _launch(tester, live: live);
    await _openTpSlForm(tester);
    await tester.tap(find.byKey(const Key('position-tpsl-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a take-profit or stop-loss trigger price.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('position-tpsl-sl-price')), '76000');
    await tester.tap(find.byKey(const Key('position-tpsl-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount no larger than the position.'), findsOneWidget);
    expect(find.widgetWithText(TextField, '76000'), findsOneWidget);
    expect(live.submits, 0);

    await tester.tap(find.byKey(const Key('position-tpsl-sl-basis')));
    await tester.pumpAndSettle();
    expect(find.text('Select Trigger Type'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trade-option-LiveOrderTriggerBasis.mark')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('position-tpsl-sl-basis')),
        matching: find.text('Mark'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('TP/SL lists the existing orders of each close scope', (tester) async {
    final identity = await _launch(tester);
    final action = find.byKey(const Key('trade-position-action-0-BTCUSDT-BOTH'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    final list = find.byType(PositionTpSlListScreen);
    Finder inList(Finder finder) => find.descendant(of: list, matching: finder);
    // Partial close: the reduce-only stop loss of 0.005 BTC.
    expect(find.byKey(const Key('position-tpsl-group-2')), findsOneWidget);
    expect(find.byKey(const Key('position-tpsl-group-1')), findsNothing);
    expect(inList(find.text('SL')), findsOneWidget);
    expect(inList(find.text('TP')), findsNothing);
    expect(inList(find.textContaining('75,000')), findsOneWidget);
    // 0.005 × (75,000 − 79,000).
    expect(inList(find.textContaining('-20', findRichText: true)), findsOneWidget);
    expect(inList(find.text('Market')), findsOneWidget);
    // Entire close: the closePosition take profit.
    await tester.tap(find.byKey(const ValueKey('position-tab-PositionTpSlScope.entire')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('position-tpsl-group-1')), findsOneWidget);
    expect(find.byKey(const Key('position-tpsl-group-2')), findsNothing);
    expect(inList(find.text('TP')), findsOneWidget);
    expect(inList(find.textContaining('90,000')), findsOneWidget);
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('TP/SL Cancel cancels the group orders after confirmation', (tester) async {
    final cancellation = TestOrderCancellationRepository()
      ..result = const OrderCancellationResult(
        resolution: OrderResolution(symbol: 'BTCUSDT', orderId: '2', status: 'CANCELED'),
      );
    final identity = await _launch(tester, cancellation: cancellation);
    final action = find.byKey(const Key('trade-position-action-0-BTCUSDT-BOTH'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('position-tpsl-cancel-2')));
    await tester.pumpAndSettle();
    expect(cancellation.cancels, 0);
    await tester.tap(find.byKey(const Key('confirm-order-cancel')));
    await tester.pumpAndSettle();
    expect(cancellation.cancels, 1);
    expect(find.byKey(const Key('position-tpsl-group-2')), findsNothing);
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('TP/SL opens the form directly without existing orders', (tester) async {
    final identity = await _launch(tester, exits: false);
    final action = find.byKey(const Key('trade-position-action-0-BTCUSDT-BOTH'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(PositionTpSlListScreen), findsNothing);
    expect(find.byType(PositionTpSlScreen), findsOneWidget);
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  /// Base unit, then the middle of the slider: half the 0.01 BTC position on
  /// the 0.001 step. The quote unit would floor a whole-USDT half instead.
  Future<void> closeHalfInBase(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('position-close-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trade-option-OrderSizeUnit.base')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('position-close-percent')));
    await tester.pumpAndSettle();
  }

  Future<void> openClose(WidgetTester tester, int action) async {
    final button = find.byKey(Key('trade-position-action-$action-BTCUSDT-BOTH'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('close amount slider follows the trade-workspace slider rules', (tester) async {
    final live = TestLiveOrderRepository()..context = liveCloseContext();
    final identity = await _launch(tester, live: live);
    await openClose(tester, 1);
    final slider = find.byKey(const Key('position-close-percent'));
    String amount() =>
        tester.widget<TextField>(find.byKey(const Key('position-close-amount'))).controller!.text;
    final box = tester.getRect(slider);
    // Between stops in USDT: a whole-unit amount, not a snapped percentage.
    await tester.tapAt(Offset(box.left + 6 + (box.width - 12) * 0.3, box.center.dy));
    await tester.pumpAndSettle();
    final partial = amount();
    expect(partial, isNotEmpty);
    expect(partial, isNot(contains('.')));
    // Only the end of the track is the whole position.
    await tester.dragFrom(Offset(box.left + 6, box.center.dy), Offset(box.width + 20, 0));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(slider).value, '100%');
    final whole = Decimal.parse(amount());
    expect(whole > Decimal.parse(partial), isTrue);
    // A typed amount moves the thumb to its share of the position value.
    await tester.enterText(
      find.byKey(const Key('position-close-amount')),
      '${(whole / Decimal.fromInt(4)).toDecimal(scaleOnInfinitePrecision: 8)}',
    );
    await tester.pumpAndSettle();
    expect(tester.getSemantics(slider).value, '25%');
    expect(live.submits, 0);
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('Market closes half the position as a reduce-only market order', (tester) async {
    final live = TestLiveOrderRepository()..context = liveCloseContext();
    final identity = await _launch(tester, live: live);
    await openClose(tester, 1);
    expect(find.text('Close Position'), findsOneWidget);
    await closeHalfInBase(tester);
    expect(
      tester.widget<TextField>(find.byKey(const Key('position-close-amount'))).controller!.text,
      '0.005',
    );
    // Closing a long at the bid: 0.005 × (79,999 − 79,000).
    expect(find.text('+4.995 USDT'), findsOneWidget);
    await tester.tap(find.byKey(const Key('position-close-confirm')));
    await tester.pumpAndSettle();
    final draft = live.lastIntent!.draft;
    expect(live.submits, 1);
    expect(
      (draft.market, draft.buy, draft.closingSide, draft.quantity),
      (true, false, 'BOTH', '0.005'),
    );
    expect(find.text('Close Position'), findsNothing);
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('Limit close sends a hidden limit order and keeps input on errors', (tester) async {
    final live = TestLiveOrderRepository()..context = liveCloseContext();
    final identity = await _launch(tester, live: live);
    await openClose(tester, 2);
    expect(find.text('Hidden Order'), findsOneWidget);
    await closeHalfInBase(tester);
    await tester.tap(find.byKey(const Key('position-close-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a limit price or choose BBO.'), findsOneWidget);
    expect(live.submits, 0);

    await tester.enterText(find.byKey(const Key('position-limit-price')), '80500');
    await tester.tap(find.byKey(const Key('position-close-hidden')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('position-close-confirm')));
    await tester.pumpAndSettle();
    final draft = live.lastIntent!.draft;
    expect(live.submits, 1);
    expect((draft.market, draft.price, draft.quantity), (false, '80500', '0.005'));
    expect(draft.timeInForce, LiveOrderTimeInForce.hidden);
    expect(find.text('Close Position'), findsNothing);
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });

  testWidgets('Limit close unit and price type work before the order context loads', (
    tester,
  ) async {
    final live = TestLiveOrderRepository()..context = liveCloseContext();
    final identity = await _launch(tester, live: live);
    live.readGate = Completer<void>();
    await openClose(tester, 2);
    expect(live.readGate!.isCompleted, isFalse);

    await tester.tap(find.byKey(const Key('position-close-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trade-option-OrderSizeUnit.base')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(const Key('position-close-unit')), matching: find.text('BTC')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('position-close-price-type')));
    await tester.pumpAndSettle();
    expect(find.text('Select Price Type'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trade-option-LiveOrderTriggerBasis.mark')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('position-limit-price'));
    expect(tester.widget<TextField>(field).controller!.text, '77250');
    expect(
      find.descendant(
        of: find.byKey(const Key('position-close-price-type')),
        matching: find.text('Mark'),
      ),
      findsOneWidget,
    );
    live.readGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await _logout(tester, identity);
  });
}
