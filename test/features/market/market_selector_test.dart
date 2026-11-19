import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/market/domain/market_quote.dart';
import 'package:vanta/features/market/domain/market_quotes.dart';
import 'package:vanta/features/market/domain/market_precision.dart';
import 'package:vanta/features/market/domain/market_descriptor.dart';
import 'package:vanta/features/market/domain/public_leverage.dart';
import 'package:vanta/features/market/application/market_selection_provider.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/market_list_row.dart';

import '../../support/trade_fixture.dart';

void main() {
  testWidgets('multilingual aliases and favorites intersect across live updates and selection', (
    tester,
  ) async {
    final events = StreamController<MarketQuotes>.broadcast();
    MarketQuote described(
      String symbol, {
      String name = '',
      List<String> aliases = const [],
      String price = '123.456',
    }) => MarketQuote(
      symbol: symbol,
      base: symbol.replaceFirst(RegExp(r'USDT$'), ''),
      precision: const MarketPrecision(),
      price: Decimal.parse(price),
      descriptor: MarketDescriptor(name: name, aliases: aliases),
    );
    MarketQuotes feed(String price) => MarketQuotes(
      quotes: [
        for (var i = 0; i < 150; i++) described('COIN${i}USDT'),
        described('BTCUSDT'),
        described('ETHUSDT'),
        described('XAUUSDT', name: 'Gold', aliases: ['黄金'], price: price),
        described('FAKEAIUSDT', name: 'AI'),
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
    expect(find.textContaining('个永续合约'), findsNothing); // design has no count row
    expect(find.byType(MarketListRow).evaluate().length, lessThan(20)); // lazy rows
    await tester.ensureVisible(find.byKey(const Key('market-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('market-search')), '黄金');
    await tester.pumpAndSettle();
    expect(find.byType(MarketListRow), findsOneWidget);
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
    expect(container.read(marketSelectionProvider).onlyFavorites, false);
    expect(container.read(favoriteSymbolsProvider), {'XAUUSDT'});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
    await tester.pumpAndSettle();
  });

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
    expect(find.text('实时报价'), findsNothing); // no connection status row
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
    expect(find.text('报价已离线，保留最近数据'), findsNothing);
    expect(find.descendant(of: row, matching: find.text('124.567')), findsOneWidget);
    expect(container.read(symbolProvider), 'BTCUSDT');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    unawaited(events.close());
    await tester.pumpAndSettle();
  });
  testWidgets('rows show public max leverage and open interest; titles sort; keyboard stays', (
    tester,
  ) async {
    final events = StreamController<MarketQuotes>.broadcast();
    MarketQuote row(String symbol, String volume, String mark) => MarketQuote(
      symbol: symbol,
      base: symbol.replaceFirst('USDT', ''),
      precision: const MarketPrecision(),
      price: Decimal.parse(mark),
      quoteVolume: Decimal.parse(volume),
      markPrice: Decimal.parse(mark),
    );
    final container = setup(
      tester,
      quoteStream: events.stream,
      publicLeverage: {
        'BTCUSDT': PublicLeverage([(1, 200), (1, 50)]),
      },
      openInterest: {'BTCUSDT': Decimal.parse('2.5'), 'ETHUSDT': Decimal.fromInt(10)},
    );
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('trade-market-selector')));
    await tester.pump(const Duration(milliseconds: 400));
    events.add(
      MarketQuotes(
        quotes: [row('ETHUSDT', '10', '2000'), row('BTCUSDT', '30', '64000')],
        connection: QuoteConnection.live,
      ),
    );
    await tester.pumpAndSettle();
    final btc = find.byKey(const Key('market-BTCUSDT'));
    expect(find.descendant(of: btc, matching: find.text('200x')), findsOneWidget);
    expect(
      find.descendant(of: btc, matching: find.text(r'$160,000')),
      findsOneWidget,
    ); // 2.5 × 64000
    expect(
      find.descendant(of: find.byKey(const Key('market-ETHUSDT')), matching: find.text(r'$20,000')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const Key('market-ETHUSDT')), matching: find.text('200x')),
      findsNothing,
    );
    List<String> order() => [
      for (final element in find.byType(MarketListRow).evaluate())
        (element.widget as MarketListRow).quote.symbol,
    ];
    expect(order(), ['ETHUSDT', 'BTCUSDT']); // catalog order
    await tester.tap(find.byKey(const Key('market-sort-volume')));
    await tester.pumpAndSettle();
    expect(order(), ['BTCUSDT', 'ETHUSDT']);
    await tester.tap(find.byKey(const Key('market-sort-volume')));
    await tester.pumpAndSettle();
    expect(order(), ['ETHUSDT', 'BTCUSDT']);
    await tester.tap(find.byKey(const Key('market-sort-openInterest')));
    await tester.pumpAndSettle();
    expect(order(), ['BTCUSDT', 'ETHUSDT']);
    // An open keyboard shrinks the page below the compact threshold; the
    // focused search field must survive instead of being rebuilt.
    await tester.tap(find.byKey(const Key('market-search')));
    await tester.pump();
    final field = tester.state<EditableTextState>(find.byType(EditableText));
    expect(field.widget.focusNode.hasFocus, isTrue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.state<EditableTextState>(find.byType(EditableText)), same(field));
    expect(field.widget.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(events.close());
    await tester.pumpAndSettle();
  });

  testWidgets('long symbols stay on one line inside the 360dp symbol column', (tester) async {
    final events = StreamController<MarketQuotes>.broadcast();
    MarketQuote row(String symbol) => MarketQuote(
      symbol: symbol,
      base: symbol.replaceFirst('USDT', ''),
      precision: const MarketPrecision(),
      price: Decimal.one,
      quoteVolume: Decimal.parse('64470000'),
      markPrice: Decimal.one,
    );
    final container = setup(tester, width: 360, scale: 1.3, quoteStream: events.stream);
    await launch(tester, container);
    await tester.tap(find.byKey(const Key('trade-market-selector')));
    await tester.pump(const Duration(milliseconds: 400));
    events.add(
      MarketQuotes(
        quotes: [row('BTCUSDT'), row('ASTERUSDT'), row('1000PEPEUSDT')],
        connection: QuoteConnection.live,
      ),
    );
    await tester.pumpAndSettle();
    final line = tester.getSize(find.byKey(const ValueKey('market-symbol-BTCUSDT'))).height;
    for (final symbol in ['ASTERUSDT', '1000PEPEUSDT']) {
      final text = find.byKey(ValueKey('market-symbol-$symbol'));
      expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines, isFalse);
      expect(tester.getSize(text).height, line, reason: symbol);
      // Scaled within the symbol column instead of wrapping past it.
      final fitted = find.ancestor(of: text, matching: find.byType(FittedBox)).first;
      expect(tester.getRect(text).right, lessThanOrEqualTo(tester.getRect(fitted).right + 0.01));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
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
      expect(find.byType(ChoiceChip), findsNothing); // no category filter
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
      expect(find.text('未找到结果'), findsOneWidget);
      expect(find.text('请尝试其他关键词。'), findsOneWidget);
      expect(container.read(symbolProvider), 'BTCUSDT');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
