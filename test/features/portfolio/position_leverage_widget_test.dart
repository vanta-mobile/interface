import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_leverage.dart';
import 'package:vanta/features/portfolio/presentation/position_leverage_screen.dart';
import 'package:vanta/features/portfolio/application/position_leverage_provider.dart';

import '../../support/aster_account.dart';
import '../../support/position_leverage.dart';
import '../../support/identity_repository.dart';
import '../../support/trade_fixture.dart';

void main() {
  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    await launch(tester, container);
    openLeverageSettings(tester.element(find.byType(Navigator).first), 'BTCUSDT');
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      150,
      scrollable: find
          .descendant(of: find.byKey(const Key('leverage-page')), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String value) async {
    await visible(tester, 'leverage-target');
    await tester.enterText(find.byKey(const Key('leverage-target')), value);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(const Key('leverage-read')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(repository.reads, 0);
    expect(repository.changes, 0);
    expect(identity.wallets, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets(
    'review displays wallet, symbol, old and target leverage; cancelling sends no change',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestPositionLeverageRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        positionLeverageRepository: repository,
        leverageClock: () => leverageClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await tester.tap(find.byKey(const Key('leverage-read')));
      await tester.pumpAndSettle();
      await enter(tester, '20');
      await visible(tester, 'leverage-review');
      await tester.tap(find.byKey(const Key('leverage-review')));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text(accountAddress)), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('BTCUSDT')), findsOneWidget);
      expect(find.text('10× → 20×'), findsOneWidget);
      expect(find.textContaining('including both hedge directions'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.changes, 0);
      expect(
        tester.widget<TextField>(find.byKey(const Key('leverage-target'))).controller!.text,
        '20',
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  testWidgets(
    'explicit confirmation submits once; unknown result retains input and only rechecks',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestPositionLeverageRepository()
        ..changeGate = Completer<void>()
        ..result = const LeverageResult(failure: AccountReadFailure('accountNetwork'));
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        positionLeverageRepository: repository,
        leverageClock: () => leverageClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await tester.tap(find.byKey(const Key('leverage-read')));
      await tester.pumpAndSettle();
      await enter(tester, '20');
      await visible(tester, 'leverage-review');
      await tester.tap(find.byKey(const Key('leverage-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leverage-confirm')));
      await tester.pump();
      expect(repository.changes, 1);
      expect(tester.widget<FilledButton>(find.byKey(const Key('leverage-review'))).onPressed, null);
      repository.changeGate!.complete();
      await tester.pumpAndSettle();
      await visible(tester, 'leverage-target');
      expect(
        tester.widget<TextField>(find.byKey(const Key('leverage-target'))).controller!.text,
        '20',
      );
      await visible(tester, 'leverage-result');
      expect(find.textContaining('No change is resubmitted'), findsOneWidget);
      repository.result = LeverageResult(observed: 10, checkedAt: leverageClock);
      await visible(tester, 'leverage-recheck');
      await tester.tap(find.byKey(const Key('leverage-recheck')));
      await tester.pumpAndSettle();
      expect(repository.checks, 1);
      expect(repository.changes, 1);
      expect(find.textContaining('Query shows 10×; requested 20×'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
  for (final spec in [(360.0, 844.0, 2.0, 'en'), (844.0, 390.0, 1.5, 'zh')]) {
    testWidgets('localized leverage input, confirmation and result fit $spec', (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestPositionLeverageRepository();
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        width: spec.$1,
        scale: spec.$3,
        language: Locale(spec.$4),
        identityRepository: identity,
        positionLeverageRepository: repository,
        leverageClock: () => leverageClock,
      );
      tester.view.physicalSize = Size(spec.$1, spec.$2);
      await open(tester, container);
      await visible(tester, 'leverage-read');
      await tester.tap(find.byKey(const Key('leverage-read')));
      await tester.pumpAndSettle();
      await enter(tester, '1.5');
      expect(
        find.text(
          spec.$4 == 'en'
              ? 'Enter a different whole-number leverage within the displayed limit.'
              : '请输入显示范围内且不同于当前值的整数杠杆。',
        ),
        findsOneWidget,
      );
      await enter(tester, '20');
      await visible(tester, 'leverage-review');
      await tester.tap(find.byKey(const Key('leverage-review')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('leverage-confirm')));
      await tester.tap(find.byKey(const Key('leverage-confirm')));
      await tester.pumpAndSettle();
      await visible(tester, 'leverage-result');
      expect(
        find.textContaining(
          spec.$4 == 'en' ? 'Query verified the requested leverage' : '查询已核对目标杠杆',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
  testWidgets(
    'stale refresh preserves target; refused signature exposes a safe localized failure',
    (tester) async {
      final identity = TestIdentityRepository()..restored = signingIdentity;
      final repository = TestPositionLeverageRepository()
        ..submit = false
        ..changeFailure = const AccountReadFailure('authWalletRejected');
      addTearDown(identity.dispose);
      final container = setup(
        tester,
        identityRepository: identity,
        positionLeverageRepository: repository,
        leverageClock: () => leverageClock,
        language: const Locale('en'),
      );
      await open(tester, container);
      await tester.tap(find.byKey(const Key('leverage-read')));
      await tester.pumpAndSettle();
      await enter(tester, '20');
      container.read(positionLeverageProvider.notifier).markStale();
      await tester.pumpAndSettle();
      await visible(tester, 'leverage-read');
      await tester.tap(find.byKey(const Key('leverage-read')));
      await tester.pumpAndSettle();
      await visible(tester, 'leverage-target');
      expect(
        tester.widget<TextField>(find.byKey(const Key('leverage-target'))).controller!.text,
        '20',
      );
      await visible(tester, 'leverage-review');
      await tester.tap(find.byKey(const Key('leverage-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('leverage-confirm')));
      await tester.pumpAndSettle();
      await visible(tester, 'leverage-error');
      expect(find.byKey(const Key('leverage-error')), findsOneWidget);
      expect(repository.changes, 1);
      expect(container.read(positionLeverageProvider).needsRecheck, false);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}
