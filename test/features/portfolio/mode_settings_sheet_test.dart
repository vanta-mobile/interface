import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vanta/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/presentation/position_margin_mode_screen.dart';
import 'package:vanta/features/portfolio/presentation/position_risk_screen.dart';
import 'package:vanta/features/portfolio/application/futures_asset_mode_provider.dart';
import 'package:vanta/features/portfolio/application/futures_position_mode_provider.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';
import 'package:vanta/features/portfolio/presentation/futures_asset_mode_screen.dart';
import 'package:vanta/features/portfolio/presentation/futures_position_mode_screen.dart';
import 'package:vanta/features/portfolio/presentation/mode_settings_sheet.dart';
import 'package:vanta/features/portfolio/presentation/multi_asset_activation_sheet.dart';

import '../../support/aster_account.dart';
import '../../support/futures_asset_mode.dart';
import '../../support/futures_position_mode.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';

const isolated = AssetModeMarket(
  symbol: 'ETHUSDT',
  marginMode: PositionMarginMode.isolated,
  hasPosition: false,
  hasCollateral: false,
);
const cross = AssetModeMarket(
  symbol: 'ETHUSDT',
  marginMode: PositionMarginMode.cross,
  hasPosition: false,
  hasCollateral: false,
);

FuturesAssetModeContext marketContext(List<AssetModeMarket> markets) => FuturesAssetModeContext(
  address: accountAddress,
  current: FuturesAssetMode.single,
  isolatedSymbols: markets.where((m) => m.requiresCross && m.blocked).map((m) => m.symbol).toList(),
  markets: markets,
  receivedAt: assetModeClock,
);

