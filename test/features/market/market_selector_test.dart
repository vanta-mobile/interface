import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/market_quote.dart';
import 'package:vanta/features/market/domain/market_quotes.dart';
import 'package:vanta/features/market/domain/market_precision.dart';
import 'package:vanta/features/market/domain/market_descriptor.dart';
import 'package:vanta/features/market/application/market_selection_provider.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/market_list_row.dart';

import '../../support/trade_fixture.dart';

void main() {
  testWidgets(
    'categories, multilingual aliases and favorites intersect across live updates and selection',
    (tester) async {
      final events = StreamController<MarketQuotes>.broadcast();
      MarketQuote described(
        String symbol,
        List<String> categories, {
        String name = '',
        List<String> aliases = const [],
        String price = '123.456',
      }) => MarketQuote(
        symbol: symbol,
        base: symbol.replaceFirst(RegExp(r'USDT$'), ''),
        precision: const MarketPrecision(),
        price: Decimal.parse(price),
        descriptor: MarketDescriptor(name: name, aliases: aliases, categories: categories),
      );
      MarketQuotes feed(String price) => MarketQuotes(
        quotes: [
          for (var i = 0; i < 150; i++) described('COIN${i}USDT', []),
          described('BTCUSDT', ['Top']),
          described('ETHUSDT', ['Top', 'AI']),
          described('XAUUSDT', ['Commodities'], name: 'Gold', aliases: ['黄金'], price: price),
          described('FAKEAIUSDT', [], name: 'AI'),
        ],
        connection: QuoteConnection.live,
      );
      final container = setup(tester, quoteStream: events.stream);
      await launch(tester, container);
      container.read(orderPriceProvider.notifier).setPrice('123.45');
      await tester.tap(find.byKey(const Key('trade-market-selector')));
      await tester.pump(const Duration(milliseconds: 400));
      events.add(feed('123.456'));
      await tester.pumpAndSettle();
      expect(find.text('154 / 154 个永续合约'), findsOneWidget);
      expect(find.byType(MarketListRow).evaluate().length, lessThan(20)); // lazy rows
      await tester.ensureVisible(find.byKey(const Key('market-category-top')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-category-top')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 154 个永续合约'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('market-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('market-search')), '黄金');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的合约'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('market-category-commodities')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-category-commodities')));
      await tester.pumpAndSettle();
      final gold = find.byKey(const Key('market-XAUUSDT'));
      expect(gold, findsOneWidget); // matches an alias beyond the former 100 cap
      expect(find.text('Gold'), findsOneWidget);
      expect(container.read(symbolProvider), 'BTCUSDT');
      await tester.ensureVisible(find.byKey(const Key('favorite-XAUUSDT')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('favorite-XAUUSDT')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('自选').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('自选').first);
      await tester.pumpAndSettle();
      events.add(feed('124.567'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: gold, matching: find.text('124.567')), findsOneWidget);
      expect(container.read(marketSelectionProvider).query, '黄金');
      expect(container.read(marketSelectionProvider).category, MarketCategory.commodities);
      expect(container.read(marketSelectionProvider).onlyFavorites, true);
      await tester.ensureVisible(find.byTooltip('清除搜索'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pumpAndSettle();
      expect(gold, findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('market-XAUUSDT')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-XAUUSDT')));
      await tester.pumpAndSettle();
      expect(container.read(symbolProvider), 'XAUUSDT');
      expect(container.read(orderPriceProvider), '');
      await tester.tap(find.byKey(const Key('trade-market-selector')));
      await tester.pump(const Duration(milliseconds: 400));
      events.add(feed('124.567'));
      await tester.pumpAndSettle();
      expect(container.read(marketSelectionProvider).query, '');
      expect(container.read(marketSelectionProvider).category, MarketCategory.all);
      expect(container.read(marketSelectionProvider).onlyFavorites, false);
      expect(container.read(favoriteSymbolsProvider), {'XAUUSDT'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(events.close());
      await tester.pumpAndSettle();
    },
  );

  for (final spec in [(360.0, 1.5, 'zh'), (390.0, 2.0, 'en'), (844.0, 1.5, 'en')]) {
    testWidgets('category controls stay accessible at ${spec.$1}, scale ${spec.$2}, ${spec.$3}', (
      tester,
    ) async {
      final container = setup(tester, width: spec.$1, scale: spec.$2, language: Locale(spec.$3));
      if (spec.$1 == 844) tester.view.physicalSize = const Size(844, 390);
      await launch(tester, container);
      await tester.tap(find.byKey(const Key('trade-market-selector')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('market-category-semiconductors')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-category-semiconductors')));
      await tester.pumpAndSettle();
      expect(container.read(marketSelectionProvider).category, MarketCategory.semiconductors);
      expect(
        find.text(
          spec.$3 == 'en'
              ? 'No contracts in this category match your filters.'
              : '该分类下没有符合筛选条件的合约。',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('market-category-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('market-category-all')));
      await tester.pumpAndSettle();
      expect(container.read(marketSelectionProvider).category, MarketCategory.all);
      expect(find.byKey(const Key('market-BTCUSDT')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('live updates retain search and favorites while offline values stay selectable', (
    tester,
  ) async {
    final events = StreamController<MarketQuotes>.broadcast();
    final container = setup(tester, quoteStream: events.stream, width: 360, scale: 1.5);
    MarketQuotes feed(String price, QuoteConnection connection) => MarketQuotes(
      quotes: [
        MarketQuote(
          symbol: 'BTCUSDT',
          base: 'BTC',
          precision: const MarketPrecision(),
          price: Decimal.parse(price),
          change: Decimal.parse('1.25'),
          funding: Decimal.parse('0.000345'),
          quoteVolume: Decimal.parse('1234.5'),
        ),
      ],
      connection: connection,
      updatedAt: DateTime(2026, 11, 2, 12),
    );
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('trade-market-selector')));
    await tester.pump(const Duration(milliseconds: 400));
    events.add(feed('123.456', QuoteConnection.live));
    await tester.pumpAndSettle();
    expect(find.text('实时报价'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('market-search')));
    await tester.enterText(find.byKey(const Key('market-search')), ' btc ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('favorite-BTCUSDT')));
    await tester.tap(find.byKey(const Key('favorite-BTCUSDT')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('自选').first);
    await tester.tap(find.text('自选').first);
    await tester.pumpAndSettle();
    events.add(feed('124.567', QuoteConnection.live));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('market-BTCUSDT'));
    expect(find.descendant(of: row, matching: find.text('124.567')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('+0.0345%')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('market-search'))).controller?.text,
      ' btc ',
    );
    events.add(feed('124.567', QuoteConnection.offline));
    await tester.pumpAndSettle();
    expect(find.text('报价已离线，保留最近数据'), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('124.567')), findsOneWidget);
    expect(find.byKey(const Key('retry-market-quotes')), findsOneWidget);
    expect(container.read(symbolProvider), 'BTCUSDT');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    unawaited(events.close());
    await tester.pumpAndSettle();
  });
  for (final spec in [(360.0, 1.5), (390.0, 2.0), (844.0, 1.5)]) {
    testWidgets('selector search, clear and empty states at ${spec.$1} scale ${spec.$2}', (
      tester,
    ) async {
      final container = setup(tester, width: spec.$1, scale: spec.$2);
      if (spec.$1 == 844) tester.view.physicalSize = const Size(844, 390);
      await launch(tester, container);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('trade-market-selector')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('market-search')));
      await tester.enterText(find.byKey(const Key('market-search')), ' eth ');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('market-ETHUSDT')), findsOneWidget);
      expect(find.byKey(const Key('market-BTCUSDT')), findsNothing);
      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('market-search'))).controller?.text, '');
      expect(find.byKey(const Key('market-BTCUSDT')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('market-search')), 'notlisted');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的合约'), findsOneWidget);
      expect(container.read(symbolProvider), 'BTCUSDT');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
