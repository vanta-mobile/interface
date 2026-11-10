import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/presentation/status_view.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/funding/application/transfer_history_provider.dart';
import 'package:vanta/features/funding/presentation/transfer_history_screen.dart';
import 'package:vanta/features/funding/presentation/transfer_history_components.dart';
import 'package:vanta/features/funding/presentation/transfer_record_screen.dart';
import 'package:vanta/features/funding/presentation/transfer_history_skeleton.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/navigation_fixture.dart';
import '../../support/trade_fixture.dart';
import '../../support/trading_agents.dart';
import '../../support/transfers.dart';

Future<TradingAgentStore> activeStore() async {
  final store = MemoryTradingAgentStorage().store(DateTime.now);
  final agent = await store.prepare(
    signingIdentity.id,
    accountAddress,
    DateTime.now().add(const Duration(days: 30)),
  );
  await store.setStatus(agent, TradingAgentStatus.unknown);
  await store.setStatus(agent, TradingAgentStatus.active);
  return store;
}

Future<void> showControl(
  WidgetTester tester,
  Finder finder, {
  String list = 'transfer-history-list',
}) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.descendant(of: find.byKey(Key(list)), matching: find.byType(Scrollable)).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets(
      'history uses shared skeletons before loading and shared empty state after: $language',
      (tester) async {
        final identity = NavigationIdentity()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final gate = Completer<void>();
        final history = TestTransferHistoryRepository()
          ..gate = gate
          ..records = [];
        final container = setup(
          tester,
          language: Locale(language),
          width: 320,
          scale: 1.5,
          identityRepository: identity,
          transferHistoryRepository: history,
          tradingAgentStore: await activeStore(),
        );
        await launch(tester, container);
        await tapNavigationControl(tester, 'navigation-portfolio');
        await tester.tap(find.byKey(const Key('portfolio-history-entry')));
        await tester.pumpAndSettle();
        expect(container.read(transferHistoryProvider).busy, true);
        expect(find.byType(TransferHistorySkeleton), findsOneWidget);
        expect(find.byType(SkeletonBox), findsWidgets);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(StatusEmptyView), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.byType(TransferHistorySkeleton), findsNothing);
        expect(find.byType(StatusEmptyView), findsOneWidget);
        expect(find.byKey(const Key('status-empty')), findsOneWidget);
        // Switching filters uses the same shared empty state, with no request.
        await tester.tap(find.byKey(const Key('transfer-filter-withdraw')));
        await tester.pumpAndSettle();
        expect(find.byType(StatusEmptyView), findsOneWidget);
        expect(history.calls, 1);
        history.gate = Completer<void>();
        final refresh = container.read(transferHistoryProvider.notifier).refresh();
        await tester.pump();
        expect(find.byType(TransferHistorySkeleton), findsNothing);
        expect(find.byType(StatusEmptyView), findsOneWidget);
        history.gate!.complete();
        await refresh;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }

  for (final language in ['en', 'zh']) {
    testWidgets(
      'portfolio entry loads history; filters, five-row pages and details retain selection: $language',
      (tester) async {
        final identity = NavigationIdentity()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final history = TestTransferHistoryRepository()
          ..now = DateTime.now().toUtc()
          ..records = [
            for (var i = 0; i < 8; i++)
              transferRecord(
                id: 'record-$i',
                type: i == 0 ? 'WITHDRAW' : 'DEPOSIT',
                status: i == 0 ? 'SUCCESS' : 'PROCESSING',
              ),
          ];
        final container = setup(
          tester,
          language: Locale(language),
          identityRepository: identity,
          transferHistoryRepository: history,
          tradingAgentStore: await activeStore(),
        );
        await launch(tester, container);
        await tapNavigationControl(tester, 'navigation-portfolio');
        await tester.tap(find.byKey(const Key('portfolio-history-entry')));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(TransferHistoryScreen)));
        expect(history.calls, 1);
        expect(identity.signatures, 0);
        expect(find.text(l.transferHistoryScope), findsNothing);
        expect(find.text(l.transferBaselineCreated), findsNothing);
        expect(find.byKey(const Key('transfer-history-market')), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        final firstCard = find.byType(HistoryRecordCard).first;
        final firstStatus = find.descendant(of: firstCard, matching: find.byType(HistoryStatus));
        expect(
          tester.getTopRight(firstCard).dx - tester.getTopRight(firstStatus).dx,
          closeTo(16, .1),
        );
        final next = find.byKey(const Key('transfer-history-next'));
        await showControl(tester, next);
        expect(find.text('1 / 2'), findsOneWidget);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        final selected = find.byKey(ValueKey('transfer-${history.records.last.key}'));
        await showControl(tester, selected);
        await tester.tap(selected);
        await tester.pumpAndSettle();
        expect(find.byType(TransferRecordScreen), findsOneWidget);
        expect(find.text('0.000000000000000001 USDT'), findsOneWidget);
        expect(find.widgetWithText(SelectableText, l.assetHistoryUnavailable), findsOneWidget);
        expect(find.text(l.assetHistoryConfirmationUnavailable), findsOneWidget);
        expect(find.text(l.assetHistoryConfirmed), findsNothing);
        expect(find.text(l.assetHistoryDepositCompleted), findsNothing);
        expect(find.text(accountAddress), findsNothing);
        await tester.tap(find.byKey(const Key('transfer-details-back')));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        await tester.drag(find.byKey(const Key('transfer-history-list')), const Offset(0, 1000));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('transfer-filter-withdraw')));
        await tester.pumpAndSettle();
        expect(find.text(l.assetHistoryLoaded), findsOneWidget);
        expect(find.byKey(const Key('transfer-history-next')), findsNothing);
        expect(find.byKey(ValueKey('transfer-${history.records.first.key}')), findsOneWidget);
        expect(find.byKey(ValueKey('transfer-${history.records.last.key}')), findsNothing);
        expect(history.calls, 2); // drag above also refreshed, filters stay local
        await tester.tap(find.byKey(ValueKey('transfer-${history.records.first.key}')));
        await tester.pumpAndSettle();
        expect(find.text('−0.000000000000000001 USDT'), findsOneWidget);
        expect(find.text(l.assetHistoryWithdrawCompleted), findsOneWidget);
        await tester.tap(find.byKey(const Key('transfer-details-back')));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('transfer-${history.records.first.key}')), findsOneWidget);
        await tester.tap(find.byKey(const Key('transfer-history-close')));
        await tester.pumpAndSettle();
        expect(find.byType(TransferHistoryScreen), findsNothing);
        expect(find.byKey(const Key('portfolio-page')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }

  for (final size in [const Size(320, 700), const Size(844, 390), const Size(768, 1024)]) {
    testWidgets(
      'history and detail fit enlarged text $size; refresh retains rows and awaits in-flight read',
      (tester) async {
        final identity = NavigationIdentity()..restored = signingIdentity;
        addTearDown(identity.dispose);
        final history = TestTransferHistoryRepository()..now = DateTime.now().toUtc();
        final container = setup(
          tester,
          width: size.width,
          scale: 1.5,
          identityRepository: identity,
          transferHistoryRepository: history,
          tradingAgentStore: await activeStore(),
        );
        tester.view.physicalSize = size;
        await launch(tester, container);
        await tapNavigationControl(tester, 'navigation-portfolio');
        await tester.tap(find.byKey(const Key('portfolio-history-entry')));
        await tester.pumpAndSettle();
        final card = find.byKey(ValueKey('transfer-${history.records.single.key}'));
        await showControl(tester, card);
        expect(tester.takeException(), isNull);
        history.gate = Completer<void>();
        final pending = container.read(transferHistoryProvider.notifier).refresh();
        await tester.pump();
        final duplicate = container.read(transferHistoryProvider.notifier).refresh();
        var done = false;
        unawaited(duplicate.then((_) => done = true));
        await tester.pump();
        expect(done, false);
        expect(card, findsOneWidget);
        expect(find.byKey(const Key('transfer-history-loading')), findsNothing);
        history.failure = const AccountReadFailure('accountNetwork');
        history.gate!.complete();
        await Future.wait([pending, duplicate]);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('transfer-history-error')), findsOneWidget);
        await showControl(tester, card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        await showControl(
          tester,
          find.text('0.000000000000000001 USDT'),
          list: 'transfer-record-details',
        );
        expect(tester.takeException(), isNull);
        identity.events.add(null);
        await tester.pumpAndSettle();
        expect(find.text('0.000000000000000001 USDT'), findsNothing);
        expect(find.byKey(const Key('transfer-history-enable')), findsOneWidget);
        // Another wallet can return the same exchange record ID. An old detail
        // route must never turn into a view of that wallet's transfer.
        identity.restored = const AuthIdentity(
          id: 'other-owner',
          walletAddress: '0x3333333333333333333333333333333333333333',
          walletKind: WalletKind.external,
          signingAvailable: true,
        );
        await container.read(authProvider.notifier).bootstrap();
        await tester.pumpAndSettle();
        history.failure = null;
        history.gate = null;
        await container.read(transferHistoryProvider.notifier).refresh();
        await tester.pumpAndSettle();
        expect(container.read(transferHistoryProvider).account, isNotNull);
        expect(find.text('0.000000000000000001 USDT'), findsNothing);
        expect(identity.signatures, 0);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets('history without a device grant never signs or fetches on entry', (tester) async {
    final identity = NavigationIdentity()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final history = TestTransferHistoryRepository();
    final container = setup(
      tester,
      identityRepository: identity,
      transferHistoryRepository: history,
    );
    await launch(tester, container);
    await tapNavigationControl(tester, 'navigation-portfolio');
    await tester.tap(find.byKey(const Key('portfolio-history-entry')));
    await tester.pumpAndSettle();
    expect(history.calls, 0);
    expect(identity.signatures, 0);
    expect(find.byKey(const Key('transfer-history-enable')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });

  testWidgets('known deposit-required owner skips history without adding a prompt', (tester) async {
    final identity = NavigationIdentity()..restored = signingIdentity;
    addTearDown(identity.dispose);
    final accounts = TestAsterAccountRepository()
      ..failure = const AccountReadFailure('accountDepositRequired', code: -5050);
    final history = TestTransferHistoryRepository();
    final container = setup(
      tester,
      identityRepository: identity,
      asterAccountRepository: accounts,
      transferHistoryRepository: history,
      tradingAgentStore: await activeStore(),
    );
    await launch(tester, container);
    await tapNavigationControl(tester, 'navigation-portfolio');
    expect(accounts.calls, 1);
    await tester.tap(find.byKey(const Key('portfolio-history-entry')));
    await tester.pumpAndSettle();
    expect(history.calls, 0);
    expect(find.byKey(const Key('transfer-history-error')), findsNothing);
    expect(find.byKey(const Key('portfolio-deposit-required')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}
