import '../../../core/errors/api_error_details.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/domain/aster_signature.dart';

/// Creation is an external-EOA product capability, separate from Aster's
/// master-account qualification and the wallet's current signing availability.
bool canCreateSubaccount(AuthIdentity? identity) => identity?.walletKind == WalletKind.external;

class SubaccountManagementReview {
  SubaccountManagementReview({
    required this.identity,
    required this.record,
    required this.query,
    this.signatureChainId = 1666,
  });
  final AuthIdentity identity;
  final WalletOperationRecord record;

  /// Creation query before childSignature; other commands are ready to sign.
  final String query;

  /// EIP-712 domain chain for the owner wallet signature. The child is a
  /// local key, so its proof keeps the documented 1666 domain.
  final int signatureChainId;
  Map<String, Object?> get childTypedData => asterReadTypedData(query);
}

/// A creation request is signed for at most 45 seconds; Aster refuses it after
/// that. A signed directory read this long after preparation without the child
/// wallet therefore proves the request was not executed.
const creationSettleWindow = Duration(minutes: 2);

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

  /// Checks a dispatched creation with an undecided outcome against the signed
  /// directory: true when the child is listed (recorded as created), false when
  /// it is provably absent (record cleared), null while still undecided. Throws
  /// `walletOperationUnknown` once the directory stays unreadable past the window.
  Future<bool?> settleCreation(
    SubaccountManagementReview review, {
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
