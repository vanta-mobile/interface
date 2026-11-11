import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/application/account_read_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_loading_provider.dart';
import 'package:vanta/features/portfolio/application/portfolio_overview_provider.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/asset_valuation.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_asset_row.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_assets.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_screen.dart';
import 'package:vanta/features/portfolio/presentation/portfolio_summary.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/asset_indices.dart';
import '../../support/aster_account.dart';
import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';

void main() {
  Future<ProviderContainer> mount(
    WidgetTester t,
    TestAsterAccountRepository account, {
    TestAssetIndexRepository? prices,
    bool authorized = true,
    Size size = const Size(393, 1100),
    double scale = 1,
    String locale = 'en',
  }) async {
    final identity = NavigationIdentity()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final store = MemoryTradingAgentStorage().store(DateTime.now);
    final agent = await store.prepare(
      signingIdentity.id,
      accountAddress,
      DateTime.now().add(const Duration(days: 30)),
    );
    await store.setStatus(agent, TradingAgentStatus.unknown);
    if (authorized) await store.setStatus(agent, TradingAgentStatus.active);
    final c = setup(
      t,
      identityRepository: identity,
      asterAccountRepository: account,
      assetIndexRepository: prices,
      tradingAgentStore: store,
      width: size.width,
      scale: scale,
      language: Locale(locale),
    );
    t.view.physicalSize = size;
    await c.read(authProvider.notifier).bootstrap();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: PortfolioPage()),
        ),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  Future<void> switchAssets(WidgetTester t) async {
    final tab = find.byKey(const Key('portfolio-assets-tab-assets'));
    await t.scrollUntilVisible(
      tab,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('portfolio-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.pumpAndSettle();
    await t.tap(tab);
    // The next frame must already select Assets while transport is pending.
    await t.pump();
    expect(t.widget<PortfolioAssetTabs>(find.byType(PortfolioAssetTabs)).assets, isTrue);
  }

  Future<void> close(WidgetTester t, ProviderContainer c) async {
    await t.pumpWidget(const SizedBox());
    c.dispose();
  }

  testWidgets('switch selects assets in one frame while the first account read is blocked', (
    t,
  ) async {
    final account = TestAsterAccountRepository()..gate = Completer<void>();
    final c = await mount(t, account);
    expect(account.calls, 1);
    expect(find.byKey(const Key('portfolio-value-loading')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-positions-loading')), findsOneWidget);
    expect(find.text('No positions'), findsNothing);
    await switchAssets(t);
    expect(c.read(accountReadProvider).busy, isTrue);
    expect(find.byKey(const Key('portfolio-assets-loading')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-positions-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-deposit')), findsOneWidget);
    expect(account.calls, 1); // Switching tabs does not start another read.
    account.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-assets-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-value-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-asset-USDT')), findsOneWidget);
    expect(t.takeException(), isNull);
    await close(t, c);
  });

  testWidgets('account data renders before the first USD valuation finishes', (t) async {
    final prices = TestAssetIndexRepository()..gate = Completer<AssetIndexSnapshot>();
    final c = await mount(t, TestAsterAccountRepository(), prices: prices);
    await switchAssets(t);
    expect(find.byKey(const Key('portfolio-assets-loading')), findsNothing);
    expect(find.text('Avbl. 89'), findsOneWidget);
    expect(find.byKey(const Key('portfolio-value-loading')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-asset-value-pending-USDT')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-asset-pnl-pending-USDT')), findsOneWidget);
    prices.gate!.complete(assetIndexFixture(DateTime.now().toUtc()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-value-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-asset-value-pending-USDT')), findsNothing);
    expect(find.byKey(const Key('portfolio-asset-pnl-pending-USDT')), findsNothing);
    expect(t.takeException(), isNull);
    await close(t, c);
  });

  testWidgets('refresh failure retains both tabs data and waits for account and prices', (t) async {
    final account = TestAsterAccountRepository();
    final prices = TestAssetIndexRepository();
    final c = await mount(t, account, prices: prices);
    await switchAssets(t);
    final before = c.read(portfolioOverviewProvider).assets.first.balance;
    account.gate = Completer<void>();
    account.failure = const AccountReadFailure('accountNetwork');
    prices.gate = Completer<AssetIndexSnapshot>();
    var settled = false;
    final refresh = c.read(portfolioRefreshProvider)().then((_) => settled = true);
    await t.pump();
    expect(find.byKey(const Key('portfolio-assets-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-value-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-asset-USDT')), findsOneWidget);
    account.gate!.complete();
    await t.pumpAndSettle();
    expect(settled, isFalse);
    prices.gate!.completeError(const FormatException('fixture failed read'));
    await refresh;
    await t.pumpAndSettle();
    expect(settled, isTrue);
    expect(c.read(portfolioOverviewProvider).assets.first.balance, before);
    expect(find.byKey(const Key('account-read-error')), findsOneWidget);
    expect(find.byKey(const Key('portfolio-asset-USDT')), findsOneWidget);
    expect(c.read(portfolioLoadingProvider), (account: false, value: false, valuation: false));
    expect(t.takeException(), isNull);
    await close(t, c);
  });

  testWidgets('initial account failure stops skeletons and renders existing failure feedback', (
    t,
  ) async {
    final account = TestAsterAccountRepository()..gate = Completer<void>();
    final c = await mount(t, account);
    await switchAssets(t);
    account.failure = const AccountReadFailure('accountNetwork');
    account.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-assets-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-value-loading')), findsNothing);
    expect(find.byKey(const Key('account-read-error')), findsOneWidget);
    expect(t.takeException(), isNull);
    await close(t, c);
  });

  testWidgets('failed initial valuation stops placeholders without hiding native balances', (
    t,
  ) async {
    final prices = TestAssetIndexRepository()..gate = Completer<AssetIndexSnapshot>();
    final c = await mount(t, TestAsterAccountRepository(), prices: prices);
    await switchAssets(t);
    prices.gate!.completeError(const FormatException('fixture failed read'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-value-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-asset-value-pending-USDT')), findsNothing);
    expect(find.text('Avbl. 89'), findsOneWidget);
    expect(c.read(portfolioLoadingProvider).valuation, isFalse);
    expect(t.takeException(), isNull);
    await close(t, c);
  });

  testWidgets('a successful empty account shows its empty state after loading', (t) async {
    final account = TestAsterAccountRepository()
      ..gate = Completer<void>()
      ..result = AsterAccount(
        address: accountAddress,
        receivedAt: DateTime.now().toUtc(),
        assets: [],
        positions: [],
      );
    final c = await mount(t, account);
    await switchAssets(t);
    expect(find.byKey(const Key('portfolio-assets-empty')), findsNothing);
    account.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('portfolio-assets-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-assets-empty')), findsOneWidget);
    expect(t.takeException(), isNull);
    await close(t, c);
  });

  testWidgets('missing authorization does not leave initial loading placeholders', (t) async {
    final account = TestAsterAccountRepository();
    final c = await mount(t, account, authorized: false);
    await switchAssets(t);
    expect(account.calls, 0);
    expect(find.byKey(const Key('portfolio-assets-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-value-loading')), findsNothing);
    expect(find.byKey(const Key('portfolio-enable-trading')), findsOneWidget);
    expect(t.takeException(), isNull);
    await close(t, c);
  });

  testWidgets('large asset lists build visible rows without rebuilding the account summary', (
    t,
  ) async {
    final account = TestAsterAccountRepository()
      ..result = AsterAccount(
        address: accountAddress,
        receivedAt: DateTime.now().toUtc(),
        positions: [],
        assets: List.generate(
          1000,
          (i) => AsterAssetBalance(asset: 'COIN$i', walletBalance: Decimal.one),
        ),
      );
    final c = await mount(t, account);
    final summary = t.widget<PortfolioAccountValue>(find.byType(PortfolioAccountValue));
    await switchAssets(t);
    expect(
      identical(summary, t.widget<PortfolioAccountValue>(find.byType(PortfolioAccountValue))),
      isTrue,
    );
    expect(find.byType(PortfolioAssetRow).evaluate().length, lessThan(20));
    expect(find.byKey(const Key('portfolio-asset-COIN999')), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const Key('portfolio-asset-COIN50')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('portfolio-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('portfolio-asset-COIN50')), findsOneWidget);
    expect(find.byType(PortfolioAssetRow).evaluate().length, lessThan(20));
    expect(account.calls, 1);
    expect(t.takeException(), isNull);
    await close(t, c);
  });

  for (final size in [const Size(320, 700), const Size(844, 390), const Size(768, 1024)]) {
    testWidgets('loading assets fit $size in Chinese at 1.5 text scale', (t) async {
      final account = TestAsterAccountRepository()..gate = Completer<void>();
      final c = await mount(t, account, size: size, scale: 1.5, locale: 'zh');
      await switchAssets(t);
      expect(find.byKey(const Key('portfolio-assets-loading')), findsOneWidget);
      expect(t.takeException(), isNull);
      account.gate!.complete();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await close(t, c);
    });
  }
}
