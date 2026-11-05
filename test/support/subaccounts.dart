import 'dart:async';

import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/data/subaccount_list_mapper.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_directory.dart';

import 'aster_account.dart';

List<Map<String, Object?>> subaccountRows() => [
  {'accountId': 9007199254740993, 'subAccountName': '交易台 / Desk A', 'parentAccount': false},
  {'accountId': 100000, 'subAccountName': '', 'parentAccount': true},
];
SubaccountDirectory subaccountFixture({String address = accountAddress}) => mapSubaccountDirectory(
  subaccountRows(),
  address: address,
  receivedAt: DateTime.utc(2026, 11, 3, 12),
);

class TestSubaccountListRepository implements SubaccountListRepository {
  SubaccountDirectory result = subaccountFixture();
  Completer<void>? gate;
  AccountReadFailure? failure;
  int calls = 0, sends = 0;
  @override
  Future<SubaccountDirectory> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    calls++;
    onStep(AccountReadStep.signing);
    await gate?.future;
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    sends++;
    onStep(AccountReadStep.loading);
    if (failure case final error?) throw error;
    return result;
  }
}
