import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/application/order_explorer_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/aster_open_orders.dart';
import 'package:vanta/features/portfolio/presentation/aster_open_order_card.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

const _units = AsterContractUnits(base: 'AAPL', quote: 'USDT', margin: 'USDT');

AsterOpenOrder _order({
  String type = 'LIMIT',
  String side = 'BUY',
  String price = '290',
  String? stop,
  String? workingType,
  bool reduceOnly = false,
  String? hash,
}) => AsterOpenOrder(
  symbol: 'AAPLUSDT',
  orderId: '39842202',
  side: side,
  positionSide: 'BOTH',
  type: type,
  status: 'NEW',
  time: DateTime.utc(2026, 11, 4, 12, 19, 20),
  origQty: Decimal.parse('0.03'),
  executedQty: Decimal.zero,
  price: Decimal.parse(price),
  stopPrice: stop == null ? null : Decimal.parse(stop),
  workingType: workingType,
  reduceOnly: reduceOnly,
  units: _units,
  transactionHash: hash,
);

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  Locale locale = const Locale('en'),
  List<Uri>? launched,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      orderExplorerLauncherProvider.overrideWithValue((uri) async {
        launched?.add(uri);
        return true;
      }),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  ),
);

void main() {
  testWidgets('limit order card follows the open-order design', (tester) async {
    var cancels = 0;
    await _pump(
      tester,
      AsterOpenOrderCard(order: _order(), leverage: 20, onCancel: () => cancels++),
    );
    expect(find.text('Buy'), findsOneWidget);
    expect(find.text('Limit'), findsOneWidget);
    expect(find.text('20x'), findsOneWidget);
    expect(find.text('Filled / Total amount (AAPL)'), findsOneWidget);
    expect(find.text('0 / 0.03'), findsOneWidget);
    expect(find.text('290'), findsOneWidget);
    expect(find.text('8.70 USDT'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
    expect(find.text('Reduce only'), findsNothing);
    expect(find.byKey(const Key('open-order-chart-AAPLUSDT-39842202')), findsNothing);
    await tester.tap(find.byKey(const Key('cancel-order-AAPLUSDT-39842202')));
    expect(cancels, 1);
  });

  testWidgets('conditional orders show trigger condition and reduce-only', (tester) async {
    var charts = 0;
    await _pump(
      tester,
      AsterOpenOrderCard(
        order: _order(
          type: 'TAKE_PROFIT_MARKET',
          side: 'SELL',
          price: '0',
          stop: '426.64',
          workingType: 'CONTRACT_PRICE',
          reduceOnly: true,
        ),
        onViewChart: () => charts++,
      ),
    );
    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Last price >= 426.64'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-order-chart-AAPLUSDT-39842202')));
    expect(charts, 1);
  });

  testWidgets('stop buy triggers on rising mark price', (tester) async {
    await _pump(
      tester,
      AsterOpenOrderCard(
        order: _order(type: 'STOP_MARKET', price: '0', stop: '47.4', workingType: 'MARK_PRICE'),
      ),
    );
    expect(find.text('Mark price >= 47.40'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('tapping a card opens copyable order details', (tester) async {
    await _pump(tester, AsterOpenOrderCard(order: _order()), locale: const Locale('zh'));
    await tester.tap(find.byKey(const Key('open-order-AAPLUSDT-39842202')));
    await tester.pumpAndSettle();
    expect(find.text('订单详情'), findsOneWidget);
    final id = find.descendant(
      of: find.byKey(const Key('open-order-details')),
      matching: find.byType(SelectableText),
    );
    expect(tester.widgetList<SelectableText>(id).map((w) => w.data), contains('39842202'));
    expect(tester.takeException(), null);
  });

  testWidgets('explorer opens the placement transaction and is disabled without one', (
    tester,
  ) async {
    final launched = <Uri>[];
    const hash = '0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
    await _pump(
      tester,
      AsterOpenOrderCard(order: _order(hash: hash)),
      launched: launched,
    );
    final explorer = find.byKey(const Key('open-order-explorer-AAPLUSDT-39842202'));
    expect(find.text('View Explorer'), findsOneWidget);
    await tester.tap(explorer);
    expect(launched, [Uri.parse('https://www.asterdex.com/en/explorer/tx/$hash')]);
    await _pump(tester, AsterOpenOrderCard(order: _order()), launched: launched);
    expect(tester.widget<OpenOrderChipButton>(explorer).onPressed, isNull);
  });

  testWidgets('entry shows TP/SL and exit legs show their linked strategy', (tester) async {
    await _pump(
      tester,
      AsterOpenOrderCard(
        order: _order(),
        strategy: OpenOrderStrategy(
          strategyId: '77',
          sequence: 1,
          takeProfit: Decimal.parse('372.86'),
          stopLoss: Decimal.parse('41.43'),
        ),
      ),
    );
    expect(find.text('TP/SL'), findsOneWidget);
    expect(find.text('372.86 / 41.43', findRichText: true), findsOneWidget);
    expect(find.text('Linked order:'), findsNothing);
    await _pump(
      tester,
      AsterOpenOrderCard(
        order: _order(type: 'TAKE_PROFIT_MARKET', side: 'SELL', price: '0', stop: '372.86'),
        strategy: const OpenOrderStrategy(strategyId: '77', sequence: 2),
      ),
    );
    expect(find.text('TP/SL'), findsNothing);
    expect(find.text('Linked order:'), findsOneWidget);
    expect(find.text('77'), findsOneWidget);
    await _pump(tester, AsterOpenOrderCard(order: _order()));
    expect(find.text('TP/SL'), findsNothing);
  });
}
