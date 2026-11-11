import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/asset_index_provider.dart';
import 'package:vanta/features/portfolio/application/asset_metadata_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/portfolio_overview.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_assets.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/asset_indices.dart';
import '../../support/asset_metadata.dart';
import '../../support/aster_account.dart';
import '../../support/navigation_fixture.dart';

void main() {
  Decimal d(String value) => Decimal.parse(value);
  final overview = PortfolioOverview(
    totalUsd: d('10'),
    performance: PortfolioPerformance(),
    assets: [
      PortfolioAsset(
        symbol: 'USDT',
        balance: d('10.254461'),
        available: d('9.678131'),
        pnl: d('-0.3'),
        pnlUsd: d('-0.299508'),
        usd: d('9.8'),
      ),
      PortfolioAsset(symbol: 'BNB', balance: d('0.002'), usd: d('0.9')),
      PortfolioAsset(symbol: 'BTC', balance: d('0.00001')),
    ],
  );

  Future<void> mount(
    WidgetTester tester, {
    String locale = 'en',
    double width = 393,
    double scale = 1,
    bool hidden = false,
  }) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var hideSmall = false;
    final container = ProviderContainer(
      overrides: [assetMetadataRepositoryProvider.overrideWithValue(TestAssetMetadataRepository())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      PortfolioAssetTabs(assets: true, count: 1, onChanged: (_) {}),
                      PortfolioAssetList(
                        overview: overview,
                        preview: true,
                        hidden: hidden,
                        hideSmall: hideSmall,
                        onHideSmall: (v) => setState(() => hideSmall = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asset USD profit preserves native units and never assumes a stablecoin peg', (
    t,
  ) async {
    final now = DateTime.now().toUtc();
    final indices = TestAssetIndexRepository()
      ..result = assetIndexFixture(now, prices: {'USDT': '0.99836', 'BNB': '700'});
    final f = NavigationFixture(t, assetIndexRepository: indices);
    f.account.result = AsterAccount(
      address: accountAddress,
      receivedAt: now,
      positions: [],
      assets: [
        AsterAssetBalance(asset: 'USDT', walletBalance: d('10'), unrealizedProfit: d('-0.3')),
        AsterAssetBalance(asset: 'BNB', walletBalance: Decimal.zero, unrealizedProfit: d('0.002')),
        AsterAssetBalance(asset: 'UNKNOWN', walletBalance: Decimal.one, unrealizedProfit: d('0.5')),
      ],
    );
    final subscription = f.container.listen(portfolioOverviewProvider, (_, _) {});
    await f.container.read(authProvider.notifier).bootstrap();
    await f.container.read(assetIndexProvider.notifier).refresh();
    await f.container.read(accountReadProvider.notifier).refresh();
    final assets = f.container.read(portfolioOverviewProvider).assets;
    expect(assets[0].pnl, d('-0.3'));
    expect(assets[0].pnlUsd, d('-0.299508'));
    expect(assets[1].pnl, d('0.002'));
    expect(assets[1].pnlUsd, d('1.4'));
    expect(assets[2].pnlUsd, isNull);
    subscription.close();
    await f.close(t);
  });

  testWidgets('low balance filter retains unknown valuations and asset details remain accessible', (
    t,
  ) async {
    await mount(t);
    expect(find.text('−\$0.299508'), findsOneWidget);
    expect(find.text('Avbl. 9.678131'), findsOneWidget);
    await t.tap(find.byKey(const Key('portfolio-hide-small-assets')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-asset-BNB')), findsNothing);
    expect(find.byKey(const Key('portfolio-asset-BTC')), findsOneWidget);
    await t.tap(find.byKey(const Key('portfolio-asset-USDT')));
    await t.pumpAndSettle();
    expect(find.text('Margin balance'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final locale in ['en', 'zh']) {
    for (final hidden in [false, true]) {
      testWidgets('assets fit narrow enlarged text in $locale, hidden=$hidden', (t) async {
        await mount(t, locale: locale, width: 320, scale: 1.5, hidden: hidden);
        if (hidden) {
          expect(find.textContaining('9.678131'), findsNothing);
          expect(find.textContaining('0.299508'), findsNothing);
          expect(find.textContaining('10.254461', findRichText: true), findsNothing);
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
