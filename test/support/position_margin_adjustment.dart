import 'dart:async';

import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import 'package:decimal/decimal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/position_margin_mapper.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/position_margin_adjustment.dart';

import 'aster_account.dart';

final marginClock = DateTime.utc(2026, 11, 4, 15);
const marginReference = 'vm_0123456789abcdef0123456789abcdef';
Map<String, Object?> marginAccount({
  String quantity = '2',
  String side = 'BOTH',
  String wallet = '50',
  String available = '90.123456789123',
  String cross = '100',
  String maintenance = '1',
  String initial = '20',
  String entry = '100',
}) => {
  'canTrade': true,
  'assets': [
    {
      'asset': 'USDT',
      'walletBalance': '150',
      'availableBalance': available,
      'crossWalletBalance': cross,
    },
  ],
  'positions': [
    {
      'symbol': 'BTCUSDT',
      'positionSide': side,
      'positionAmt': quantity,
      'entryPrice': entry,
      'isolatedWallet': wallet,
      'isolated': true,
      'leverage': '10',
      'positionInitialMargin': initial,
      'maintMargin': maintenance,
      'unrealizedProfit': '0',
    },
  ],
};
Map<String, Object?> marginRisk({
  String quantity = '2',
  String side = 'BOTH',
  String wallet = '50',
  String mark = '100',
  String entry = '100',
}) => {
  'symbol': 'BTCUSDT',
  'positionSide': side,
  'positionAmt': quantity,
  'entryPrice': entry,
  'isolatedWallet': wallet,
  'marginType': 'isolated',
  'leverage': '10',
  'markPrice': mark,
  'liquidationPrice': '75.123456789123',
  'unRealizedProfit': '0',
};
Map<String, Object?> marginBrackets() => {
  'symbol': 'BTCUSDT',
  'brackets': [
    {
      'bracket': 1,
      'initialLeverage': 100,
      'notionalFloor': 0,
      'notionalCap': 150,
      'maintMarginRatio': '0.01',
      'cum': '0',
    },
    {
      'bracket': 2,
      'initialLeverage': 50,
      'notionalFloor': 150,
      'notionalCap': 100000,
      'maintMarginRatio': '0.02',
      'cum': '1.5',
    },
  ],
};
PositionMarginContext marginContext({
  Map<String, Object?>? account,
  Map<String, Object?>? risk,
  DateTime? time,
}) {
  final units = mapAsterContractUnits(contractPayload());
  return PositionMarginContext(
    account: mapAsterAccount(
      account ?? marginAccount(),
      address: accountAddress,
      receivedAt: time ?? marginClock,
      units: units,
    ),
    position: mapPositionRisk(
      [risk ?? marginRisk()],
      address: accountAddress,
      receivedAt: time ?? marginClock,
      units: units,
    ).positions.single,
    receivedAt: time ?? marginClock,
    tiers: mapMarginRiskTiers(marginBrackets(), 'BTCUSDT'),
  );
}

WalletOperationRecord marginRecord({
  bool acknowledged = false,
  String? reference,
  String side = 'BOTH',
  String type = '1',
  String amount = '10',
}) => WalletOperationRecord(
  kind: WalletOperationKind.isolatedMargin,
  address: accountAddress,
  nonce: marginClock.microsecondsSinceEpoch,
  preparedAt: marginClock,
  terms: {
    'symbol': 'BTCUSDT',
    'side': side,
    'asset': 'USDT',
    'amount': amount,
    'type': type,
    'clientTranId': marginReference,
  },
  acknowledged: acknowledged,
  reference: reference,
);
Map<String, Object?> marginHistoryRow({
  String reference = marginReference,
  String type = '1',
  String side = 'BOTH',
  String amount = '10',
}) => {
  'amount': amount,
  'asset': 'USDT',
  'symbol': 'BTCUSDT',
  'time': marginClock.millisecondsSinceEpoch,
  'type': int.parse(type),
  'positionSide': side,
  'deltaType': 'USER_ADJUST',
  'clientTranId': reference,
};

class TestPositionMarginRepository implements PositionMarginRepository {
  int reads = 0, changes = 0, checks = 0;
  PositionMarginContext context = marginContext();
  MarginAdjustmentResult? result;
  AccountReadFailure? failure;
  Completer<void>? readGate, changeGate, checkGate;
  bool Function()? current, canSubmitLatest;
  bool submitted = false;
  PositionMarginIntent? lastIntent;
  @override
  Future<PositionMarginContext> read({
    required String address,
    required String symbol,
    required String side,
    required bool Function() isCurrent,
    required void Function(MarginAdjustmentStep) onStep,
  }) async {
    reads++;
    current = isCurrent;
    await readGate?.future;
    if (failure != null) throw failure!;
    return context;
  }

  @override
  Future<MarginAdjustmentResult> change({
    required PositionMarginIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(MarginAdjustmentStep) onStep,
  }) async {
    changes++;
    current = isCurrent;
    canSubmitLatest = canSubmit;
    lastIntent = intent;
    onStep(MarginAdjustmentStep.signing);
    await changeGate?.future;
    if (failure != null) throw failure!;
    if (canSubmit()) {
      submitted = true;
      onStep(MarginAdjustmentStep.submitting);
    }
    return result ??
        MarginAdjustmentResult(
          record: marginRecord(),
          failure: const AccountReadFailure('marginAdjustUnknown'),
        );
  }

  @override
  Future<MarginAdjustmentResult> check({
    required WalletOperationRecord record,
    required bool Function() isCurrent,
    required void Function(MarginAdjustmentStep) onStep,
  }) async {
    checks++;
    current = isCurrent;
    onStep(MarginAdjustmentStep.checking);
    await checkGate?.future;
    return result ??
        MarginAdjustmentResult(
          record: record,
          verified: true,
          position: context.position,
          context: context,
        );
  }
}

Decimal md(String value) => Decimal.parse(value);
