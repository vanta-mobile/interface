import 'dart:async';

import 'package:vanta/features/authorization/domain/trading_authorization.dart';

class TestTradingAuthorizationRepository implements TradingAuthorizationRepository {
  int enables = 0, checks = 0;
  Completer<void>? enableGate, checkGate;
  Object? failure;
  TradingAuthorizationResult result = TradingAuthorizationResult.acknowledged;
  TradingAuthorizationReview? review;
  bool Function()? isCurrent;
  void Function(TradingAuthorizationStep)? onStep;
  TradingAuthorizationStep initialStep = TradingAuthorizationStep.submitting;
  bool retriedPendingBuilder = false;
  TradingAuthorizationCheck? checked;

  @override
  Future<TradingAuthorizationResult> enable({
    required TradingAuthorizationReview review,
    required bool Function() isCurrent,
    void Function(TradingAuthorizationStep)? onStep,
    bool retryPendingBuilder = false,
  }) async {
    enables++;
    retriedPendingBuilder = retryPendingBuilder;
    this.review = review;
    this.isCurrent = isCurrent;
    this.onStep = onStep;
    onStep?.call(initialStep);
    await enableGate?.future;
    if (failure case final error?) throw error;
    return result;
  }

  @override
  Future<TradingAuthorizationCheck> check({
    required String address,
    required bool Function() isCurrent,
    String? identityId,
  }) async {
    checks++;
    await checkGate?.future;
    if (failure case final error?) throw error;
    return checked ??
        TradingAuthorizationCheck(
          address: address,
          checkedAt: DateTime.utc(2026, 11, 6),
          futuresReadAccepted: true,
          spotReadAccepted: true,
          futuresCanTrade: true,
        );
  }
}
