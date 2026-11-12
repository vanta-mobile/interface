import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/portfolio_loading_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';
import 'package:vanta/features/portfolio/domain/portfolio_overview.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_asset_row.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_futures_section.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';
import 'package:vanta/features/portfolio/presentation/trade_position_card.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

final _snapshot = NotifierProvider<_Snapshot, PortfolioOverview>(_Snapshot.new);

class _Snapshot extends Notifier<PortfolioOverview> {
  @override
  PortfolioOverview build() => PortfolioOverview(performance: PortfolioPerformance());
  void replace(PortfolioOverview value) => state = value;
}

final _positions = NotifierProvider<_Positions, List<PositionRisk>>(_Positions.new);

class _Positions extends Notifier<List<PositionRisk>> {
  @override
  List<PositionRisk> build() => const [];
  void replace(List<PositionRisk> value) => state = value;
}

class _Preview extends PortfolioPreviewController {
  @override
  bool build() => true;
}

void main() {
  PositionRisk position(String symbol, [String side = 'BOTH']) => PositionRisk(
    symbol: symbol,
    side: side,
    quantity: side == 'SHORT' ? -Decimal.one : Decimal.one,
    entryPrice: Decimal.one,
    markPrice: Decimal.one,
    isolated: false,
    isolatedWallet: Decimal.zero,
    leverage: 10,
    units: AsterContractUnits(base: symbol.replaceAll('USDT', ''), quote: 'USDT', margin: 'USDT'),
  );
  PortfolioOverview overview({List<PortfolioAsset> assets = const []}) =>
      PortfolioOverview(totalUsd: Decimal.one, performance: PortfolioPerformance(), assets: assets);
  Future<ProviderContainer> mount(
    WidgetTester t,
    PortfolioOverview data, {
    List<PositionRisk> positions = const [],
    Size size = const Size(393, 844),
    double scale = 1,
    bool hidden = false,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = ProviderContainer(
      overrides: [
        portfolioOverviewProvider.overrideWith((ref) => ref.watch(_snapshot)),
        portfolioPositionsProvider.overrideWith((ref) => ref.watch(_positions)),
        portfolioPreviewProvider.overrideWith(_Preview.new),
        portfolioLoadingProvider.overrideWithValue((
          account: false,
          value: false,
          valuation: false,
        )),
      ],
    );
    addTearDown(c.dispose);
    c.read(_snapshot.notifier).replace(data);
    c.read(_positions.notifier).replace(positions);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: PortfolioFuturesSection(hidden: hidden),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  Future<void> filter(WidgetTester t) async {
    final control = find.byKey(const Key('portfolio-hide-other-symbols'));
    await t.ensureVisible(control);
    await t.pumpAndSettle();
    await t.tap(control);
    await t.pumpAndSettle();
  }

  testWidgets('1,000 positions build only viewport cards and remain lazy when scrolling', (
    t,
  ) async {
    await mount(t, overview(), positions: List.generate(1000, (i) => position('COIN${i}USDT')));
    expect(find.byType(TradePositionCard).evaluate().length, lessThan(10));
    expect(find.byKey(const Key('portfolio-position-COIN999USDT-BOTH')), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const Key('portfolio-position-COIN20USDT-BOTH')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('portfolio-position-COIN20USDT-BOTH')), findsOneWidget);
    expect(find.byType(TradePositionCard).evaluate().length, lessThan(10));
    expect(t.takeException(), isNull);
  });

  testWidgets('symbol filtering preserves both hedge sides and reacts to market changes', (
    t,
  ) async {
    final c = await mount(
      t,
      overview(),
      positions: [
        position('ETHUSDT', 'LONG'),
        position('BTCUSDT', 'LONG'),
        position('BTCUSDT', 'SHORT'),
        position('SOLUSDT'),
      ],
    );
    await filter(t);
    expect(find.byKey(const Key('portfolio-position-BTCUSDT-LONG')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-position-BTCUSDT-SHORT')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-position-ETHUSDT-LONG')), findsNothing);
    final sides = t
        .widgetList<TradePositionCard>(find.byType(TradePositionCard))
        .map((w) => w.position.side);
    expect(sides, ['LONG', 'SHORT']);
    c.read(symbolProvider.notifier).select('ETHUSDT');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-position-ETHUSDT-LONG')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-position-BTCUSDT-SHORT')), findsNothing);
    c.read(symbolProvider.notifier).select('XRPUSDT');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-positions-empty')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('positions use the shared Futures card and mask values while hidden', (t) async {
    await mount(t, overview(), positions: [position('BTCUSDT', 'LONG')], hidden: true);
    final card = t.widget<TradePositionCard>(find.byType(TradePositionCard));
    expect(card.hidden, true);
    expect(find.byKey(const Key('trade-position-BTCUSDT-LONG')), findsOneWidget);
    expect(find.text(hiddenAmount), findsWidgets);
    expect(find.text('\$1'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('tapping the margin ratio gauge toggles its explanation', (t) async {
    await mount(t, overview(), positions: [position('BTCUSDT', 'LONG')]);
    final tip = find.byKey(const Key('trade-position-margin-tip'));
    final l = AppLocalizations.of(t.element(find.byType(TradePositionCard)));
    expect(tip, findsNothing);
    await t.tap(find.byKey(const Key('trade-position-margin-gauge')));
    await t.pumpAndSettle();
    expect(tip, findsOneWidget);
    expect(find.text(l.positionsMarginRatioTip), findsOneWidget);
    final gauge = t.getRect(find.byKey(const Key('trade-position-margin-gauge')));
    final bubble = t.getRect(tip);
    expect(bubble.bottom, lessThanOrEqualTo(gauge.top));
    expect(bubble.width, 288);
    // Figma: the arrow tip sits 18 px inside the bubble's right edge.
    final arrow = t.getRect(find.byType(SvgPicture).last);
    expect(arrow.size, const Size(36, 7));
    expect(bubble.right - arrow.center.dx, 18);
    expect(arrow.top, bubble.bottom - 1);
    await t.tapAt(const Offset(20, 600));
    await t.pumpAndSettle();
    expect(tip, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('updated USD sorting moves the matching asset element with its identity', (t) async {
    PortfolioAsset a(String symbol, String usd) =>
        PortfolioAsset(symbol: symbol, balance: Decimal.one, usd: Decimal.parse(usd));
    final c = await mount(t, overview(assets: [a('USDT', '100'), a('BNB', '700')]));
    await t.tap(find.byKey(const Key('portfolio-assets-tab-assets')));
    await t.pumpAndSettle();
    final bnb = find.byKey(const Key('portfolio-asset-BNB'));
    final usdt = find.byKey(const Key('portfolio-asset-USDT'));
    final original = t.element(bnb);
    expect(t.getTopLeft(bnb).dy, lessThan(t.getTopLeft(usdt).dy));
    c.read(_snapshot.notifier).replace(overview(assets: [a('USDT', '100'), a('BNB', '50')]));
    await t.pumpAndSettle();
    expect(t.getTopLeft(usdt).dy, lessThan(t.getTopLeft(bnb).dy));
    expect(t.element(bnb), same(original));
    expect(find.byType(PortfolioAssetRow), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(320, 700), const Size(844, 390)]) {
    testWidgets('lazy positions fit $size at enlarged text', (t) async {
      await mount(
        t,
        overview(),
        positions: List.generate(200, (i) => position('COIN${i}USDT')),
        size: size,
        scale: 1.5,
      );
      expect(find.byType(TradePositionCard).evaluate().length, lessThan(10));
      expect(t.takeException(), isNull);
    });
  }
}
