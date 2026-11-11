import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';
import 'package:vanta/features/portfolio/application/futures_asset_mode_provider.dart';
import 'package:vanta/features/portfolio/application/position_leverage_provider.dart';
import 'package:vanta/features/portfolio/presentation/futures_asset_mode_screen.dart';
import 'package:vanta/features/portfolio/presentation/position_leverage_screen.dart';

import '../../support/aster_account.dart';
import '../../support/futures_asset_mode.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    Navigator.of(tester.element(find.byType(Navigator).first))
        .push<void>(MaterialPageRoute(builder: (_) => const FuturesAssetModeScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('asset-mode-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, {bool zh = false}) async {
    await visible(tester, 'asset-mode-target');
    await tester.tap(find.byKey(const Key('asset-mode-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh ? '多资产' : 'Multi-assets').last);
    await tester.pumpAndSettle();
  }

  Future<void> read(WidgetTester tester) async {
    await visible(tester, 'asset-mode-read');
    await tester.tap(find.byKey(const Key('asset-mode-read')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'signed-out entry opens actual email / EOA login without reading or creating wallets',
    (tester) async {
      final identity = TestIdentityRepository(), repository = TestFuturesAssetModeRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        futuresAssetModeRepository: repository,
      );
      await open(tester, container);
      await read(tester);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(repository.reads, 0);
      expect(repository.changes, 0);
      expect(identity.wallets, 0);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets(
    'confirmation binds wallet, symbol and both modes; cancel keeps selection without a change',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestFuturesAssetModeRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        futuresAssetModeRepository: repository,
        assetModeClock: () => assetModeClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await read(tester);
      await choose(tester);
      await visible(tester, 'asset-mode-review');
      await tester.tap(find.byKey(const Key('asset-mode-review')));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      for (final text in [accountAddress, 'All futures symbols', 'Single-asset', 'Multi-assets']) {
        expect(find.descendant(of: dialog, matching: find.text(text)), findsOneWidget);
      }
      expect(find.textContaining('ALL futures symbols'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.changes, 0);
      expect(container.read(futuresAssetModeProvider).result, null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets(
    'confirmed request submits once, preserves selection on failure and rechecks without submitting',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestFuturesAssetModeRepository()
        ..changeGate = Completer<void>()
        ..result = const AssetModeResult(failure: AccountReadFailure('accountNetwork'));
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        futuresAssetModeRepository: repository,
        assetModeClock: () => assetModeClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await read(tester);
      await choose(tester);
      await visible(tester, 'asset-mode-review');
      await tester.tap(find.byKey(const Key('asset-mode-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('asset-mode-confirm')));
      await tester.pump();
      expect(repository.changes, 1);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('asset-mode-review'))).onPressed,
        null,
      );
      repository.changeGate!.complete();
      await tester.pumpAndSettle();
      await visible(tester, 'asset-mode-target');
      expect(
        tester
            .widget<DropdownButtonFormField<FuturesAssetMode>>(
              find.byKey(const Key('asset-mode-target')),
            )
            .initialValue,
        FuturesAssetMode.multi,
      );
      await visible(tester, 'asset-mode-result');
      expect(find.textContaining('Querying never resubmits'), findsOneWidget);
      repository.result = AssetModeResult(
        observed: FuturesAssetMode.single,
        checkedAt: assetModeClock,
      );
      await visible(tester, 'asset-mode-recheck');
      await tester.tap(find.byKey(const Key('asset-mode-recheck')));
      await tester.pumpAndSettle();
      expect(repository.checks, 1);
      expect(repository.changes, 1);
      expect(
        find.textContaining('Query shows Single-asset; requested Multi-assets'),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets('isolated symbols explain multi-assets blocker and disable review', (tester) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestFuturesAssetModeRepository()
      ..context = assetModeContext(isolatedSymbols: ['ETHUSDT']);
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      futuresAssetModeRepository: repository,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    await open(tester, container);
    await read(tester);
    await choose(tester);
    expect(find.textContaining('These symbols have isolated positions'), findsOneWidget);
    expect(find.text('ETHUSDT'), findsOneWidget);
    await visible(tester, 'asset-mode-review');
    expect(tester.widget<FilledButton>(find.byKey(const Key('asset-mode-review'))).onPressed, null);
    expect(repository.changes, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('mode selection, confirmation and result fit $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestFuturesAssetModeRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        futuresAssetModeRepository: repository,
        assetModeClock: () => assetModeClock,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await open(tester, container);
      await read(tester);
      await choose(tester, zh: spec.$4 == 'zh');
      await visible(tester, 'asset-mode-review');
      await tester.tap(find.byKey(const Key('asset-mode-review')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('asset-mode-confirm')));
      await tester.tap(find.byKey(const Key('asset-mode-confirm')));
      await tester.pumpAndSettle();
      await visible(tester, 'asset-mode-result');
      expect(
        find.textContaining(
          spec.$4 == 'en' ? 'Query verified the requested asset mode' : '查询已核对目标资产模式',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  testWidgets('unknown mode change blocks leverage page with a concrete recovery hint', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestFuturesAssetModeRepository()
      ..result = const AssetModeResult(failure: AccountReadFailure('accountNetwork'));
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      futuresAssetModeRepository: repository,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    await open(tester, container);
    await read(tester);
    final controller = container.read(futuresAssetModeProvider.notifier);
    await controller.change(controller.prepare(FuturesAssetMode.multi)!);
    openLeverageSettings(tester.element(find.byType(Navigator).first), 'BTCUSDT');
    await tester.pumpAndSettle();
    expect(find.textContaining('Complete the pending futures setting'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('leverage-read'))).onPressed, null);
    expect(container.read(positionLeverageProvider).context, null);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets('stale refresh keeps selected mode and refused signature shows safe failure', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    final repository = TestFuturesAssetModeRepository()
      ..submit = false
      ..changeFailure = const AccountReadFailure('authWalletRejected');
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      futuresAssetModeRepository: repository,
      assetModeClock: () => assetModeClock,
      language: const Locale('en'),
    );
    await open(tester, container);
    await read(tester);
    await choose(tester);
    container.read(futuresAssetModeProvider.notifier).markStale();
    await tester.pumpAndSettle();
    await read(tester);
    await visible(tester, 'asset-mode-review');
    await tester.tap(find.byKey(const Key('asset-mode-review')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('asset-mode-confirm')));
    await tester.pumpAndSettle();
    await visible(tester, 'asset-mode-error');
    expect(find.byKey(const Key('asset-mode-error')), findsOneWidget);
    expect(container.read(futuresAssetModeProvider).needsRecheck, false);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
