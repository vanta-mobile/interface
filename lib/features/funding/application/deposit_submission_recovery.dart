part of 'deposit_submission_provider.dart';

/// Receipt and platform credit reconciliation never sends a transaction.
mixin _DepositSubmissionRecovery on Notifier<DepositSubmissionState> {
  bool get _working;
  set _working(bool value);
  int get _generation;
  set _generation(int value);
  bool _scope(AuthIdentity identity, int generation);
  String _failure(Object error);
  Future<void> check(String key, String candidate) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity?.walletAddress == null) return;
    final journal = ref.read(depositSubmissionJournalProvider);
    if (!journal.snapshot.ready || journal.snapshot.failure != null) {
      state = const DepositSubmissionState(failure: 'depositSubmissionStorage');
      return;
    }
    final record = journal.snapshot.records
        .where(
          (r) =>
              r.key == key &&
              r.transaction.from.toLowerCase() == identity!.walletAddress!.toLowerCase(),
        )
        .singleOrNull;
    if (record == null) return;
    final chosenHash = candidate.trim().isEmpty ? record.hash ?? '' : candidate.trim();
    final generation = ++_generation;
    bool current() => _scope(identity!, generation);
    _working = true;
    state = DepositSubmissionState(step: DepositSubmissionStep.checking, record: record);
    try {
      final receipt = await ref
          .read(depositSubmissionReceiptRepositoryProvider)
          .read(record, chosenHash, isCurrent: current);
      if (!current()) return;
      if (!validFundingHash(receipt.hash) ||
          (chosenHash).toLowerCase() != receipt.hash.toLowerCase() ||
          receipt.status != DepositReceiptStatus.pending &&
              ((receipt.status == DepositReceiptStatus.replaced) == receipt.matchesIntent ||
                  !receipt.bound ||
                  receipt.confirmations < 2 ||
                  receipt.blockNumber == null ||
                  receipt.blockNumber! < record.baseBlock)) {
        throw const AccountReadFailure('depositRpcInvalid');
      }
      if (receipt.bound && receipt.matchesIntent && record.hash == null) {
        await journal.attachHash(record.key, receipt.hash);
      }
      if (!current()) return;
      // Chain success stays durable until an exact signed platform record
      // confirms credit. Reversion/replacement resolve only the chain attempt.
      if (receipt.status == DepositReceiptStatus.reverted ||
          receipt.status == DepositReceiptStatus.replaced) {
        await journal.complete(record.key);
      }
      if (current()) state = DepositSubmissionState(record: record, receipt: receipt);
    } catch (error) {
      if (current()) state = DepositSubmissionState(record: record, failure: _failure(error));
    } finally {
      _working = false;
    }
  }

  Future<void> checkCredit(String key, {String candidate = ''}) async {
    final auth = ref.read(authProvider), identity = auth.identity;
    if (_working || auth.busy || identity?.walletAddress == null) return;
    if (!identity!.signingAvailable) {
      state = const DepositSubmissionState(failure: 'authWalletReconnect');
      return;
    }
    final journal = ref.read(depositSubmissionJournalProvider);
    if (!journal.snapshot.ready || journal.snapshot.failure != null) {
      state = const DepositSubmissionState(failure: 'depositSubmissionStorage');
      return;
    }
    final record = journal.snapshot.records
        .where(
          (r) =>
              r.key == key &&
              r.transaction.from.toLowerCase() == identity.walletAddress!.toLowerCase(),
        )
        .singleOrNull;
    final chosenHash = candidate.trim().isEmpty ? record?.hash : candidate.trim();
    if (record == null || chosenHash == null || !validFundingHash(chosenHash)) {
      state = const DepositSubmissionState(failure: 'depositSubmissionHashNeeded');
      return;
    }
    final generation = ++_generation;
    bool current() => _scope(identity, generation);
    _working = true;
    state = DepositSubmissionState(step: DepositSubmissionStep.checking, record: record);
    try {
      final receipt = await ref
          .read(depositSubmissionReceiptRepositoryProvider)
          .read(record, chosenHash, isCurrent: current);
      if (!current()) return;
      if (receipt.hash.toLowerCase() != chosenHash.toLowerCase() ||
          receipt.blockNumber == null ||
          receipt.blockNumber! < record.baseBlock ||
          receipt.status != DepositReceiptStatus.succeeded ||
          !receipt.bound ||
          !receipt.matchesIntent ||
          receipt.confirmations < 2) {
        throw const AccountReadFailure('depositSubmissionChainPending');
      }
      final history = await ref
          .read(transferHistoryRepositoryProvider)
          .read(address: identity.walletAddress!, isCurrent: current, onStep: (_) {});
      if (!current()) return;
      if (history.address.toLowerCase() != identity.walletAddress!.toLowerCase() ||
          history.receivedAt.isBefore(record.preparedAt)) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final matches = history.records
          .where(
            (r) =>
                r.type == TransferType.deposit &&
                r.market == record.query.market &&
                r.chainId == record.query.asset.chainId &&
                r.asset == record.query.asset.asset &&
                r.txHash?.toLowerCase() == receipt.hash.toLowerCase() &&
                r.amount == depositQuantity(record.amountUnits, record.query.asset.decimals),
          )
          .toList();
      if (matches.length != 1 || matches.single.status != TransferStatus.success) {
        state = DepositSubmissionState(
          record: record,
          receipt: receipt,
          failure: 'depositSubmissionCreditPending',
        );
        return;
      }
      await journal.complete(record.key);
      if (current()) {
        state = DepositSubmissionState(record: record, receipt: receipt, credited: true);
      }
    } catch (e) {
      if (current()) state = DepositSubmissionState(record: record, failure: _failure(e));
    } finally {
      _working = false;
    }
  }
}
