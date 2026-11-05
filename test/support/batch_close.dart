import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/data/live_order_mapper.dart';
import 'package:vanta/features/portfolio/data/position_risk_mapper.dart';
import 'package:vanta/features/portfolio/domain/aster_account.dart';
import 'package:vanta/features/portfolio/domain/futures_position_mode.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/position_margin_mode.dart';
import 'package:vanta/features/portfolio/domain/position_risk.dart';

import 'aster_account.dart';
import 'live_order.dart';
import 'position_risk.dart';

const batchUnits = {
  'BTCUSDT': AsterContractUnits(base: 'BTC', quote: 'USDT', margin: 'USDT'),
  'ETHUSDT': AsterContractUnits(base: 'ETH', quote: 'USDT', margin: 'USDT'),
};

List<Map<String, dynamic>> batchRiskRows({bool hedge = false, String btcQuantity = '0.01'}) => [
  {
    ...positionRiskRow(),
    'symbol': 'BTCUSDT',
    'positionSide': hedge ? 'LONG' : 'BOTH',
    'positionAmt': btcQuantity,
    'entryPrice': '79000',
    'markPrice': '80000',
    'marginType': 'cross',
    'leverage': '10',
  },
  if (hedge)
    {
      ...positionRiskRow(),
      'symbol': 'BTCUSDT',
      'positionSide': 'SHORT',
      'positionAmt': '-0.02',
      'entryPrice': '79000',
      'markPrice': '80000',
      'marginType': 'cross',
      'leverage': '10',
    },
  {
    ...positionRiskRow(),
    'symbol': 'ETHUSDT',
    'positionSide': hedge ? 'LONG' : 'BOTH',
    'positionAmt': hedge ? '0.03' : '-0.02',
    'entryPrice': '79000',
    'markPrice': '80000',
    'marginType': 'cross',
    'leverage': '10',
  },
  if (hedge)
    {
      ...positionRiskRow(),
      'symbol': 'ETHUSDT',
      'positionSide': 'SHORT',
      'positionAmt': '0',
      'entryPrice': '0',
      'markPrice': '80000',
      'marginType': 'cross',
      'leverage': '10',
    },
  {...positionRiskRow(), 'symbol': 'ZEROUSDT', 'positionAmt': '0', 'entryPrice': '0'},
];

PositionRiskSnapshot batchRiskFixture({
  bool hedge = false,
  DateTime? time,
  String btcQuantity = '0.01',
}) => mapPositionRisk(
  batchRiskRows(hedge: hedge, btcQuantity: btcQuantity),
  address: accountAddress,
  receivedAt: time ?? liveOrderClock,
  units: batchUnits,
);

Map<String, LiveOrderContext> batchContexts(
  PositionRiskSnapshot snapshot, {
  bool hedge = false,
}) => {
  for (final symbol in snapshot.positions.where((p) => !p.balanceOnly).map((p) => p.symbol).toSet())
    symbol: LiveOrderContext(
      address: snapshot.address,
      rules: mapLiveOrderRules({
        'symbols': [
          {
            ...(liveExchangePayload()['symbols'] as List).single as Map<String, dynamic>,
            'symbol': symbol,
            'baseAsset': batchUnits[symbol]!.base,
          },
        ],
      }, symbol),
      mode: hedge ? FuturesPositionMode.hedge : FuturesPositionMode.oneWay,
      marginMode: PositionMarginMode.cross,
      leverage: 10,
      markPrice: Decimal.parse('80000'),
      receivedAt: snapshot.receivedAt,
      positions: {
        for (final p in snapshot.positions.where((p) => p.symbol == symbol))
          p.side: LiveOrderPosition(side: p.side, quantity: p.quantity, entryPrice: p.entryPrice),
      },
    ),
};

class TestBatchLiveRepository implements LiveOrderRepository {
  TestBatchLiveRepository(PositionRiskSnapshot snapshot, {bool hedge = false})
    : contexts = batchContexts(snapshot, hedge: hedge);
  final Map<String, LiveOrderContext> contexts;
  final List<LiveOrderIntent> posts = [], checks = [];
  final List<String> reads = [];
  Completer<void>? readGate, signGate, queryGate;
  void Function()? afterRead, afterSign, afterPost;
  AccountReadFailure? failure;
  bool unknown = false, failAfterPost = false;
  bool Function()? latestCurrent;
  @override
  Future<LiveOrderContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
    bool includeFunds = true,
  }) async {
    reads.add(symbol);
    latestCurrent = isCurrent;
    onStep(LiveOrderStep.signingContext);
    await readGate?.future;
    afterRead?.call();
    return contexts[symbol]!;
  }

  @override
  Future<LiveOrderResult> submit({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LiveOrderStep) onStep,
  }) async {
    latestCurrent = isCurrent;
    onStep(LiveOrderStep.signing);
    await signGate?.future;
    afterSign?.call();
    if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
    if (!failAfterPost && failure != null) throw failure!;
    onStep(LiveOrderStep.submitting);
    posts.add(intent);
    afterPost?.call();
    if (failure != null) throw failure!;
    return recheck(intent: intent, isCurrent: isCurrent, onStep: onStep);
  }

  @override
  Future<LiveOrderResult> recheck({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  }) async {
    checks.add(intent);
    onStep(LiveOrderStep.checkSigning);
    await queryGate?.future;
    if (unknown) return const LiveOrderResult(failure: AccountReadFailure('accountNetwork'));
    return LiveOrderResult(
      orderId: '${checks.length}',
      status: 'FILLED',
      executedQuantity: Decimal.parse(intent.draft.quantity),
      checkedAt: liveOrderClock,
    );
  }
}
