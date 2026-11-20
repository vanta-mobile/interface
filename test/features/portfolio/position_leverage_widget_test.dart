import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/presentation/mode_settings_sheet.dart';
import 'package:vanta/features/portfolio/presentation/position_leverage_sheet.dart';
import 'package:vanta/features/portfolio/application/position_leverage_provider.dart';

import '../../support/aster_account.dart';
import '../../support/position_leverage.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';

void main() {
  final sheet = find.byKey(const Key('leverage-sheet'));

  Future<void> open(WidgetTester tester, ProviderContainer container, {bool settle = true}) async {
    await launch(tester, container);
    await awaitTradingAgent(tester, container);
    unawaited(openLeverageSettings(tester.element(find.byType(Navigator).first), 'BTCUSDT'));
    // Skeletons animate, so a pending read pumps a fixed time.
    settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  String value(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('leverage-value'))).data!;

  VoidCallback? pressed(WidgetTester tester, String key) => tester
      .widget<FilledButton>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)),
      )
      .onPressed;

  /// Signed in with an active device trading grant, so the sheet reads itself.
  Future<ProviderContainer> signedIn(
    WidgetTester tester,
    TestPositionLeverageRepository repository, {
    Locale language = const Locale('en'),
  }) async {
    final identity = TestIdentityRepository()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final store = await activeAgentStore();
    return setup(
      tester,
      identityRepository: identity,
      tradingAgentStore: store,
      positionLeverageRepository: repository,
      leverageClock: () => leverageClock,
      language: language,
    );
  }

  testWidgets('signed-out read opens actual login and never creates a wallet or sends writes', (
    tester,
  ) async {
    final identity = TestIdentityRepository(), repository = TestPositionLeverageRepository();
    addTearDown(identity.dispose);
    final container = setup(
      tester,
      identityRepository: identity,
      positionLeverageRepository: repository,
    );
    await open(tester, container);
    expect(find.byKey(const Key('leverage-confirm')), findsNothing);
    await tap(tester, 'mode-access-action');
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(repository.reads, 0);
    expect(repository.changes, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('designed stepper, stops and notional cap follow the signed brackets', (
    tester,
  ) async {
    final repository = TestPositionLeverageRepository();
    final container = await signedIn(tester, repository);
    await open(tester, container);
    expect(find.text('BTCUSDT Adjust leverage'), findsOneWidget);
    expect(repository.reads, 1); // read on entry with the trading grant
    expect(value(tester), '10');
    // Brackets allow up to 100x: stops at 1, 26, 51, 75 and 100.
    for (final label in ['1x', '26x', '51x', '75x', '100x']) {
      expect(find.text(label), findsOneWidget);
    }
    final notional = find.byKey(const Key('leverage-notional'));
    expect(find.text('Remaining openable notional value'), findsOneWidget);
    // Bracket cap at 10x (100,000) less the 2,500 position notional.
    expect(find.descendant(of: notional, matching: find.text('97,500 USDT')), findsOneWidget);
    await tap(tester, 'leverage-decrease');
    expect(value(tester), '9');
    for (var i = 0; i < 2; i++) {
      await tap(tester, 'leverage-increase');
    }
    expect(value(tester), '11');
    // Dragging to the far right reaches the maximum, whose bracket caps lower.
    final slider = find.byKey(const Key('leverage-slider'));
    await tester.tapAt(tester.getTopRight(slider) + const Offset(-1, 12));
    await tester.pumpAndSettle();
    expect(value(tester), '100');
    expect(find.descendant(of: notional, matching: find.text('7,500 USDT')), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('leverage-increase'))).onPressed, isNull);
    // Stops are only marks: a point between them selects that leverage.
    // 10% along the track, between the first two stops.
    await tester.tapAt(
      tester.getTopLeft(slider) + Offset(6 + (tester.getSize(slider).width - 12) * 0.1, 12),
    );
    await tester.pumpAndSettle();
    expect(value(tester), '11');
    expect(repository.changes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('confirm submits the selected leverage once and closes when verified', (
    tester,
  ) async {
    final repository = TestPositionLeverageRepository()..changeGate = Completer<void>();
    final container = await signedIn(tester, repository);
    await open(tester, container);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const Key('leverage-increase')));
      await tester.pump();
    }
    expect(value(tester), '20');
    await tester.tap(find.byKey(const Key('leverage-confirm')));
    await tester.pump();
    expect(repository.changes, 1);
    expect(pressed(tester, 'leverage-confirm'), isNull);
    repository.changeGate!.complete();
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(container.read(positionLeverageProvider).result?.observed, 20);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('confirming the current leverage closes without a change', (tester) async {
    final repository = TestPositionLeverageRepository();
    final container = await signedIn(tester, repository);
    await open(tester, container);
    await tap(tester, 'leverage-confirm');
    expect(sheet, findsNothing);
    expect(repository.changes, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('an unverified change is queried automatically; a failed query is an error', (
    tester,
  ) async {
    final repository = TestPositionLeverageRepository()
      ..result = const LeverageResult(failure: AccountReadFailure('accountNetwork'))
      ..checkResult = const LeverageResult(failure: AccountReadFailure('accountNetwork'));
    final container = await signedIn(tester, repository);
    await open(tester, container);
    await tap(tester, 'leverage-increase');
    await tap(tester, 'leverage-confirm');
    expect(repository.changes, 1);
    expect(repository.checks, 1);
    expect(sheet, findsOneWidget);
    expect(find.byType(ModeError), findsOneWidget);
    expect(find.textContaining('No change is resubmitted'), findsNothing);
    // The sheet stays usable: nothing is locked behind a manual re-check.
    expect(pressed(tester, 'leverage-confirm'), isNotNull);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('leverage-increase'))).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('account values are skeletons while the first read is pending', (tester) async {
    final repository = TestPositionLeverageRepository()..readGate = Completer<void>();
    final container = await signedIn(tester, repository);
    await open(tester, container, settle: false);
    expect(find.byKey(const Key('leverage-value-pending')), findsOneWidget);
    expect(find.byKey(const Key('leverage-value')), findsNothing);
    expect(pressed(tester, 'leverage-confirm'), isNull);
    repository.readGate!.complete();
    await tester.pumpAndSettle();
    expect(value(tester), '10');
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('expired read refreshes before signing; refusal shows a safe failure', (
    tester,
  ) async {
    final repository = TestPositionLeverageRepository()
      ..submit = false
      ..changeFailure = const AccountReadFailure('authWalletRejected');
    final container = await signedIn(tester, repository);
    await open(tester, container);
    await tap(tester, 'leverage-increase');
    container.read(positionLeverageProvider.notifier).markStale();
    await tester.pumpAndSettle();
    expect(value(tester), '11'); // the selection survives expiry
    await tap(tester, 'leverage-confirm');
    expect(repository.reads, 2);
    expect(repository.changes, 1);
    expect(find.byType(ModeError), findsOneWidget);
    expect(repository.checks, 0); // nothing was sent, nothing to verify
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('stepper, stops and confirmation fit $spec', (tester) async {
      final repository = TestPositionLeverageRepository();
      final container = await signedIn(tester, repository, language: Locale(spec.$4));
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      tester.platformDispatcher.textScaleFactorTestValue = spec.$3;
      await open(tester, container);
      await tap(tester, 'leverage-increase');
      await tap(tester, 'leverage-confirm');
      expect(repository.changes, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
