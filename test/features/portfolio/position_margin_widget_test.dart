import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/portfolio/application/position_margin_provider.dart';
import 'package:vanta/features/portfolio/application/position_margin_storage_provider.dart';
import 'package:vanta/features/portfolio/domain/position_margin_adjustment.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';
import 'package:vanta/features/portfolio/presentation/position_margin_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/identity_repository.dart';
import '../../support/position_margin_adjustment.dart';

void main() {
  late ProviderContainer container;
  late TestIdentityRepository identity;
  late TestPositionMarginRepository repository;
  late MemoryWalletOperationJournal journal;
  late DateTime now;
  var disposed = false;
  setUp(() {
    disposed = false;
    identity = TestIdentityRepository()..restored = signingIdentity;
    repository = TestPositionMarginRepository();
    journal = MemoryWalletOperationJournal();
    now = marginClock;
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        positionMarginRepositoryProvider.overrideWithValue(repository),
        positionMarginJournalProvider.overrideWithValue(journal),
        positionMarginClockProvider.overrideWithValue(() => now),
        positionMarginReferenceProvider.overrideWithValue(() => marginReference),
      ],
    );
  });
  tearDown(() async {
    if (!disposed) container.dispose();
    await identity.dispose();
    await journal.close();
  });
  Future<void> open(WidgetTester tester, {bool zh = false, Widget? home}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale(zh ? 'zh' : 'en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home ?? const PositionMarginScreen(symbol: 'BTCUSDT', side: 'BOTH'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    disposed = true;
  }

  Future<void> visible(WidgetTester tester, String key) async {
    final scroll = find
        .descendant(
          of: find.byKey(const Key('margin-adjust-page')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('margin-adjust-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> read(WidgetTester tester) async {
    await visible(tester, 'margin-adjust-read');
    await tester.tap(find.byKey(const Key('margin-adjust-read')));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String text) async {
    await visible(tester, 'margin-adjust-amount');
    await tester.enterText(find.byKey(const Key('margin-adjust-amount')), text);
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester) async {
    await visible(tester, 'margin-adjust-review');
    await tester.tap(find.byKey(const Key('margin-adjust-review')));
    await tester.pumpAndSettle();
  }

  Future<void> chooseRemove(WidgetTester tester, {bool zh = false}) async {
    final finder = find.byWidgetPredicate((w) => w is DropdownButtonFormField<MarginDirection>);
    tester.testTextInput.hide();
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh ? '移除保证金' : 'Remove margin').last);
    await tester.pumpAndSettle();
  }

  testWidgets('entry has no automatic read, default Add and empty amount; Max floors to 2dp', (
    tester,
  ) async {
    await open(tester);
    expect(repository.reads, 0);
    expect(identity.wallets, 0);
    await read(tester);
    await visible(tester, 'margin-adjust-amount');
    expect(
      tester.widget<TextField>(find.byKey(const Key('margin-adjust-amount'))).controller!.text,
      '',
    );
    await visible(tester, 'margin-adjust-max');
    await tester.tap(find.byKey(const Key('margin-adjust-max')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(const Key('margin-adjust-amount'))).controller!.text,
      '80.00',
    );
    await chooseRemove(tester);
    expect(
      tester.widget<TextField>(find.byKey(const Key('margin-adjust-amount'))).controller!.text,
      '80.00',
    );
    expect(find.text('Amount exceeds the available limit.'), findsOneWidget);
    await visible(tester, 'margin-adjust-review');
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('margin-adjust-review'))).onPressed,
      null,
    );
    await cleanup(tester);
  });
  testWidgets('review exposes exact original terms; cancelling preserves input and sends nothing', (
    tester,
  ) async {
    await open(tester);
    await read(tester);
    await enter(tester, '10');
    await review(tester);
    final dialog = find.byType(AlertDialog);
    for (final text in [accountAddress, 'BTCUSDT · BOTH', marginReference, '10 USDT']) {
      expect(find.descendant(of: dialog, matching: find.text(text)), findsOneWidget);
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.changes, 0);
    expect(
      tester.widget<TextField>(find.byKey(const Key('margin-adjust-amount'))).controller!.text,
      '10',
    );
    await cleanup(tester);
  });
  testWidgets('failed signing keeps amount; verified success clears only original amount', (
    tester,
  ) async {
    await open(tester);
    await read(tester);
    await enter(tester, '10');
    repository.failure = const AccountReadFailure('authWalletRejected');
    await review(tester);
    await tester.tap(find.byKey(const Key('margin-adjust-confirm')));
    await tester.pumpAndSettle();
    await visible(tester, 'margin-adjust-amount');
    expect(
      tester.widget<TextField>(find.byKey(const Key('margin-adjust-amount'))).controller!.text,
      '10',
    );
    repository.failure = null;
    await read(tester);
    repository.result = MarginAdjustmentResult(
      record: marginRecord(acknowledged: true, reference: marginReference),
      verified: true,
      context: repository.context,
      position: repository.context.position,
    );
    await review(tester);
    await tester.tap(find.byKey(const Key('margin-adjust-confirm')));
    await tester.pumpAndSettle();
    await visible(tester, 'margin-adjust-amount');
    expect(
      tester.widget<TextField>(find.byKey(const Key('margin-adjust-amount'))).controller!.text,
      '',
    );
    expect(repository.changes, 2);
    await cleanup(tester);
  });
  testWidgets('verified adjustment with refreshed account closes pushed page', (tester) async {
    await open(
      tester,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openPositionMargin(context, symbol: 'BTCUSDT', side: 'BOTH'),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await read(tester);
    await enter(tester, '10');
    final c = repository.context;
    repository.result = MarginAdjustmentResult(
      record: marginRecord(acknowledged: true, reference: marginReference),
      verified: true,
      context: c,
      position: c.position,
      account: c.account,
      positions: PositionRiskSnapshot(
        address: accountAddress,
        receivedAt: marginClock,
        positions: [c.position],
      ),
    );
    await review(tester);
    await tester.tap(find.byKey(const Key('margin-adjust-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(PositionMarginScreen), findsNothing);
    expect(repository.changes, 1);
    expect(find.text('Exact adjustment found in Aster history.'), findsOneWidget);
    await cleanup(tester);
  });
  testWidgets('expired dialog confirmation does not submit', (tester) async {
    await open(tester);
    await read(tester);
    await enter(tester, '10');
    await review(tester);
    now = now.add(const Duration(seconds: 30));
    await tester.tap(find.byKey(const Key('margin-adjust-confirm')));
    await tester.pumpAndSettle();
    expect(repository.changes, 0);
    await cleanup(tester);
  });
  testWidgets('logout removes old amount and position without creating wallet', (tester) async {
    await open(tester);
    await read(tester);
    await enter(tester, '10');
    await container.read(authProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('margin-adjust-amount')), findsNothing);
    expect(identity.wallets, 0);
    await cleanup(tester);
  });
  testWidgets(
    'startup pending record remains reachable without any open position; explicit check only',
    (tester) async {
      await journal.prepare(marginRecord());
      await open(tester, home: const PositionMarginScreen());
      expect(repository.reads, 0);
      expect(repository.checks, 0);
      expect(find.byKey(const Key('margin-adjust-read')), findsNothing);
      final check = find.byKey(ValueKey('margin-adjust-check-${marginRecord().key}'));
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(repository.checks, 1);
      expect(repository.changes, 0);
      await cleanup(tester);
    },
  );

  for (final zh in [false, true]) {
    for (final size in [const Size(320, 740), const Size(844, 390), const Size(768, 1024)]) {
      testWidgets('${zh ? 'ZH' : 'EN'} $size enlarged text form and review no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await open(tester, zh: zh);
        await read(tester);
        await enter(tester, '0.00000001');
        await chooseRemove(tester, zh: zh);
        await review(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), null);
        await tester.tap(find.text(zh ? '取消' : 'Cancel'));
        await tester.pumpAndSettle();
        await cleanup(tester);
      });
    }
  }
}
