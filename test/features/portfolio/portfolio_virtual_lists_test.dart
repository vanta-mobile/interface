import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/market/application/selection_providers.dart';
import 'package:vanta/features/portfolio/application/portfolio_loading_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';
import 'package:vanta/features/portfolio/domain/portfolio_overview.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_asset_row.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_futures_section.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_position_card.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

final _snapshot = NotifierProvider<_Snapshot, PortfolioOverview>(_Snapshot.new);

class _Snapshot extends Notifier<PortfolioOverview> {
  @override
  PortfolioOverview build() => PortfolioOverview(performance: PortfolioPerformance());
  void replace(PortfolioOverview value) => state = value;
}

class _Preview extends PortfolioPreviewController {
  @override
  bool build() => true;
}

void main() {
  PortfolioPosition position(String symbol, [String side = 'BOTH']) => PortfolioPosition(
    symbol: symbol,
    side: side,
    long: side != 'SHORT',
    quantity: Decimal.one,
    base: symbol.replaceAll('USDT', ''),
    quote: 'USDT',
    marginAsset: 'USDT',
  );
  PortfolioOverview overview({
    List<PortfolioPosition> positions = const [],
    List<PortfolioAsset> assets = const [],
  }) => PortfolioOverview(
    totalUsd: Decimal.one,
    performance: PortfolioPerformance(),
    positions: positions,
    assets: assets,
  );
  Future<ProviderContainer> mount(
    WidgetTester t,
    PortfolioOverview data, {
    Size size = const Size(393, 844),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = ProviderContainer(
      overrides: [
        portfolioOverviewProvider.overrideWith((ref) => ref.watch(_snapshot)),
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
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(16),
                  sliver: PortfolioFuturesSection(hidden: false),
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
    await mount(t, overview(positions: List.generate(1000, (i) => position('COIN${i}USDT'))));
    expect(find.byType(PortfolioPositionCard).evaluate().length, lessThan(10));
    expect(find.byKey(const Key('portfolio-position-COIN999USDT-BOTH')), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const Key('portfolio-position-COIN20USDT-BOTH')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('portfolio-position-COIN20USDT-BOTH')), findsOneWidget);
    expect(find.byType(PortfolioPositionCard).evaluate().length, lessThan(10));
    expect(t.takeException(), isNull);
  });

  testWidgets('symbol filtering preserves both hedge sides and reacts to market changes', (
    t,
  ) async {
    final c = await mount(
      t,
      overview(
        positions: [
          position('ETHUSDT', 'LONG'),
          position('BTCUSDT', 'LONG'),
          position('BTCUSDT', 'SHORT'),
          position('SOLUSDT'),
        ],
      ),
    );
    await filter(t);
    expect(find.byKey(const Key('portfolio-position-BTCUSDT-LONG')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-position-BTCUSDT-SHORT')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-position-ETHUSDT-LONG')), findsNothing);
    final sides = t
        .widgetList<PortfolioPositionCard>(find.byType(PortfolioPositionCard))
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
        overview(positions: List.generate(200, (i) => position('COIN${i}USDT'))),
        size: size,
        scale: 1.5,
      );
      expect(find.byType(PortfolioPositionCard).evaluate().length, lessThan(10));
      expect(t.takeException(), isNull);
    });
  }
}
