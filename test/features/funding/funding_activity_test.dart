import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/application/wallet_operation_provider.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/core/presentation/app_toast.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/application/deposit_submission_provider.dart';
import 'package:vanta/features/funding/application/funding_activity_provider.dart';
import 'package:vanta/features/funding/application/funding_activity_poll_provider.dart';
import 'package:vanta/features/funding/application/funding_flow_provider.dart';
import 'package:vanta/features/funding/application/transfer_history_provider.dart';
import 'package:vanta/features/funding/data/deposit_submission_journal.dart';
import 'package:vanta/features/funding/domain/deposit_quote_validation.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';
import 'package:vanta/features/funding/domain/deposit_submission.dart';
import 'package:vanta/features/funding/domain/funding_activity.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/funding/presentation/portfolio_funding_activity.dart';
import 'package:vanta/features/funding/presentation/transfer_record_screen.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_submission.dart';
import '../../support/deposit_wallet.dart';
import '../../support/identity_repository.dart';
import '../../support/notifications.dart';
import '../../support/transfers.dart';

void main() {
  late ProviderContainer c;
  late TestIdentityRepository identity;
  late TestTransferHistoryRepository history;
  late LocalNotificationRepository inbox;
  late MemoryDepositSubmissionJournal deposits;
  late MemoryWalletOperationJournal withdrawals;
  late TestDepositReceiptRepository receipts;
  var closedContainer = false;
  WalletOperationRecord localWithdrawal() => WalletOperationRecord(
    kind: WalletOperationKind.withdrawal,
    address: accountAddress,
    nonce: 1793620800123000,
    preparedAt: DateTime.utc(2025, 3, 17),
    terms: {
      'chain': '56',
      'market': 'perp',
      'asset': 'USDT',
      'amount': '0.000000000000000001',
      'fee': '0',
      'receiver': accountAddress,
    },
  );
  Future<void> start(
    WidgetTester tester, {
    bool silentReads = true,
    bool restoredWithdrawal = false,
  }) async {
    closedContainer = false;
    identity = TestIdentityRepository()..restored = signingIdentity;
    history = TestTransferHistoryRepository();
    inbox = LocalNotificationRepository(MemoryNotificationStorage());
    deposits = MemoryDepositSubmissionJournal();
    withdrawals = MemoryWalletOperationJournal();
    if (restoredWithdrawal) {
      final r = localWithdrawal();
      await withdrawals.prepare(r);
      await withdrawals.report(r.key, '1234567');
    }
    receipts = TestDepositReceiptRepository();
    c = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        transferHistoryRepositoryProvider.overrideWithValue(history),
        notificationRepositoryProvider.overrideWithValue(inbox),
        depositSubmissionJournalProvider.overrideWithValue(deposits),
        walletOperationJournalProvider.overrideWithValue(withdrawals),
        depositSubmissionReceiptRepositoryProvider.overrideWithValue(receipts),
        fundingSilentReadsProvider.overrideWithValue(silentReads),
      ],
    );
    c.read(authProvider);
    await tester.pump();
    c.read(fundingActivityProvider);
    await tester.pump();
    addTearDown(() async {
      AppToast.dismiss();
      if (!closedContainer) c.dispose();
      await identity.dispose();
      await inbox.dispose();
      await deposits.close();
      await withdrawals.close();
    });
  }

  FundingActivityState state() => c.read(fundingActivityProvider);
  Future<void> read() => c.read(transferHistoryProvider.notifier).refresh();
  DepositSubmissionRecord localDeposit() {
    final now = DateTime.utc(2025, 3, 17), query = depositQuery();
    final quote = gasQuote(query: query, receivedAt: now);
    return DepositSubmissionRecord(
      query: query,
      kind: quote.transaction.kind,
      amountUnits: quote.transaction.amountUnits,
      transaction: validatedDepositQuote(
        quote: quote,
        address: accountAddress,
        query: query,
        amount: '1',
        now: now,
      ),
      preparedAt: now,
      baseBlock: quote.wallet.blockNumber,
      baseBlockHash: quote.wallet.blockHash,
      hash: '0x${'b' * 64}',
    );
  }

  testWidgets('unknown attempts stay invisible; the same late hash displays and completes once', (
    tester,
  ) async {
    await start(tester);
    final template = localDeposit();
    DepositSubmissionRecord attempt(String id) => DepositSubmissionRecord(
      query: template.query,
      kind: template.kind,
      amountUnits: template.amountUnits,
      transaction: template.transaction,
      preparedAt: template.preparedAt,
      baseBlock: template.baseBlock,
      baseBlockHash: template.baseBlockHash,
      attemptId: id * 32,
    );
    final first = attempt('a'), second = attempt('b');
    await deposits.prepare(first);
    await deposits.prepare(second);
    await tester.pump();
    expect(state().pending, isEmpty);
    await deposits.attachHash(second.key, template.hash!);
    await tester.pump();
    expect(state().pending, hasLength(1));
    await deposits.attachHash(first.key, template.hash!);
    await tester.pump();
    expect(state().pending, hasLength(1));
    receipts.result = DepositApprovalReceipt(
      hash: template.hash!,
      bound: true,
      status: DepositReceiptStatus.reverted,
      confirmations: 2,
      blockNumber: template.baseBlock,
    );
    final controller = c.read(depositSubmissionProvider.notifier);
    await controller.check(first.key, '');
    await controller.check(second.key, '');
    await tester.pump();
    expect(state().pending, isEmpty);
    expect(state().completions, hasLength(1));
  });
  testWidgets('without an active device grant polling never requests wallet signing', (
    tester,
  ) async {
    await start(tester, silentReads: false);
    final sub = c.listen(fundingActivityPollProvider(true), (_, _) {});
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    expect(history.calls, 0);
    expect(identity.wallets, 0);
    sub.close();
    c.dispose();
    closedContainer = true;
  });
  for (final credited in [true, false]) {
    testWidgets('canonical deposit polling resolves ${credited ? 'credit' : 'reversion'} once', (
      tester,
    ) async {
      await start(tester);
      final d = localDeposit();
      await deposits.prepare(d);
      await tester.pump();
      receipts.result = DepositApprovalReceipt(
        hash: d.hash!,
        bound: true,
        matchesIntent: true,
        status: credited ? DepositReceiptStatus.succeeded : DepositReceiptStatus.reverted,
        confirmations: 2,
        blockNumber: d.baseBlock,
      );
      history.records = credited
          ? [
              TransferRecord(
                id: 'local',
                market: d.query.market,
                type: TransferType.deposit,
                status: TransferStatus.success,
                asset: d.query.asset.asset,
                amount: state().pending.single.amount,
                recordTime: d.preparedAt,
                chainId: d.query.asset.chainId,
                txHash: d.hash,
              ),
            ]
          : [];
      await c.read(refreshFundingActivityProvider)();
      expect(state().pending, isEmpty);
      expect(
        state().completions.single.status,
        credited ? TransferStatus.success : TransferStatus.failed,
      );
      expect(deposits.snapshot.records, isEmpty);
      await c.read(refreshFundingActivityProvider)();
      expect(state().completions, hasLength(1));
    });
  }

  for (final terminal in ['SUCCESS', 'FAILED']) {
    testWidgets('pending survives missing history and errors; $terminal completes once', (
      tester,
    ) async {
      await start(tester);
      await read();
      expect(state().pending, hasLength(1));
      history.failure = const AccountReadFailure('accountNetwork');
      await read();
      expect(state().pending, hasLength(1));
      expect(state().completions, isEmpty);
      history.failure = null;
      history.records = [];
      await read();
      expect(state().pending, hasLength(1));
      history.records = [transferRecord(status: terminal)];
      await read();
      expect(state().pending, isEmpty);
      expect(state().completions.single.status.name, terminal.toLowerCase());
      c
          .read(fundingActivityProvider.notifier)
          .acknowledgeCompletion(state().completions.single.activity.key);
      await read();
      history.records = [transferRecord()]; // A stale regression cannot revive it.
      await read();
      expect(state().pending, isEmpty);
      expect(state().completions, isEmpty);
    });
  }
  testWidgets('historical completions are silent; changed transfer terms cannot settle progress', (
    tester,
  ) async {
    await start(tester);
    history.records = [transferRecord(status: 'SUCCESS')];
    await read();
    expect(state().completions, isEmpty);
    history.records = [transferRecord()];
    await read();
    history.records = [
      TransferRecord(
        id: '1234567',
        market: TransferMarket.perp,
        type: TransferType.deposit,
        status: TransferStatus.success,
        asset: 'BNB',
        amount: history.records.single.amount,
        recordTime: history.records.single.recordTime,
        chainId: 56,
      ),
    ];
    await read();
    expect(state().pending, hasLength(1));
    expect(state().completions, isEmpty);
  });
  testWidgets('exact withdrawal reference deduplicates local and API records', (tester) async {
    await start(tester);
    final r = localWithdrawal();
    await withdrawals.prepare(r);
    await withdrawals.report(r.key, '1234567');
    await tester.pump();
    history.records = [transferRecord(type: 'WITHDRAW')];
    await read();
    expect(state().pending, hasLength(1));
    expect(state().pending.single.withdrawal?.reference, '1234567');
    history.records = [transferRecord(type: 'WITHDRAW', status: 'SUCCESS')];
    await read();
    expect(state().pending, isEmpty);
    expect(state().completions, hasLength(1));
    await read();
    expect(state().completions, hasLength(1));
  });
  testWidgets('restored completed withdrawal is silent across identity sessions', (tester) async {
    await start(tester, restoredWithdrawal: true);
    history.records = [transferRecord(type: 'WITHDRAW', status: 'SUCCESS')];
    await read();
    expect(state().pending, isEmpty);
    expect(state().completions, isEmpty);
    expect(withdrawals.snapshot.records, hasLength(1));
  });
  testWidgets('new local withdrawal finishing before first history still notifies', (tester) async {
    await start(tester);
    final r = localWithdrawal();
    await withdrawals.prepare(r);
    await tester.pump();
    await withdrawals.report(r.key, '1234567');
    await tester.pump();
    history.records = [transferRecord(type: 'WITHDRAW', status: 'SUCCESS')];
    await read();
    expect(state().pending, isEmpty);
    expect(state().completions.single.status, TransferStatus.success);
  });
  testWidgets('deposit remains pending until exact platform result and deduplicates the hash', (
    tester,
  ) async {
    await start(tester);
    final now = DateTime.utc(2025, 3, 17), query = depositQuery();
    final quote = gasQuote(query: query, receivedAt: now);
    final d = DepositSubmissionRecord(
      query: query,
      kind: quote.transaction.kind,
      amountUnits: quote.transaction.amountUnits,
      transaction: validatedDepositQuote(
        quote: quote,
        address: accountAddress,
        query: query,
        amount: '1',
        now: now,
      ),
      preparedAt: now,
      baseBlock: quote.wallet.blockNumber,
      baseBlockHash: quote.wallet.blockHash,
      hash: '0x${'b' * 64}',
    );
    await deposits.prepare(d);
    await tester.pump();
    expect(state().pending.single.deposit?.key, d.key);
    history.records = [
      TransferRecord(
        id: '1234567',
        market: TransferMarket.perp,
        type: TransferType.deposit,
        status: TransferStatus.processing,
        asset: 'USDT',
        amount: state().pending.single.amount,
        recordTime: now,
        chainId: 56,
        txHash: d.hash,
      ),
    ];
    await read();
    expect(state().pending, hasLength(1));
    expect(state().completions, isEmpty);
    final r = history.records.single;
    history.records = [
      TransferRecord(
        id: r.id,
        market: r.market,
        type: r.type,
        status: TransferStatus.failed,
        asset: r.asset,
        amount: r.amount,
        recordTime: r.recordTime,
        chainId: r.chainId,
        txHash: r.txHash,
      ),
    ];
    await read();
    expect(state().pending, isEmpty);
    expect(state().completions.single.status, TransferStatus.failed);
    expect(deposits.snapshot.records, hasLength(1)); // No inferred journal deletion.
  });
  testWidgets('identity change clears progress and rejects late old-owner reads', (tester) async {
    await start(tester);
    await read();
    history.gate = Completer<void>();
    final pending = read();
    identity.events.add(
      const AuthIdentity(
        id: 'another',
        walletAddress: '0x3333333333333333333333333333333333333333',
        signingAvailable: true,
      ),
    );
    await tester.pump();
    history.gate!.complete();
    await pending;
    expect(state().pending, isEmpty);
    expect(state().completions, isEmpty);
  });

  for (final locale in ['en', 'zh']) {
    testWidgets('design card polls to final toast and stops; enlarged $locale', (tester) async {
      await start(tester);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: vantaTheme(),
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: PortfolioFundingActivity(hidden: false)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(history.calls, 1);
      expect(find.text(locale == 'en' ? 'Deposit processing' : '充值处理中'), findsOneWidget);
      history.records = [transferRecord(status: locale == 'en' ? 'SUCCESS' : 'FAILED')];
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(state().pending, isEmpty);
      expect(find.byKey(const Key('app-toast')), findsOneWidget);
      expect(find.text(locale == 'en' ? 'Deposit successful' : '充值失败'), findsOneWidget);
      expect(history.calls, 2);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(history.calls, 2);
      expect(find.byKey(const Key('app-toast')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      closedContainer = true;
    });
  }
  testWidgets('route navigation and background pause polling; pull callers await shared refresh', (
    tester,
  ) async {
    await start(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: vantaTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: PortfolioFundingActivity(hidden: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(ValueKey('portfolio-funding-history:${history.records.single.key}'));
    history.records = [];
    await read();
    await tester.pump();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(TransferRecordScreen), findsOneWidget);
    expect(find.text('Processing'), findsOneWidget);
    final calls = history.calls;
    await tester.pump(const Duration(seconds: 11));
    expect(history.calls, calls);
    Navigator.of(tester.element(find.byType(TransferRecordScreen))).pop();
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = history.calls;
    await tester.pump(const Duration(seconds: 11));
    expect(history.calls, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    history.gate = Completer<void>();
    final first = c.read(refreshFundingActivityProvider)(),
        second = c.read(refreshFundingActivityProvider)();
    var ended = false;
    unawaited(Future.wait([first, second]).then((_) => ended = true));
    await tester.pump();
    expect(ended, false);
    history.gate!.complete();
    await tester.pumpAndSettle();
    expect(ended, true);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    closedContainer = true;
  });
}
