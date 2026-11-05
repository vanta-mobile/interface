import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/auth_provider.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_transaction.dart';
import 'package:vanta/features/funding/application/deposit_approval_provider.dart';
import 'package:vanta/features/funding/application/deposit_gas_provider.dart';
import 'package:vanta/features/funding/data/deposit_approval_codec.dart';
import 'package:vanta/features/funding/data/deposit_approval_journal.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_account.dart';
import '../../support/deposit_approval.dart';
import '../../support/deposit_gas.dart';
import '../../support/deposit_wallet.dart';

void main() {
  final time = DateTime.utc(2026, 11, 4, 8), query = depositQuery();
  final hash = '0x${'b' * 64}';
  const user = AuthIdentity(
    id: 'wallet',
    walletAddress: accountAddress,
    walletKind: WalletKind.external,
    signingAvailable: true,
  );
  late DateTime now;
  late ProviderContainer container;
  late ApprovalIdentityRepository identity;
  late TestDepositGasRepository gas;
  late TestApprovalReceiptRepository receipts;
  late GatedApprovalJournal journal;
  DepositApprovalController controller() => container.read(depositApprovalProvider.notifier);
  DepositApprovalState state() => container.read(depositApprovalProvider);
  void approvalTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      now = time;
      identity = ApprovalIdentityRepository()..restored = user;
      gas = TestDepositGasRepository()..result = approvalQuote(now: now);
      receipts = TestApprovalReceiptRepository();
      journal = GatedApprovalJournal();
      container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(identity),
          depositGasRepositoryProvider.overrideWithValue(gas),
          depositGasClockProvider.overrideWithValue(() => now),
          depositApprovalJournalProvider.overrideWithValue(journal),
          depositApprovalReceiptRepositoryProvider.overrideWithValue(receipts),
        ],
      );
      container.read(authProvider);
      container.read(depositApprovalProvider);
      await tester.pump();
      try {
        await body(tester);
      } finally {
        container.dispose();
        await journal.close();
        await identity.dispose();
      }
    });
  }

  Future<DepositApprovalReview> review() async => (await controller().prepare(query, '1'))!;
  approvalTest(
    'fresh explicit EOA review persists exact approval before dispatch, never creates wallet or auto-deposits',
    (tester) async {
      expect(gas.calls, isEmpty);
      final prepared = await review();
      expect(identity.transactions, isEmpty);
      identity.beforeSend = () async {
        expect(
          journal.snapshot.records.single.transaction.parameters,
          prepared.transaction.parameters,
        );
        expect(journal.snapshot.records.single.hash, null);
      };
      await controller().confirm(prepared);
      expect(gas.calls.length, 2);
      expect(identity.transactions.single.parameters, prepared.transaction.parameters);
      expect(journal.snapshot.records.single.hash, hash);
      expect(identity.wallets, 0);
      expect(receipts.calls, isEmpty);
      await controller().confirm(prepared);
      expect(identity.transactions.length, 1);
      expect(await controller().prepare(query, '1'), null);
      expect(state().failure, 'depositApprovalPending');
    },
  );
  approvalTest(
    'reset approval sends only zero; next step requires new balance read and confirmation',
    (tester) async {
      gas.result = approvalQuote(now: now, reset: true);
      final prepared = await review();
      await controller().confirm(prepared);
      expect(identity.transactions.single.data.endsWith('0' * 64), true);
      expect(identity.transactions.length, 1);
    },
  );
  approvalTest('cancel never writes or signs', (tester) async {
    final prepared = await review();
    controller().cancel(prepared);
    await controller().confirm(prepared);
    expect(journal.snapshot.records, isEmpty);
    expect(identity.transactions, isEmpty);
  });
  approvalTest('restored read-only EOA cannot prepare signing', (tester) async {
    identity.events.add(
      const AuthIdentity(
        id: 'wallet',
        walletAddress: accountAddress,
        walletKind: WalletKind.external,
      ),
    );
    await tester.pump();
    expect(await controller().prepare(query, '1'), null);
    expect(state().failure, 'authWalletReconnect');
    expect(gas.calls, isEmpty);
    expect(identity.wallets, 0);
  });
  for (final native in [false, true]) {
    approvalTest(
      'actual ${native ? 'native' : 'token'} deposit is blocked even if allowance is sufficient',
      (tester) async {
        final q = depositQuery(native: native);
        gas.result = gasQuote(query: q, receivedAt: now);
        expect(await controller().prepare(q, '1'), null);
        expect(state().failure, 'depositApprovalNotNeeded');
        expect(journal.snapshot.records, isEmpty);
        expect(identity.transactions, isEmpty);
      },
    );
  }
  for (final change in ['nonce', 'gasPrice', 'allowance']) {
    approvalTest('fresh $change change invalidates old review without send', (tester) async {
      final prepared = await review();
      gas.result = change == 'nonce'
          ? approvalQuote(now: now, nonce: BigInt.from(8))
          : change == 'allowance'
          ? approvalQuote(now: now, reset: true)
          : gasQuote(
              query: query,
              wallet: depositSnapshot(query: query, allowance: BigInt.zero, receivedAt: now),
              receivedAt: now,
              gasPrice: BigInt.from(2000000000),
            );
      await controller().confirm(prepared);
      expect(state().failure, 'depositApprovalChanged');
      expect(journal.snapshot.records, isEmpty);
      expect(identity.transactions, isEmpty);
    });
  }
  approvalTest('expired review cannot cause even a new estimate', (tester) async {
    final prepared = await review();
    now = now.add(const Duration(seconds: 30));
    await controller().confirm(prepared);
    expect(gas.calls.length, 1);
    expect(identity.transactions, isEmpty);
  });
  approvalTest('expiry while saving journal removes known-not-sent record', (tester) async {
    final prepared = await review();
    journal.gate = Completer();
    final pending = controller().confirm(prepared);
    await tester.pump();
    now = now.add(const Duration(seconds: 30));
    journal.gate!.complete();
    await pending;
    expect(journal.snapshot.records, isEmpty);
    expect(identity.transactions, isEmpty);
    expect(state().failure, 'depositReadStale');
  });
  approvalTest('storage failure before dispatch blocks sender', (tester) async {
    final prepared = await review();
    journal.prepareFailure = const AccountReadFailure('depositApprovalStorage');
    await controller().confirm(prepared);
    expect(state().failure, 'depositApprovalStorage');
    expect(identity.transactions, isEmpty);
  });
  for (final result in ['rejected', 'knownNotSent', 'unknown', 'thrown']) {
    approvalTest('$result distinguishes known-not-sent from uncertain dispatch', (tester) async {
      final prepared = await review();
      if (result == 'rejected') {
        identity.transactionResult = const WalletTransactionResult.rejected();
      }
      if (result == 'knownNotSent') {
        identity.transactionFailure = const WalletTransactionNotSent('authWalletChanged');
      }
      if (result == 'unknown') identity.transactionResult = const WalletTransactionResult.unknown();
      if (result == 'thrown') {
        identity.transactionFailure = const FormatException('private native detail');
      }
      await controller().confirm(prepared);
      expect(journal.snapshot.records.length, ['unknown', 'thrown'].contains(result) ? 1 : 0);
      expect(identity.transactions.length, 1);
      expect(state().failure, switch (result) {
        'rejected' => 'authWalletRejected',
        'knownNotSent' => 'authWalletChanged',
        _ => 'depositApprovalUnknown',
      });
    });
  }
  for (final change in ['stop', 'logout', 'dispose']) {
    approvalTest(
      'hash after $change stays under original wallet and duplicate dispatch is blocked',
      (tester) async {
        final prepared = await review();
        identity.transactionGate = Completer();
        final pending = controller().confirm(prepared);
        await tester.pump();
        expect(identity.transactions.length, 1);
        final originalController = controller();
        if (change == 'stop') originalController.stop();
        if (change == 'logout') identity.events.add(null);
        if (change == 'dispose') container.dispose();
        await tester.pump();
        if (change != 'dispose') {
          await originalController.confirm(prepared);
          expect(await originalController.prepare(query, '1'), null);
        }
        identity.transactionGate!.complete();
        await pending;
        expect(journal.snapshot.records.single.hash, hash);
        expect(journal.snapshot.records.single.transaction.from, accountAddress);
        expect(identity.transactions.length, 1);
      },
    );
  }
  approvalTest('stop during prepare discards late review and blocks overlap until completion', (
    tester,
  ) async {
    gas.gate = Completer();
    final pending = controller().prepare(query, '1');
    controller().stop();
    expect(await controller().prepare(query, '1'), null);
    gas.gate!.complete();
    expect(await pending, null);
    expect(state().review, null);
    expect(identity.transactions, isEmpty);
  });
  approvalTest('wallet change before durable save completes never dispatches', (tester) async {
    final prepared = await review();
    journal.gate = Completer();
    final pending = controller().confirm(prepared);
    await tester.pump();
    identity.events.add(null);
    await tester.pump();
    journal.gate!.complete();
    await pending;
    expect(identity.transactions, isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
  for (final outcome in [
    DepositReceiptStatus.succeeded,
    DepositReceiptStatus.reverted,
    DepositReceiptStatus.replaced,
  ]) {
    approvalTest(
      'read-only EOA can recover canonical $outcome without signing or submitting next step',
      (tester) async {
        final record = approvalRecord(now: now, hash: hash);
        await journal.prepare(record);
        identity.events.add(
          const AuthIdentity(
            id: 'wallet',
            walletAddress: accountAddress,
            walletKind: WalletKind.external,
          ),
        );
        await tester.pump();
        receipts.result = DepositApprovalReceipt(
          hash: hash,
          bound: true,
          matchesIntent: outcome != DepositReceiptStatus.replaced,
          status: outcome,
          confirmations: 2,
          blockNumber: record.baseBlock,
        );
        await controller().check(record.key, '');
        expect(journal.snapshot.records, isEmpty);
        expect(state().receipt!.status, outcome);
        expect(identity.transactions, isEmpty);
        expect(identity.wallets, 0);
        expect(gas.calls, isEmpty);
      },
    );
  }
  approvalTest(
    'manual original hash adopted only after matching transaction, pending stays blocked',
    (tester) async {
      final record = approvalRecord(now: now);
      await journal.prepare(record);
      await controller().check(record.key, hash);
      expect(journal.snapshot.records.single.hash, hash);
      expect(state().receipt!.status, DepositReceiptStatus.pending);
      expect(await controller().prepare(query, '1'), null);
      expect(identity.transactions, isEmpty);
    },
  );
  for (final intent in [true, false]) {
    approvalTest('unbound or replacement pending $intent never poisons original hash', (
      tester,
    ) async {
      final record = approvalRecord(now: now);
      await journal.prepare(record);
      receipts.result = DepositApprovalReceipt(
        hash: hash,
        bound: !intent,
        matchesIntent: intent,
        status: DepositReceiptStatus.pending,
      );
      await controller().check(record.key, hash);
      expect(journal.snapshot.records.single.hash, null);
    });
  }
  approvalTest(
    'stored hash can resolve through same-nonce cancellation candidate without overwriting original',
    (tester) async {
      final record = approvalRecord(now: now, hash: hash);
      await journal.prepare(record);
      final candidate = '0x${'c' * 64}';
      receipts.result = DepositApprovalReceipt(
        hash: candidate,
        bound: true,
        matchesIntent: false,
        status: DepositReceiptStatus.replaced,
        confirmations: 2,
        blockNumber: record.baseBlock,
      );
      await controller().check(record.key, candidate);
      expect(receipts.calls.single.$2, candidate);
      expect(state().record!.hash, hash);
      expect(journal.snapshot.records, isEmpty);
    },
  );
  for (final issue in [
    'unbound',
    'oneConfirmation',
    'noBlock',
    'oldBlock',
    'wrongHash',
    'wrongIntent',
    'falseReplacement',
  ]) {
    approvalTest('invalid terminal evidence $issue cannot clear unresolved record', (tester) async {
      final record = approvalRecord(now: now);
      await journal.prepare(record);
      receipts.result = DepositApprovalReceipt(
        hash: issue == 'wrongHash' ? '0x${'c' * 64}' : hash,
        bound: issue != 'unbound',
        status: issue == 'falseReplacement'
            ? DepositReceiptStatus.replaced
            : DepositReceiptStatus.succeeded,
        matchesIntent: issue != 'wrongIntent',
        confirmations: issue == 'oneConfirmation' ? 1 : 2,
        blockNumber: issue == 'noBlock'
            ? null
            : record.baseBlock - (issue == 'oldBlock' ? BigInt.one : BigInt.zero),
      );
      await controller().check(record.key, hash);
      expect(journal.snapshot.records.single.hash, null);
      expect(state().failure, 'depositRpcInvalid');
    });
  }
  approvalTest('receipt mismatch safe failure does not adopt candidate', (tester) async {
    final record = approvalRecord(now: now);
    await journal.prepare(record);
    receipts.failure = const AccountReadFailure('depositApprovalMismatch');
    await controller().check(record.key, hash);
    expect(journal.snapshot.records.single.hash, null);
    expect(state().failure, 'depositApprovalMismatch');
  });
  for (final change in ['stop', 'logout']) {
    approvalTest('late receipt after $change never clears or adopts hash', (tester) async {
      final record = approvalRecord(now: now);
      await journal.prepare(record);
      receipts.gate = Completer();
      final pending = controller().check(record.key, hash);
      if (change == 'stop') {
        controller().stop();
      } else {
        identity.events.add(null);
      }
      await tester.pump();
      receipts.gate!.complete();
      await pending;
      expect(journal.snapshot.records.single.hash, null);
      expect(state().receipt, null);
    });
  }
  approvalTest('other wallet record cannot be queried or displayed', (tester) async {
    final record = approvalRecord(now: now);
    await journal.prepare(record);
    identity.events.add(
      const AuthIdentity(id: 'other', walletAddress: '0x3333333333333333333333333333333333333333'),
    );
    await tester.pump();
    expect(container.read(pendingDepositApprovalsProvider), isEmpty);
    await controller().check(record.key, hash);
    expect(receipts.calls, isEmpty);
    expect(journal.snapshot.records.length, 1);
  });
  approvalTest(
    'host file is durable before wallet request, rebuild recovers hash without sending',
    (tester) async {
      await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp('vanta-approval-controller-');
        final disk = FileDepositApprovalJournal(() async => directory);
        await disk.reload();
        container.dispose();
        container = ProviderContainer(
          overrides: [
            identityRepositoryProvider.overrideWithValue(identity),
            depositGasRepositoryProvider.overrideWithValue(gas),
            depositGasClockProvider.overrideWithValue(() => now),
            depositApprovalJournalProvider.overrideWithValue(disk),
            depositApprovalReceiptRepositoryProvider.overrideWithValue(receipts),
          ],
        );
        container.read(authProvider);
        container.read(depositApprovalProvider);
        await Future<void>.delayed(Duration.zero);
        identity.beforeSend = () async {
          final file = File('${directory.path}/pending-deposit-approvals-v1.json');
          final records = decodeApprovalJournal(await file.readAsString());
          expect(records.single.hash, null);
          expect(records.single.transaction.nonce, BigInt.from(7));
        };
        await controller().confirm(await review());
        await disk.close();
        final rebuilt = FileDepositApprovalJournal(() async => directory);
        await rebuilt.reload();
        expect(rebuilt.snapshot.records.single.hash, hash);
        expect(identity.transactions.length, 1);
        await rebuilt.close();
        await directory.delete(recursive: true);
      });
    },
  );
}
