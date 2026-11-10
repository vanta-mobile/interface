import 'dart:async';

import 'package:vanta/features/auth/data/account_switch_authorization.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';

class TestAccountSwitchAuthorization extends AccountSwitchAuthorization {
  TestAccountSwitchAuthorization()
    : super(({required expectedAddress, required typedData}) async => throw UnimplementedError());
  int calls = 0;
  String? from, to;
  AuthFailure? failure;
  Completer<void>? gate;
  @override
  Future<void> authorize({
    required String from,
    required String to,
    required bool Function() isCurrent,
  }) async {
    calls++;
    this.from = from;
    this.to = to;
    await gate?.future;
    if (!isCurrent()) throw const AuthFailure('authWalletChanged');
    if (failure case final error?) throw error;
  }
}
