import 'dart:async';

import 'package:vanta/features/authorization/domain/trading_authorization.dart';

class TestTradingAuthorizationRepository implements TradingAuthorizationRepository {
  int enables = 0, checks = 0;
  Completer<void>? enableGate, checkGate;
  Object? failure;
  TradingAuthorizationResult result = TradingAuthorizationResult.acknowledged;
  TradingAuthorizationReview? review;
  bool Function()? isCurrent;

  @override
  Future<TradingAuthorizationResult> enable({
    required TradingAuthorizationReview review,
    required bool Function() isCurrent,
  }) async {
    enables++;
    this.review = review;
    this.isCurrent = isCurrent;
    await enableGate?.future;
    if (failure case final error?) throw error;
    return result;
  }

  @override
  Future<TradingAuthorizationCheck> check({
    required String address,
    required bool Function() isCurrent,
  }) async {
    checks++;
    await checkGate?.future;
    if (failure case final error?) throw error;
    return TradingAuthorizationCheck(
      address: address,
      checkedAt: DateTime.utc(2026, 11, 6),
      futuresReadAccepted: true,
      spotReadAccepted: true,
      futuresCanTrade: true,
    );
  }
}
