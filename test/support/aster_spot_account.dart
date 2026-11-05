import 'dart:async';

import 'package:vanta/features/portfolio/data/aster_spot_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/aster_spot_account.dart';

import 'aster_account.dart';

Map<String, Object?> spotPayload() => {
  'canTrade': true,
  'balances': [
    {'asset': 'BTC', 'free': '0.000000000000000001', 'locked': '0.01'},
    {'asset': 'USDT', 'free': '99.000000000000000001', 'locked': '1'},
    {'asset': 'BNB', 'free': '0', 'locked': '0'},
    {'asset': 'ETH', 'free': '0', 'locked': '2'},
  ],
};

AsterSpotAccount spotFixture({String address = accountAddress}) => mapAsterSpotAccount(
  spotPayload(),
  address: address,
  receivedAt: DateTime.utc(2026, 11, 2, 12, 30),
);

class TestSpotRepository implements AsterSpotAccountRepository {
  AsterSpotAccount result = spotFixture();
  AccountReadFailure? failure;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<AsterSpotAccount> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    calls++;
    onStep(AccountReadStep.signing);
    await gate?.future;
    onStep(AccountReadStep.loading);
    if (failure case final error?) throw error;
    return result;
  }
}
