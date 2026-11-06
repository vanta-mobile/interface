import '../../../core/errors/api_error_details.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/domain/aster_signature.dart';

/// Creation is an external-EOA product capability, separate from Aster's
/// master-account qualification and the wallet's current signing availability.
bool canCreateSubaccount(AuthIdentity? identity) => identity?.walletKind == WalletKind.external;

class SubaccountManagementReview {
  SubaccountManagementReview({required this.identity, required this.record, required this.query});
  final AuthIdentity identity;
  final WalletOperationRecord record;

  /// Creation query before childSignature; other commands are ready to sign.
  final String query;
  Map<String, Object?> get childTypedData => asterReadTypedData(query);
}

abstract interface class SubaccountManagementRepository {
  Future<SubaccountManagementReview> prepare({
    required AuthIdentity identity,
    required WalletOperationKind kind,
    required Map<String, String> terms,
    required bool Function() isCurrent,
  });
  Future<WalletOperationRecord> submit(
    SubaccountManagementReview review, {
    String childSignature = '',
    required bool Function() isCurrent,
  });
}

class SubaccountManagementState {
  const SubaccountManagementState({
    this.busy = false,
    this.review,
    this.result,
    this.failure,
    this.errorDetails,
  });
  final bool busy;
  final SubaccountManagementReview? review;
  final WalletOperationRecord? result;
  final ApiErrorDetails? errorDetails;
  final String? failure;
}
