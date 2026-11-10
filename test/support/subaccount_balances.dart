import 'dart:async';

import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/subaccounts/data/subaccount_balance_repository.dart';
import 'package:vanta/features/subaccounts/domain/generated_subaccount.dart';

import 'aster_account.dart';

class TestSubaccountBalanceReader implements SubaccountBalanceReader {
  final addresses = <String>[];
  Completer<void>? gate;
  AccountReadFailure? failure;
  bool Function()? latestCurrent;
  @override
  Future<AsterAccount> read(GeneratedSubaccount wallet, bool Function() isCurrent) async {
    addresses.add(wallet.address);
    latestCurrent = isCurrent;
    await gate?.future;
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    if (failure case final error?) throw error;
    return accountFixture(address: wallet.address);
  }
}
