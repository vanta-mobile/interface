import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/live_order.dart';
import 'package:vanta/features/portfolio/domain/scaled_order.dart';

import 'live_order.dart';

ScaledOrderDraft scaledDraft({
  bool buy = true,
  String low = '79000',
  String high = '81000',
  String quantity = '0.008',
  int count = 3,
  ScaledSizeUnit unit = ScaledSizeUnit.base,
  ScaledDistribution distribution = ScaledDistribution.equal,
  ScaledConstant constant = ScaledConstant.difference,
  String variance = '10',
  int? seed,
}) => ScaledOrderDraft(
  buy: buy,
  lowest: low,
  highest: high,
  quantity: quantity,
  count: count,
  unit: unit,
  distribution: distribution,
  constant: constant,
  variance: variance,
  randomSeed: seed,
);

class TestScaledRepository implements LiveOrderRepository {
  LiveOrderContext context = liveContext();
  final reads = <String>[], posts = <LiveOrderIntent>[], checks = <LiveOrderIntent>[];
  final includesFunds = <bool>[];
  final submitted = <LiveOrderIntent>[];
  FutureOr<void> Function()? afterRead, afterPost;
  Completer<void>? signingGate, queryGate, readGate;
  bool Function()? latestCurrent;
  bool unknown = false;
  AccountReadFailure? failure;
  String status = 'NEW';
  @override
  Future<LiveOrderContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
    bool includeFunds = true,
  }) async {
    reads.add(symbol);
    includesFunds.add(includeFunds);
    latestCurrent = isCurrent;
    await readGate?.future;
    await afterRead?.call();
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    return context;
  }

  LiveOrderResult get result => unknown
      ? const LiveOrderResult(failure: AccountReadFailure('accountNetwork'))
      : LiveOrderResult(
          orderId: '${100 + posts.length}',
          status: status,
          executedQuantity: Decimal.zero,
        );
  @override
  Future<LiveOrderResult> submit({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LiveOrderStep) onStep,
  }) async {
    submitted.add(intent);
    latestCurrent = isCurrent;
    onStep(LiveOrderStep.signing);
    await signingGate?.future;
    if (!canSubmit()) throw const AccountReadFailure('liveOrderContextExpired');
    if (failure case final error?) throw error;
    onStep(LiveOrderStep.submitting);
    posts.add(intent);
    await afterPost?.call();
    await queryGate?.future;
    return result;
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
    return result;
  }
}

LiveOrderContext scaledContext({
  LiveOrderRules? rules,
  int? leverage,
  String available = '89.000000000000000001',
}) {
  final data = liveContext(available: available);
  return LiveOrderContext(
    address: data.address,
    rules: rules ?? data.rules,
    mode: data.mode,
    marginMode: data.marginMode,
    leverage: leverage ?? data.leverage,
    markPrice: data.markPrice,
    receivedAt: data.receivedAt,
    positions: data.positions,
    funds: data.funds,
  );
}

LiveOrderRules scaledRules({
  String? tick,
  String? minimumPrice,
  OrderQuantityRule? lot,
  Set<String>? types,
}) {
  final x = liveContext().rules;
  return LiveOrderRules(
    symbol: x.symbol,
    baseAsset: x.baseAsset,
    quoteAsset: x.quoteAsset,
    priceMinimum: minimumPrice == null ? x.priceMinimum : Decimal.parse(minimumPrice),
    priceMaximum: x.priceMaximum,
    priceTick: tick == null ? x.priceTick : Decimal.parse(tick),
    limitQuantity: lot ?? x.limitQuantity,
    marketQuantity: x.marketQuantity,
    minimumNotional: x.minimumNotional,
    percentUp: x.percentUp,
    percentDown: x.percentDown,
    timeInForce: x.timeInForce,
    orderTypes: types ?? x.orderTypes,
  );
}
