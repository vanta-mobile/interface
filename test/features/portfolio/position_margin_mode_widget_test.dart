import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/authorization/presentation/enable_trading_screen.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';
import 'package:vanta/features/portfolio/application/position_margin_mode_provider.dart';
import 'package:vanta/features/portfolio/application/position_leverage_provider.dart';
import 'package:vanta/features/portfolio/presentation/mode_settings_sheet.dart';
import 'package:vanta/features/portfolio/presentation/position_margin_mode_sheet.dart';
import 'package:vanta/features/portfolio/presentation/position_leverage_sheet.dart';

import '../../support/aster_account.dart';
import '../../support/position_leverage.dart';
import '../../support/position_margin_mode.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';

void main() {
  final sheet = find.byKey(const Key('margin-mode-sheet'));

  Future<void> open(WidgetTester tester, ProviderContainer container, {bool settle = true}) async {
    await launch(tester, container);
    await awaitTradingAgent(tester, container);
    unawaited(openMarginModeSettings(tester.element(find.byType(Navigator).first), 'BTCUSDT'));
    // Skeletons and busy spinners animate, so pending states pump a fixed time.
    settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  ModeOptionCard card(WidgetTester tester, String key) =>
      tester.widget<ModeOptionCard>(find.byKey(Key(key)));

  VoidCallback? pressed(WidgetTester tester, String key) => tester
      .widget<FilledButton>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)),
      )
      .onPressed;

  /// Signed in with an active device trading grant, so the sheet reads itself.
  Future<ProviderContainer> trading(
    WidgetTester tester,
    TestPositionMarginModeRepository repository, {
    Locale language = const Locale('en'),
    TestPositionLeverageRepository? leverage,
  }) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final store = await activeAgentStore();
    return setup(
      tester,
      identityRepository: identity,
      tradingAgentStore: store,
      positionMarginModeRepository: repository,
      marginModeClock: () => marginModeClock,
      positionLeverageRepository: leverage,
      leverageClock: () => leverageClock,
      language: language,
    );
  }

  testWidgets('designed sheet reads on entry and shows Cross selected without extra copy', (
    tester,
  ) async {
    final repository = TestPositionMarginModeRepository();
    final container = await trading(tester, repository);
    await open(tester, container);
    expect(find.text('BTCUSDT Margin mode'), findsOneWidget);
    expect(find.text('Margin mode changes apply only to this contract'), findsOneWidget);
    expect(find.textContaining('Shares available margin across cross positions'), findsOneWidget);
    expect(find.textContaining('Uses separate margin for each position'), findsOneWidget);
    expect(repository.reads, 1);
    expect(card(tester, 'margin-mode-cross').selected, isTrue);
    expect(card(tester, 'margin-mode-isolated').selected, isFalse);
    expect(find.text('Refresh settings'), findsNothing);
    expect(find.byKey(const Key('margin-mode-confirm')), findsOneWidget);
    expect(repository.changes, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('the current mode is a skeleton while the first read is pending', (tester) async {
    final repository = TestPositionMarginModeRepository()..readGate = Completer<void>();
    final container = await trading(tester, repository);
    await open(tester, container, settle: false);
    expect(card(tester, 'margin-mode-cross').loading, isTrue);
    expect(card(tester, 'margin-mode-isolated').loading, isTrue);
    expect(pressed(tester, 'margin-mode-confirm'), isNull);
    repository.readGate!.complete();
    await tester.pumpAndSettle();
    expect(card(tester, 'margin-mode-cross').loading, isFalse);
    expect(card(tester, 'margin-mode-cross').selected, isTrue);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('signed-out action opens actual login without reading or creating wallets', (
    tester,
  ) async {
    final identity = TestIdentityRepository(), repository = TestPositionMarginModeRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      positionMarginModeRepository: repository,
    );
    await launch(tester, container);
    unawaited(openMarginModeSettings(tester.element(find.byType(Navigator).first), 'BTCUSDT'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('margin-mode-confirm')), findsNothing);
    await tap(tester, 'mode-access-action');
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(repository.reads, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('without trading authorization the action opens Enable trading, never reads', (
    tester,
  ) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final repository = TestPositionMarginModeRepository();
    final container = setup(
      tester,
      identityRepository: identity,
      positionMarginModeRepository: repository,
      language: const Locale('en'),
    );
    await launch(tester, container);
    await awaitTradingAgent(tester, container);
    unawaited(openMarginModeSettings(tester.element(find.byType(Navigator).first), 'BTCUSDT'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('mode-access-action')),
        matching: find.text('Enable trading'),
      ),
      findsOneWidget,
    );
    await tap(tester, 'mode-access-action');
    expect(find.byType(EnableTradingScreen), findsOneWidget);
    expect(repository.reads, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('confirming the current mode closes without a change', (tester) async {
    final repository = TestPositionMarginModeRepository();
    final container = await trading(tester, repository);
    await open(tester, container);
    await tap(tester, 'margin-mode-confirm');
    expect(sheet, findsNothing);
    expect(repository.changes, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('confirm submits once and closes on a verified result', (tester) async {
    final repository = TestPositionMarginModeRepository()..changeGate = Completer<void>();
    final container = await trading(tester, repository);
    await open(tester, container);
    await tap(tester, 'margin-mode-isolated');
    await tester.tap(find.byKey(const Key('margin-mode-confirm')));
    await tester.pump();
    expect(repository.changes, 1);
    expect(pressed(tester, 'margin-mode-confirm'), isNull); // busy, no duplicate submit
    repository.changeGate!.complete();
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(
      container.read(positionMarginModeProvider).result?.observed,
      PositionMarginMode.isolated,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('an unverified change is queried automatically, then succeeds or errors', (
    tester,
  ) async {
    final repository = TestPositionMarginModeRepository()
      ..result = const MarginModeResult(failure: AccountReadFailure('accountNetwork'))
      ..checkResult = MarginModeResult(
        observed: PositionMarginMode.isolated,
        checkedAt: marginModeClock,
      );
    final container = await trading(tester, repository);
    await open(tester, container);
    await tap(tester, 'margin-mode-isolated');
    await tap(tester, 'margin-mode-confirm');
    expect(repository.checks, 1);
    expect(sheet, findsNothing); // verified: success
    unawaited(openMarginModeSettings(tester.element(find.byType(Navigator).first), 'BTCUSDT'));
    await tester.pumpAndSettle();
    repository
      ..context = marginModeContext(current: PositionMarginMode.isolated)
      ..checkResult = const MarginModeResult(failure: AccountReadFailure('accountNetwork'));
    await container.read(positionMarginModeProvider.notifier).load('BTCUSDT');
    await tester.pumpAndSettle();
    await tap(tester, 'margin-mode-cross');
    await tap(tester, 'margin-mode-confirm');
    expect(repository.changes, 2);
    expect(repository.checks, 2);
    expect(sheet, findsOneWidget);
    expect(find.byType(ModeError), findsOneWidget); // the query's own error
    expect(find.textContaining('unverified'), findsNothing);
    expect(pressed(tester, 'margin-mode-confirm'), isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('positions or orders disable the other mode with one merged reason', (tester) async {
    final repository = TestPositionMarginModeRepository()
      ..context = marginModeContext(hasPosition: true, orders: 1);
    final container = await trading(tester, repository);
    await open(tester, container);
    expect(card(tester, 'margin-mode-isolated').disabled, isTrue);
    expect(card(tester, 'margin-mode-isolated').onTap, isNull);
    expect(card(tester, 'margin-mode-cross').disabled, isFalse);
    expect(
      find.text(
        'This contract has open positions or orders. Close the positions and cancel the orders '
        'before switching margin mode.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ModeError), findsOneWidget);
    await tap(tester, 'margin-mode-confirm');
    expect(repository.changes, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('expired read refreshes before signing; refusal shows a safe failure', (
    tester,
  ) async {
    final repository = TestPositionMarginModeRepository()
      ..submit = false
      ..changeFailure = const AccountReadFailure('authWalletRejected');
    final container = await trading(tester, repository);
    await open(tester, container);
    await tap(tester, 'margin-mode-isolated');
    container.read(positionMarginModeProvider.notifier).markStale();
    await tester.pumpAndSettle();
    await tap(tester, 'margin-mode-confirm');
    expect(repository.reads, 2);
    expect(repository.changes, 1);
    expect(repository.checks, 0); // nothing was sent, nothing to verify
    expect(find.byType(ModeError), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('a margin change in progress does not block the leverage sheet', (tester) async {
    final repository = TestPositionMarginModeRepository()..changeGate = Completer<void>();
    final leverage = TestPositionLeverageRepository();
    final container = await trading(tester, repository, leverage: leverage);
    await open(tester, container);
    final controller = container.read(positionMarginModeProvider.notifier);
    final pending = controller.change(controller.prepare('BTCUSDT', PositionMarginMode.isolated)!);
    unawaited(openLeverageSettings(tester.element(find.byType(Navigator).first), 'BTCUSDT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(leverage.reads, 1);
    expect(container.read(positionLeverageProvider).context, isNotNull);
    expect(find.textContaining('pending futures setting'), findsNothing);
    repository.changeGate!.complete();
    await pending;
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('selection and confirmation fit $spec', (tester) async {
      final repository = TestPositionMarginModeRepository();
      final container = await trading(tester, repository, language: Locale(spec.$4));
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      tester.platformDispatcher.textScaleFactorTestValue = spec.$3;
      await open(tester, container);
      await tap(tester, 'margin-mode-isolated');
      await tap(tester, 'margin-mode-confirm');
      expect(repository.changes, 1);
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
