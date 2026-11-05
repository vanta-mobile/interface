import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';
import 'package:vanta/features/funding/application/deposit_approval_provider.dart';
import 'package:vanta/features/funding/application/deposit_submission_provider.dart';
import 'package:vanta/features/funding/application/deposit_gas_provider.dart';
import 'package:vanta/features/funding/application/funding_catalog_provider.dart';
import 'package:vanta/features/funding/application/transfer_history_provider.dart';
import 'package:vanta/features/funding/data/deposit_submission_codec.dart';
import 'package:vanta/features/funding/data/deposit_submission_journal.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_approval.dart';
import '../../support/deposit_submission.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_wallet.dart';
import '../../support/funding_info.dart';
import '../../support/transfers.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8), query = depositQuery(), hash = '0x${'b' * 64}';
  late DateTime now;
  late ProviderContainer c;
  late ApprovalIdentityRepository identity;
  late TestDepositGasRepository gas;
  late TestDepositReceiptRepository receipts;
  late GatedDepositJournal journal;
  late TestFundingCatalogRepository catalog;
  late TestTransferHistoryRepository history;
  DepositSubmissionController controller() => c.read(depositSubmissionProvider.notifier);
  DepositSubmissionState state() => c.read(depositSubmissionProvider);
  void flow(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      now = time;
      identity = ApprovalIdentityRepository()..restored = signingIdentity;
      gas = TestDepositGasRepository()..result = gasQuote(query: query, receivedAt: now);
      receipts = TestDepositReceiptRepository();
      journal = GatedDepositJournal();
      catalog = TestFundingCatalogRepository()..rows = [fundingAssetRow()..['minDeposit'] = '0.1'];
      history = TestTransferHistoryRepository()..now = now;
      c = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          depositGasRepositoryProvider.overrideWithValue(gas),
          depositGasClockProvider.overrideWithValue(() => now),
          depositSubmissionJournalProvider.overrideWithValue(journal),
          depositSubmissionReceiptRepositoryProvider.overrideWithValue(receipts),
          fundingCatalogRepositoryProvider.overrideWithValue(catalog),
          transferHistoryRepositoryProvider.overrideWithValue(history),
        ],
      );
      c.read(authProvider);
      c.read(depositSubmissionProvider);
      await tester.pump();
      try {
        await body(tester);
      } finally {
        c.dispose();
        await journal.close();
        await identity.dispose();
      }
    });
  }

  Future<DepositSubmissionReview> review() async =>
      (await controller().prepare(query, '1', acknowledgeUnknownLimits: true))!;
  void successfulReceipt({
    String? value,
    bool matches = true,
    DepositReceiptStatus status = DepositReceiptStatus.succeeded,
    int confirmations = 2,
  }) {
    receipts.result = DepositApprovalReceipt(
      hash: value ?? hash,
      bound: true,
      matchesIntent: matches,
      status: status,
      confirmations: confirmations,
      blockNumber: BigInt.from(123),
    );
  }

  TransferRecord credit({
    String? value,
    String asset = 'USDT',
    int chain = 56,
    String amount = '1',
    TransferMarket market = TransferMarket.perp,
    TransferStatus status = TransferStatus.success,
  }) => TransferRecord(
    id: 'credit-1',
    market: market,
    type: TransferType.deposit,
    status: status,
    asset: asset,
    amount: Decimal.parse(amount),
    recordTime: now,
    chainId: chain,
    txHash: value ?? hash,
  );
  flow(
    'deposit persists exact unsigned transaction before EOA dispatch, no additional wallet or automatic retry',
    (t) async {
      final r = await review();
      expect(identity.transactions, isEmpty);
      identity.beforeSend = () async {
        expect(journal.snapshot.records.single.transaction.parameters, r.transaction.parameters);
      };
      await controller().confirm(r);
      expect(identity.transactions.single.data.startsWith('0xcf4a0c5e'), true);
      expect(identity.wallets, 0);
      expect(journal.snapshot.records.single.hash, hash);
      expect(gas.calls.length, 2);
      expect(catalog.calls.length, 2);
      await controller().confirm(r);
      expect(identity.transactions.length, 1);
    },
  );
  flow('unknown platform caps require explicit external verification acknowledgement', (t) async {
    expect(await controller().prepare(query, '1', acknowledgeUnknownLimits: false), null);
    expect(gas.calls, isEmpty);
    expect(state().failure, 'depositLimitsAcknowledgement');
  });
  flow('pending approval blocks deposit before fresh reads', (t) async {
    await c.read(depositApprovalJournalProvider).prepare(approvalRecord(now: now));
    expect(await controller().prepare(query, '1', acknowledgeUnknownLimits: true), null);
    expect(state().failure, 'depositApprovalPending');
    expect(gas.calls, isEmpty);
    expect(identity.transactions, isEmpty);
  });
  flow('pending deposit blocks approval preparation before wallet prompt', (t) async {
    await controller().confirm(await review());
    final approval = c.read(depositApprovalProvider.notifier);
    expect(await approval.prepare(query, '1'), null);
    expect(c.read(depositApprovalProvider).failure, 'depositSubmissionPending');
    expect(identity.transactions.length, 1);
  });
  flow('approval flush and deposit share dispatch lock even after stop', (t) async {
    gas.result = approvalQuote(now: now);
    final approval = c.read(depositApprovalProvider.notifier);
    final a = (await approval.prepare(query, '1'))!;
    gas.result = gasQuote(query: query, receivedAt: now);
    final d = await review();
    final approvalJournal = GatedApprovalJournal()..gate = Completer<void>();
    // Override only before creating a second container's controllers.
    final other = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(identity),
        depositGasRepositoryProvider.overrideWithValue(gas),
        depositGasClockProvider.overrideWithValue(() => now),
        depositApprovalJournalProvider.overrideWithValue(approvalJournal),
        fundingCatalogRepositoryProvider.overrideWithValue(catalog),
      ],
    );
    addTearDown(other.dispose);
    other.read(authProvider);
    await t.pump();
    gas.result = approvalQuote(now: now);
    final ac = other.read(depositApprovalProvider.notifier);
    final ar = (await ac.prepare(query, '1'))!;
    gas.result = gasQuote(query: query, receivedAt: now);
    final dc = other.read(depositSubmissionProvider.notifier);
    final dr = (await dc.prepare(query, '1', acknowledgeUnknownLimits: true))!;
    gas.result = approvalQuote(now: now);
    final pending = ac.confirm(ar);
    await t.pump();
    ac.stop();
    await dc.confirm(dr);
    expect(other.read(depositSubmissionProvider).failure, 'depositTransactionBusy');
    expect(identity.transactions, isEmpty);
    approvalJournal.gate!.complete();
    await pending;
    expect(identity.transactions, isEmpty);
    expect(approvalJournal.snapshot.records, isEmpty);
    // Reviews in the original scope remain unsigned.
    expect(a.transaction.from, d.transaction.from);
  });
  flow('externally verified missing minimum survives review and submission journal', (t) async {
    final base = depositQuery(minimum: null),
        q = DepositWalletQuery(
          market: base.market,
          asset: base.asset,
          verifiedMinimumDeposit: Decimal.parse('0.25'),
        );
    catalog.rows = [fundingAssetRow()..remove('minDeposit')];
    gas.result = gasQuote(query: q, receivedAt: now);
    final r = (await controller().prepare(q, '1', acknowledgeUnknownLimits: true))!;
    await controller().confirm(r);
    final restored = decodeSubmissionJournal(encodeSubmissionJournal(journal.snapshot.records))
        .single;
    expect(restored.query.verifiedMinimumDeposit, Decimal.parse('0.25'));
    expect(identity.transactions.length, 1);
  });
  flow('insufficient allowance requires separate approval and sends no deposit', (t) async {
    gas.result = approvalQuote(now: now);
    expect(await controller().prepare(query, '1', acknowledgeUnknownLimits: true), null);
    expect(identity.transactions, isEmpty);
  });
  flow('fresh catalog removal prevents Gas request and signing', (t) async {
    catalog.rows = [];
    expect(await controller().prepare(query, '1', acknowledgeUnknownLimits: true), null);
    expect(gas.calls, isEmpty);
    expect(identity.transactions, isEmpty);
  });
  flow('catalog change during review stops submission', (t) async {
    final r = await review();
    catalog.rows = [];
    await controller().confirm(r);
    expect(identity.transactions, isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
  flow('Gas or nonce change during review requires a new review', (t) async {
    final r = await review();
    gas.result = gasQuote(query: query, receivedAt: now, nonce: BigInt.from(8));
    await controller().confirm(r);
    expect(identity.transactions, isEmpty);
    expect(state().failure, 'depositSubmissionChanged');
  });
  flow('failed durable prepare prevents opening wallet', (t) async {
    final r = await review();
    journal.prepareFailure = const AccountReadFailure('depositSubmissionStorage');
    await controller().confirm(r);
    expect(identity.transactions, isEmpty);
  });
  flow('known-not-sent transaction removes only pre-dispatch record', (t) async {
    final r = await review();
    identity.transactionFailure = const WalletTransactionNotSent('walletTransactionWrongChain');
    await controller().confirm(r);
    expect(journal.snapshot.records, isEmpty);
    expect(state().failure, 'walletTransactionWrongChain');
  });
  flow('structured wallet rejection clears reservation without claiming execution', (t) async {
    final r = await review();
    identity.transactionResult = const WalletTransactionResult.rejected();
    await controller().confirm(r);
    expect(journal.snapshot.records, isEmpty);
    expect(state().failure, 'authWalletRejected');
  });
  flow('unknown response remains durable and blocks another deposit', (t) async {
    final r = await review();
    identity.transactionResult = const WalletTransactionResult.unknown();
    await controller().confirm(r);
    expect(journal.snapshot.records.single.hash, null);
    expect(await controller().prepare(query, '1', acknowledgeUnknownLimits: true), null);
    expect(identity.transactions.length, 1);
  });
  flow('scope loss during flush removes unsubmitted record', (t) async {
    final r = await review();
    journal.gate = Completer();
    final future = controller().confirm(r);
    await t.pump();
    identity.events.add(null);
    await t.pump();
    journal.gate!.complete();
    await future;
    expect(identity.transactions, isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
  flow('late wallet response after stop retains hash in original-wallet journal', (t) async {
    final r = await review();
    identity.transactionGate = Completer();
    final future = controller().confirm(r);
    await t.pump();
    controller().stop();
    identity.transactionGate!.complete();
    await future;
    expect(journal.snapshot.records.single.hash, hash);
    expect(state().record, null);
  });
  flow('chain success stays pending without platform credit', (t) async {
    await controller().confirm(await review());
    successfulReceipt();
    await controller().check(journal.snapshot.records.single.key, '');
    expect(journal.snapshot.records.length, 1);
    expect(state().credited, false);
    expect(history.calls, 0);
  });
  flow('exact signed SUCCESS credit resolves deposit after canonical chain receipt', (t) async {
    await controller().confirm(await review());
    successfulReceipt();
    history.records = [credit()];
    await controller().checkCredit(journal.snapshot.records.single.key);
    expect(state().credited, true);
    expect(journal.snapshot.records, isEmpty);
    expect(history.calls, 1);
  });
  for (final variant in [
    'hash',
    'amount',
    'market',
    'chain',
    'asset',
    'processing',
    'failed',
    'address',
  ]) {
    flow('credit mismatch $variant never clears pending deposit', (t) async {
      await controller().confirm(await review());
      successfulReceipt();
      history.records = [
        credit(
          value: variant == 'hash' ? '0x${'d' * 64}' : null,
          asset: variant == 'asset' ? 'BNB' : 'USDT',
          chain: variant == 'chain' ? 1 : 56,
          amount: variant == 'amount' ? '1.000000000000000001' : '1',
          market: variant == 'market' ? TransferMarket.spot : TransferMarket.perp,
          status: variant == 'processing'
              ? TransferStatus.processing
              : variant == 'failed'
              ? TransferStatus.failed
              : TransferStatus.success,
        ),
      ];
      if (variant == 'address') {
        history.returnedAddress = '0x3333333333333333333333333333333333333333';
      }
      await controller().checkCredit(journal.snapshot.records.single.key);
      expect(state().credited, false);
      expect(journal.snapshot.records.length, 1);
    });
  }
  flow('matching speedup hash can confirm credit without replacing original saved hash', (t) async {
    await controller().confirm(await review());
    final speedup = '0x${'e' * 64}';
    successfulReceipt(value: speedup);
    history.records = [credit(value: speedup)];
    await controller().checkCredit(journal.snapshot.records.single.key, candidate: speedup);
    expect(state().credited, true);
    expect(journal.snapshot.records, isEmpty);
  });
  flow('one confirmation or replaced intent never queries platform history', (t) async {
    await controller().confirm(await review());
    successfulReceipt(confirmations: 1);
    final key = journal.snapshot.records.single.key;
    await controller().checkCredit(key);
    expect(history.calls, 0);
    successfulReceipt(matches: false);
    await controller().checkCredit(key);
    expect(history.calls, 0);
    expect(journal.snapshot.records.length, 1);
  });
  flow('persisted deposit round trip covers calldata beyond approval length', (t) async {
    await controller().confirm(await review());
    final records = decodeSubmissionJournal(encodeSubmissionJournal(journal.snapshot.records));
    expect(records.single.transaction.data.length, 266);
    expect(
      records.single.transaction.parameters,
      journal.snapshot.records.single.transaction.parameters,
    );
  });
  flow('file-backed deposit survives process restart', (t) async {
    await controller().confirm(await review());
    await t.runAsync(() async {
      final d = await Directory.systemTemp.createTemp('vanta-deposit-test-');
      try {
        final a = FileDepositSubmissionJournal(() async => d);
        await a.reload();
        await a.prepare(journal.snapshot.records.single);
        await a.close();
        final b = FileDepositSubmissionJournal(() async => d);
        await b.reload();
        expect(b.snapshot.records.single.hash, hash);
        await b.close();
      } finally {
        await d.delete(recursive: true);
      }
    });
  });
}
