import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/withdrawal.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_management.dart';

import 'funding_info.dart';

class TestTradingAuthorizationRepository implements TradingAuthorizationRepository {
  int sends = 0, checks = 0;
  Completer<void>? gate;
  Object? failure;
  @override
  Future<TradingAuthorizationResult> enable({
    required TradingAuthorizationReview review,
    required bool Function() isCurrent,
  }) async {
    sends++;
    await gate?.future;
    if (failure != null) throw failure!;
    return TradingAuthorizationResult.acknowledged;
  }

  @override
  Future<TradingAuthorizationCheck> check({
    required String address,
    required bool Function() isCurrent,
  }) async {
    checks++;
    await gate?.future;
    if (failure != null) throw failure!;
    return TradingAuthorizationCheck(
      address: address,
      checkedAt: DateTime.now().toUtc(),
      futuresReadAccepted: true,
      spotReadAccepted: true,
      futuresCanTrade: false,
    );
  }
}

class TestSubaccountManagementRepository implements SubaccountManagementRepository {
  int prepares = 0, sends = 0;
  Completer<void>? gate;
  Object? failure;
  bool Function()? latestCurrent;
  @override
  Future<SubaccountManagementReview> prepare({
    required AuthIdentity identity,
    required WalletOperationKind kind,
    required Map<String, String> terms,
    required bool Function() isCurrent,
  }) async {
    prepares++;
    latestCurrent = isCurrent;
    await gate?.future;
    if (failure != null) throw failure!;
    return SubaccountManagementReview(
      identity: identity,
      record: WalletOperationRecord(
        kind: kind,
        address: identity.walletAddress!,
        nonce: 123,
        preparedAt: DateTime.now().toUtc(),
        terms: terms,
      ),
      query: 'fixture-query',
    );
  }

  @override
  Future<WalletOperationRecord> submit(
    SubaccountManagementReview review, {
    String childSignature = '',
    required bool Function() isCurrent,
  }) async {
    sends++;
    latestCurrent = isCurrent;
    await gate?.future;
    if (failure != null) throw failure!;
    return review.record.reported();
  }

  /// Directory checks in order: true, false, null or an error to throw.
  /// An exhausted queue ends checking as an unknown outcome.
  final settlements = <Object?>[];
  int settles = 0;
  @override
  Future<bool?> settleCreation(
    SubaccountManagementReview review, {
    required bool Function() isCurrent,
  }) async {
    settles++;
    if (settlements.isEmpty) throw const AccountReadFailure('walletOperationUnknown');
    final next = settlements.removeAt(0);
    if (next is Exception) throw next;
    return next as bool?;
  }
}

class TestWithdrawalRepository implements WithdrawalRepository {
  int prepares = 0, sends = 0;
  Completer<void>? gate;
  Object? failure;
  @override
  Future<WithdrawalReview> prepare({
    required AuthIdentity identity,
    required DepositWalletQuery query,
    required String amount,
    required bool Function() isCurrent,
  }) async {
    prepares++;
    await gate?.future;
    if (failure != null) throw failure!;
    final now = DateTime.now().toUtc();
    return WithdrawalReview(
      identity: identity,
      query: query,
      amount: Decimal.parse(amount),
      fee: FundingFeeQuote(
        query: FundingFeeQuery(
          market: query.market,
          chainId: query.asset.chainId,
          asset: query.asset.asset,
        ),
        receivedAt: now,
        assetFee: Decimal.parse('0.1'),
        usdFee: Decimal.parse('0.1'),
      ),
      info: withdrawInfoFixture(address: identity.walletAddress!),
      preparedAt: now,
    );
  }

  @override
  Future<WalletOperationRecord> submit(
    WithdrawalReview review, {
    required bool Function() isCurrent,
  }) async {
    sends++;
    await gate?.future;
    if (failure != null) throw failure!;
    return WalletOperationRecord(
      kind: WalletOperationKind.withdrawal,
      address: review.identity.walletAddress!,
      nonce: 123,
      preparedAt: review.preparedAt,
      terms: {
        'asset': review.query.asset.asset,
        'amount': review.amount.toString(),
        'fee': review.fee.assetFee.toString(),
        'chain': '${review.query.asset.chainId}',
        'market': review.query.market.name,
        'receiver': review.identity.walletAddress!,
      },
      acknowledged: true,
      reference: 'fixture-withdraw-id',
    );
  }
}
