import 'dart:async';

import 'package:vanta/features/funding/data/deposit_submission_journal.dart';
import 'package:vanta/features/funding/domain/deposit_submission.dart';
import 'package:vanta/features/funding/domain/deposit_approval.dart';

class GatedDepositJournal extends MemoryDepositSubmissionJournal {
  Completer<void>? gate;
  Object? prepareFailure, hashFailure;
  @override
  Future<void> prepare(DepositSubmissionRecord r) async {
    await gate?.future;
    if (prepareFailure != null) throw prepareFailure!;
    await super.prepare(r);
  }

  @override
  Future<void> attachHash(String key, String hash) async {
    if (hashFailure != null) throw hashFailure!;
    await super.attachHash(key, hash);
  }
}

class TestDepositReceiptRepository implements DepositSubmissionReceiptRepository {
  Completer<void>? gate;
  DepositApprovalReceipt? result;
  Object? failure;
  int calls = 0;
  @override
  Future<DepositApprovalReceipt> read(
    DepositSubmissionRecord r,
    String hash, {
    required bool Function() isCurrent,
  }) async {
    calls++;
    await gate?.future;
    if (failure != null) throw failure!;
    return result ??
        DepositApprovalReceipt(hash: hash, bound: true, status: DepositReceiptStatus.pending);
  }
}