FilledButton action(WidgetTester t, String key) => t.widget<FilledButton>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)).first,
);
Future<void> tap(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

Future<void> close(WidgetTester t, ProviderContainer c) async {
  await t.pumpWidget(const SizedBox());
  c.dispose();
}

/// Reproduce a running app whose bundle predates the new mode sheets.
class ExistingPortfolioBundle extends CachingAssetBundle {
  final requested = <String>[];
  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    if (key.startsWith('assets/portfolio/mode-')) {
      throw FlutterError('Asset is absent from the running app bundle: $key');
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('existing asset bundle renders settings icons and close dismisses the sheet', (
    t,
  ) async {
    final c = setup(t, language: const Locale('en'));
    final bundle = ExistingPortfolioBundle();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: DefaultAssetBundle(bundle: bundle, child: const VantaApp()),
      ),
    );
    await t.pumpAndSettle();
    await tap(t, 'trade-settings');
    expect(t.takeException(), null);
    expect(bundle.requested, contains('assets/portfolio/close.svg'));
    expect(bundle.requested, contains('assets/portfolio/chevron-right.svg'));
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('trade-mode-settings')), findsNothing);
    await close(t, c);
  });

  testWidgets('existing asset bundle renders verified activation success and close icons', (
    t,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestFuturesAssetModeRepository()..context = marketContext([isolated]);
    final c = setup(
      t,
      identityRepository: identity,
      futuresAssetModeRepository: repository,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    final bundle = ExistingPortfolioBundle();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: DefaultAssetBundle(bundle: bundle, child: const VantaApp()),
      ),
    );
    await t.pumpAndSettle();
    await c.read(futuresAssetModeProvider.notifier).load();
    showModeSettingsSheet<void>(
      t.element(find.byType(Navigator).first),
      const MultiAssetActivationSheet(),
    );
    await t.pumpAndSettle();
    repository.context = marketContext([cross]);
    await c.read(futuresAssetModeProvider.notifier).load();
    await t.pumpAndSettle();
    expect(bundle.requested, contains('assets/portfolio/notification-success.svg'));
    expect(find.text('Requirements met'), findsOneWidget);
    expect(t.takeException(), null);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('multi-asset-activation-sheet')), findsNothing);
    await close(t, c);
  });

  testWidgets('settings opens the designed asset and position sheets without navigation reads', (
    t,
  ) async {
    final assets = TestFuturesAssetModeRepository();
    final positions = TestFuturesPositionModeRepository();
    final c = setup(
      t,
      futuresAssetModeRepository: assets,
      futuresPositionModeRepository: positions,
      language: const Locale('en'),
    );
    await launch(t, c);
    await tap(t, 'trade-settings');
    expect(find.text('Account Settings'), findsOneWidget);
    expect(find.byKey(const Key('settings-asset-mode')), findsOneWidget);
    expect(find.byKey(const Key('settings-position-mode')), findsOneWidget);
    await tap(t, 'settings-asset-mode');
    expect(find.byKey(const Key('asset-mode-sheet')), findsOneWidget);
    expect(find.byKey(const Key('asset-mode-single')), findsOneWidget);
    expect(find.byKey(const Key('asset-mode-multi')), findsOneWidget);
    expect(assets.reads, 0);
    await tap(t, 'asset-mode-sheet-read');
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(assets.changes, 0);
    expect(positions.changes, 0);
    await close(t, c);
  });

  testWidgets('multi activation moves through blocked, resolving and verified Cross states', (
    t,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestFuturesAssetModeRepository()
      ..context = marketContext([
        const AssetModeMarket(
          symbol: 'ETHUSDT',
          marginMode: PositionMarginMode.isolated,
          hasPosition: true,
          hasCollateral: false,
        ),
      ]);
    final c = setup(
      t,
      identityRepository: identity,
      futuresAssetModeRepository: repository,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    await launch(t, c);
    final controller = c.read(futuresAssetModeProvider.notifier);
    await controller.load();
    openAssetModeSettings(t.element(find.byType(Navigator).first));
    await t.pumpAndSettle();
    await tap(t, 'asset-mode-multi');
    expect(find.text('Open position'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(action(t, 'multi-asset-confirm').onPressed, null);
    expect(repository.changes, 0);
    repository.context = marketContext([isolated]);
    await controller.load();
    await t.pumpAndSettle();
    expect(find.text('Switch to Cross'), findsOneWidget);
    expect(find.text('No open positions or orders'), findsOneWidget);
    expect(action(t, 'multi-asset-confirm').onPressed, null);
    repository.context = marketContext([cross]);
    await controller.load();
    await t.pumpAndSettle();
    expect(find.text('Requirements met'), findsOneWidget);
    expect(find.text('ETHUSDT'), findsOneWidget);
    expect(action(t, 'multi-asset-confirm').onPressed, isNotNull);
    repository.changeGate = Completer<void>();
    await t.tap(find.byKey(const Key('multi-asset-confirm')));
    await t.pump();
    expect(repository.changes, 1);
    expect(action(t, 'multi-asset-confirm').onPressed, null);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await t.tap(find.byKey(const Key('multi-asset-confirm')));
    expect(repository.changes, 1);
    repository.changeGate!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('multi-asset-activation-sheet')), findsNothing);
    expect(c.read(futuresAssetModeProvider).result?.observed, FuturesAssetMode.multi);
    expect(t.takeException(), null);
    await close(t, c);
  });

  testWidgets('negative USDT prevents a single-asset write and reports the design error', (
    t,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final r = TestFuturesAssetModeRepository()
      ..context = assetModeContext(
        current: FuturesAssetMode.multi,
        usdt: Decimal.parse('-0.000000000000000001'),
      );
    final c = setup(
      t,
      identityRepository: identity,
      futuresAssetModeRepository: r,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    await launch(t, c);
    await c.read(futuresAssetModeProvider.notifier).load();
    openAssetModeSettings(t.element(find.byType(Navigator).first));
    await t.pumpAndSettle();
    await tap(t, 'asset-mode-single');
    expect(find.textContaining('Your available USDT assets are negative'), findsOneWidget);
    expect(r.changes, 0);
    await close(t, c);
  });

  testWidgets('position sheet uses one-way and hedge and enforces positions and order blockers', (
    t,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final r = TestFuturesPositionModeRepository()..context = positionModeContext(orders: 1);
    final c = setup(
      t,
      identityRepository: identity,
      futuresPositionModeRepository: r,
      positionModeClock: () => positionModeClock,
      language: const Locale('en'),
    );
    await launch(t, c);
    await c.read(futuresPositionModeProvider.notifier).load();
    openPositionModeSettings(t.element(find.byType(Navigator).first));
    await t.pumpAndSettle();
    expect(find.text('One-way'), findsOneWidget);
    expect(find.text('Hedge'), findsOneWidget);
    await tap(t, 'position-mode-hedge');
    expect(
      find.textContaining('Close all open positions and cancel all open orders'),
      findsOneWidget,
    );
    expect(r.changes, 0);
    r.context = positionModeContext();
    await c.read(futuresPositionModeProvider.notifier).load();
    await t.pumpAndSettle();
    await tap(t, 'position-mode-hedge');
    expect(r.changes, 1);
    expect(c.read(futuresPositionModeProvider).result?.observed, FuturesPositionMode.hedge);
    expect(find.byKey(const Key('position-mode-sheet')), findsNothing);
    await close(t, c);
  });

  testWidgets('unknown outcome survives reopening and recheck never repeats the write', (t) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final r = TestFuturesAssetModeRepository()
      ..result = const AssetModeResult(failure: AccountReadFailure('accountNetwork'));
    final c = setup(
      t,
      identityRepository: identity,
      futuresAssetModeRepository: r,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    await launch(t, c);
    await c.read(futuresAssetModeProvider.notifier).load();
    openAssetModeSettings(t.element(find.byType(Navigator).first));
    await t.pumpAndSettle();
    await tap(t, 'asset-mode-multi');
    await tap(t, 'multi-asset-confirm');
    expect(c.read(futuresAssetModeProvider).needsRecheck, true);
    Navigator.pop(t.element(find.byKey(const Key('multi-asset-confirm'))));
    await t.pumpAndSettle();
    Navigator.pop(t.element(find.byKey(const Key('asset-mode-sheet'))));
    await t.pumpAndSettle();
    openAssetModeSettings(t.element(find.byType(Navigator).first));
    await t.pumpAndSettle();
    expect(find.textContaining('Querying never resubmits'), findsOneWidget);
    r.result = AssetModeResult(observed: FuturesAssetMode.multi, checkedAt: assetModeClock);
    await tap(t, 'asset-mode-sheet-read');
    expect(r.checks, 1);
    expect(r.changes, 1);
    expect(c.read(futuresAssetModeProvider).needsRecheck, false);
    await close(t, c);
  });

  testWidgets(
    'observed original mode stays on activation and explains that the change was not verified',
    (t) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final r = TestFuturesAssetModeRepository()
        ..result = AssetModeResult(observed: FuturesAssetMode.single, checkedAt: assetModeClock);
      final c = setup(
        t,
        identityRepository: identity,
        futuresAssetModeRepository: r,
        assetModeClock: () => assetModeClock,
        language: const Locale('en'),
      );
      await launch(t, c);
      await c.read(futuresAssetModeProvider.notifier).load();
      openAssetModeSettings(t.element(find.byType(Navigator).first));
      await t.pumpAndSettle();
      await tap(t, 'asset-mode-multi');
      await tap(t, 'multi-asset-confirm');
      expect(find.byKey(const Key('multi-asset-activation-sheet')), findsOneWidget);
      expect(find.textContaining('Query shows Single-Asset; requested Multi-Asset'), findsWidgets);
      expect(action(t, 'multi-asset-confirm').onPressed, null);
      expect(r.changes, 1);
      await close(t, c);
    },
  );

  testWidgets('active device grant loads mode on entry and pull refresh waits for failure', (
    t,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final store = MemoryTradingAgentStorage().store(DateTime.now);
    final agent = await store.prepare(
      signingIdentity.id,
      accountAddress,
      DateTime.now().add(const Duration(days: 30)),
    );
    await store.setStatus(agent, TradingAgentStatus.unknown);
    await store.setStatus(agent, TradingAgentStatus.active);
    final r = TestFuturesAssetModeRepository();
    final c = setup(
      t,
      identityRepository: identity,
      tradingAgentStore: store,
      futuresAssetModeRepository: r,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    await launch(t, c);
    openAssetModeSettings(t.element(find.byType(Navigator).first));
    await t.pumpAndSettle();
    expect(r.reads, 1);
    r.readGate = Completer<void>();
    r.readFailure = const AccountReadFailure('accountNetwork');
    final indicator = t.widget<RefreshIndicator>(
      find.descendant(
        of: find.byKey(const Key('asset-mode-sheet')),
        matching: find.byType(RefreshIndicator),
      ),
    );
    var completed = false;
    final refresh = indicator.onRefresh().then((_) => completed = true);
    await t.pump();
    expect(r.reads, 2);
    expect(completed, false);
    expect(find.byKey(const Key('asset-mode-single')), findsOneWidget);
    r.readGate!.complete();
    await refresh;
    await t.pumpAndSettle();
    expect(completed, true);
    expect(c.read(futuresAssetModeProvider).context, isNotNull);
    expect(find.byType(ModeError), findsOneWidget);
    expect(r.changes, 0);
    await close(t, c);
  });

  testWidgets('late read from a replaced account cannot submit or keep selection busy', (t) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final r = TestFuturesAssetModeRepository()..readGate = Completer<void>();
    final c = setup(
      t,
      identityRepository: identity,
      futuresAssetModeRepository: r,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    await launch(t, c);
    openAssetModeSettings(t.element(find.byType(Navigator).first));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('asset-mode-multi')));
    await t.pump();
    expect(r.reads, 1);
    identity.events.add(
      const AuthIdentity(
        id: 'replacement',
        walletAddress: '0x3333333333333333333333333333333333333333',
        walletKind: WalletKind.external,
        signingAvailable: true,
      ),
    );
    await t.pump();
    r.readGate!.complete();
    await t.pumpAndSettle();
    expect(r.changes, 0);
    expect(c.read(futuresAssetModeProvider).context, null);
    expect(t.widget<ModeOptionCard>(find.byKey(const Key('asset-mode-multi'))).busy, false);
    expect(find.byKey(const Key('multi-asset-activation-sheet')), findsNothing);
    await close(t, c);
  });

  for (final hasPosition in [true, false]) {
    testWidgets('affected market opens matching management route: position=$hasPosition', (
      t,
    ) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final r = TestFuturesAssetModeRepository()
        ..context = marketContext([
          AssetModeMarket(
            symbol: 'ETHUSDT',
            marginMode: PositionMarginMode.isolated,
            hasPosition: hasPosition,
            hasCollateral: false,
          ),
        ]);
      final c = setup(
        t,
        identityRepository: identity,
        futuresAssetModeRepository: r,
        assetModeClock: () => assetModeClock,
        language: const Locale('en'),
      );
      await launch(t, c);
      await c.read(futuresAssetModeProvider.notifier).load();
      showModeSettingsSheet<void>(
        t.element(find.byType(Navigator).first),
        const MultiAssetActivationSheet(),
      );
      await t.pumpAndSettle();
      await t.tap(find.text(hasPosition ? 'Manage' : 'Switch to Cross'));
      await t.pumpAndSettle();
      if (hasPosition) {
        expect(t.widget<PositionRiskScreen>(find.byType(PositionRiskScreen)).symbol, 'ETHUSDT');
      } else {
        final screen = t.widget<PositionMarginModeScreen>(find.byType(PositionMarginModeScreen));
        expect(screen.symbol, 'ETHUSDT');
        expect(screen.initialTarget, PositionMarginMode.cross);
      }
      expect(r.changes, 0);
      expect(t.takeException(), null);
      await close(t, c);
    });
  }

  for (final spec in [(320.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('mode and activation sheets fit narrow, landscape and large text $spec', (t) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      addTearDown(identity.dispose);
      final r = TestFuturesAssetModeRepository()..context = marketContext([isolated]);
      final c = setup(
        t,
        width: spec.$1,
        scale: spec.$3,
        identityRepository: identity,
        futuresAssetModeRepository: r,
        assetModeClock: () => assetModeClock,
        language: Locale(spec.$4),
      );
      t.view.physicalSize = Size(spec.$1, spec.$2);
      await launch(t, c);
      await c.read(futuresAssetModeProvider.notifier).load();
      showModeSettingsSheet<void>(
        t.element(find.byType(Navigator).first),
        const MultiAssetActivationSheet(),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('multi-asset-confirm')));
      expect(t.takeException(), null);
      await close(t, c);
    });
  }
}
