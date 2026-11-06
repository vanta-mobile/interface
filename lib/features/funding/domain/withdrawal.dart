import '../../../core/errors/api_error_details.dart';

import 'package:decimal/decimal.dart';

import '../../../core/domain/wallet_operation.dart';
import '../../auth/domain/auth_session.dart';
import 'deposit_wallet.dart';
import 'funding_fee.dart';
import 'withdraw_info.dart';

class WithdrawalReview {
  const WithdrawalReview({
    required this.identity,
    required this.query,
    required this.amount,
    required this.fee,
    required this.info,
    required this.preparedAt,
  });
  final AuthIdentity identity;
  final DepositWalletQuery query;
  final Decimal amount;
  final FundingFeeQuote fee;
  final WithdrawInfo info;
  final DateTime preparedAt;
}

abstract interface class WithdrawalRepository {
  Future<WithdrawalReview> prepare({
    required AuthIdentity identity,
    required DepositWalletQuery query,
    required String amount,
    required bool Function() isCurrent,
  });
  Future<WalletOperationRecord> submit(
    WithdrawalReview review, {
    required bool Function() isCurrent,
  });
}

class WithdrawalState {
  const WithdrawalState({
    this.busy = false,
    this.review,
    this.result,
    this.failure,
    this.errorDetails,
  });
  final bool busy;
  final WithdrawalReview? review;
  final WalletOperationRecord? result;
  final ApiErrorDetails? errorDetails;
  final String? failure;
}
