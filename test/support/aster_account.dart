import 'dart:async';

import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';

const accountAddress = '0x2222222222222222222222222222222222222222';
const signingIdentity = AuthIdentity(
  id: 'aster-test',
  walletAddress: accountAddress,
  walletKind: WalletKind.external,
  signingAvailable: true,
);

Map<String, Object?> accountPayload() => {
  'totalWalletBalance': '100.000000000000000001',
  'totalMarginBalance': '99.000000000000000001',
  'availableBalance': '89.000000000000000001',
  'totalUnrealizedProfit': '-1',
  'totalInitialMargin': '10',
  'canTrade': false,
  'assets': [
    {
      'asset': 'USDT',
      'walletBalance': '100.000000000000000001',
      'availableBalance': '89.000000000000000001',
      'unrealizedProfit': '-1',
      'marginAvailable': true,
    },
    {'asset': 'BNB', 'walletBalance': '0', 'marginAvailable': false},
  ],
  'positions': [
    {
      'symbol': 'BTCUSDT',
      'positionSide': 'BOTH',
      'positionAmt': '-0.000000000000000001',
      'entryPrice': '80000.01',
      'unrealizedProfit': '-1',
      'positionInitialMargin': '10',
      'leverage': '5',
      'isolated': true,
    },
    {'symbol': 'ETHUSDT', 'positionSide': 'LONG', 'positionAmt': '0'},
  ],
};

Map<String, Object?> contractPayload() => {
  'symbols': [
    {
      'symbol': 'BTCUSDT',
      'baseAsset': 'BTC',
      'quoteAsset': 'USDT',
      'marginAsset': 'USDT',
      'status': 'SETTLING',
    },
  ],
};

AsterAccount accountFixture({String address = accountAddress}) => mapAsterAccount(
  accountPayload(),
  address: address,
  receivedAt: DateTime.utc(2026, 11, 2, 12, 30),
  units: mapAsterContractUnits(contractPayload()),
);

class TestAsterAccountRepository implements AsterAccountRepository {
  AsterAccount result = accountFixture();
  AccountReadFailure? failure;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<AsterAccount> read({
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
