import '../../../core/data/aster_signature_verifier.dart';
import '../../../core/errors/api_error_details.dart';
import '../../../core/network/request_scope.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_signing_preparation.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/builder_authorization.dart';
import '../domain/trading_authorization.dart';
import 'builder_authorization_mapper.dart';
import 'authorization_refusal.dart';

class AsterBuilderAuthorizationRepository {
  AsterBuilderAuthorizationRepository(
    this.service,
    this.sign, {
    required this.nonces,
    required this.journal,
    required this.authorization,
    this.signingPreparation,
    this.onChanged,
    this.stopwatch = Stopwatch.new,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final BuilderApprovalJournal journal;
  final AccountRequestAuthorization authorization;
  final WalletSigningPreparation? signingPreparation;
  final void Function()? onChanged;
  final Stopwatch Function() stopwatch;
  final DateTime Function() now;
  // Builder uses the V3 60s nonce window. Reserve 10s for transport; the
  // separate 10s registerAndApproveAgent rule does not apply to Builder.
  static const _signatureLifetime = Duration(seconds: 50);
  bool Function()? _activeApproval;

  Future<BuilderAuthorization> inspect({
    required String address,
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    final payload = await SignedAccountRequest(
      serverTime: service.serverTime,
      send: service.builders,
      sign: sign,
      authorization: authorization,
      nonces: nonces,
    ).read(address: address, isCurrent: isCurrent, onStep: (_) {});
    try {
      return mapBuilderAuthorization(payload, address);
    } on FormatException {
      throw const AccountReadFailure(
        'accountDataInvalid',
        details: ApiErrorDetails(
          cause: ApiErrorCause.invalidResponse,
          endpoint: '/fapi/v3/builder',
        ),
      );
    }
  });

  /// Read back before any approval. A pending approval requires a renewed
  /// user action to permit a fresh signature after an insufficient live grant.
  Future<TradingAuthorizationResult> enable({
    required TradingAuthorizationReview review,
    required bool Function() isCurrent,
    void Function(TradingAuthorizationStep)? onStep,
    bool retryPendingBuilder = false,
  }) => RequestScope.run(isCurrent, () async {
    if (_activeApproval?.call() == true) throw const AccountReadFailure('builderApprovalUnknown');
    bool active() => isCurrent();
    _activeApproval = active;
    final owner = review.identity.walletAddress;
    void current() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      final age = now().difference(review.preparedAt);
      if (age.isNegative || age >= const Duration(minutes: 2)) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
    }

    try {
      current();
      onStep?.call(TradingAuthorizationStep.preparing);
      if (owner == null || !review.identity.signingAvailable || review.canWithdraw) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final previous = await journal.load(owner);
      current();
      final observed = await inspect(address: owner, isCurrent: isCurrent);
      current();
      if (observed.sufficient) {
        await _confirmed(owner, observed);
        return TradingAuthorizationResult.acknowledged;
      }
      if (previous?.status == BuilderApprovalStatus.unknown && !retryPendingBuilder) {
        return TradingAuthorizationResult.unknown;
      }
      await signingPreparation?.prepareSigning(
        expectedAddress: owner,
        chainId: 56,
        isCurrent: isCurrent,
      );
      current();
      final clock = stopwatch()..start();
      final serverTime = await service.serverTime();
      current();
      final nonce = nonces.next(serverTime);
      final update = observed.bound;
      final data = builderApprovalTypedData(owner: owner, nonce: nonce, update: update);
      onStep?.call(TradingAuthorizationStep.signing);
      final signature = await sign(expectedAddress: owner, typedData: data);
      current();
      if (!verifyAsterWalletSignature(owner, data, signature)) {
        throw const AccountReadFailure('authWalletSignature');
      }
      if (clock.elapsed >= _signatureLifetime) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
      final query = Uri(
        queryParameters: {
          'builder': VantaBuilder.address,
          'maxFeeRate': VantaBuilder.approvalCap.toString(),
          if (!update) 'builderName': VantaBuilder.name,
          'asterChain': 'Mainnet',
          'user': owner,
          'nonce': '$nonce',
          'signatureChainId': '56',
        },
      ).query;
      try {
        await journal.save(
          owner,
          BuilderApprovalRecord(
            status: BuilderApprovalStatus.unknown,
            maxFeeRate: VantaBuilder.approvalCap,
          ),
        );
        current();
        if (clock.elapsed >= _signatureLifetime) {
          throw const AccountReadFailure('accountSignatureExpired');
        }
      } catch (_) {
        // The transport has not been invoked, so this attempt cannot have
        // granted fees. Remove the pending marker without replaying anything.
        try {
          await journal.save(
            owner,
            BuilderApprovalRecord(
              status: BuilderApprovalStatus.rejected,
              maxFeeRate: VantaBuilder.approvalCap,
            ),
          );
        } catch (_) {
          // Preserve the original storage/signature/scope failure.
        }
        rethrow;
      } finally {
        onChanged?.call();
      }
      var acknowledged = false;
      try {
        onStep?.call(TradingAuthorizationStep.submitting);
        final response = await service.signedPost(
          update ? '/fapi/v3/updateBuilder' : '/fapi/v3/approveBuilder',
          query: query,
          signature: signature,
        );
        current();
        if (response is! Map<String, dynamic> || response['code'] != 200) {
          return TradingAuthorizationResult.unknown;
        }
        acknowledged = true;
        onStep?.call(TradingAuthorizationStep.confirming);
        final confirmed = await inspect(address: owner, isCurrent: isCurrent);
        current();
        if (!confirmed.sufficient) return TradingAuthorizationResult.unknown;
        await _confirmed(owner, confirmed);
        return TradingAuthorizationResult.acknowledged;
      } on AccountReadFailure catch (failure) {
        if (!isCurrent()) rethrow;
        // Builder auth can return a JSON HTTP 400 refusal without a numeric
        // business code. Classify by the HTTP envelope, never by message text.
        // A refused read-back cannot turn an acknowledged write into a refusal.
        if (!acknowledged && authorizationWasRefused(failure)) {
          await journal.save(
            owner,
            BuilderApprovalRecord(
              status: BuilderApprovalStatus.rejected,
              maxFeeRate: VantaBuilder.approvalCap,
            ),
          );
          onChanged?.call();
          rethrow;
        }
        // Retain typed server diagnostics while keeping the dispatch journal.
        throw AccountReadFailure(
          'builderApprovalUnknown',
          code: failure.code,
          details: failure.details,
        );
      }
    } on AuthFailure catch (failure) {
      throw AccountReadFailure(failure.key, details: failure.details);
    } finally {
      if (identical(_activeApproval, active)) _activeApproval = null;
    }
  });

  Future<BuilderAuthorization> check({
    required String address,
    required bool Function() isCurrent,
  }) async {
    final observed = await inspect(address: address, isCurrent: isCurrent);
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    if (observed.sufficient) {
      await _confirmed(address, observed);
    } else {
      final previous = await journal.load(address);
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      if (previous?.status != BuilderApprovalStatus.unknown) {
        await journal.save(
          address,
          BuilderApprovalRecord(
            status: BuilderApprovalStatus.rejected,
            maxFeeRate: observed.maxFeeRate ?? VantaBuilder.approvalCap,
          ),
        );
        onChanged?.call();
      }
    }
    return observed;
  }

  Future<void> _confirmed(String owner, BuilderAuthorization observed) async {
    await journal.save(
      owner,
      BuilderApprovalRecord(
        status: BuilderApprovalStatus.approved,
        maxFeeRate: observed.maxFeeRate!,
      ),
    );
    onChanged?.call();
  }
}
