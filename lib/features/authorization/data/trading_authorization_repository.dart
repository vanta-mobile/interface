import '../../../core/network/request_scope.dart';
import '../../../core/errors/api_error_details.dart';
import '../../../core/data/aster_signature_verifier.dart';
import '../../portfolio/data/aster_account_mapper.dart';
import '../../portfolio/data/aster_spot_mapper.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/trading_authorization.dart';

/// V3 public registration, signed by the current wallet itself. Deliberately
/// defaults to no withdrawal permission; an explicit IP-restricted option is
/// reviewed separately. No builder grant, API key or new wallet is created.
class AsterTradingAuthorizationRepository implements TradingAuthorizationRepository {
  AsterTradingAuthorizationRepository(
    this.futures,
    this.spot,
    this.sign, {
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService futures;
  final AsterSpotService spot;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;

  @override
  Future<TradingAuthorizationResult> enable({
    required TradingAuthorizationReview review,
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    void current() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      final age = now().difference(review.preparedAt);
      if (age < Duration.zero || age >= const Duration(minutes: 2)) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
    }

    try {
      current();
      final address = review.identity.walletAddress;
      if (address == null ||
          !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address) ||
          !review.identity.signingAvailable ||
          review.expiresAt.difference(review.preparedAt) != const Duration(days: 30)) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      if (review.canWithdraw &&
              normalizeAgentIpWhitelist(review.ipWhitelist) != review.ipWhitelist ||
          !review.canWithdraw && review.ipWhitelist.isNotEmpty) {
        throw const AccountReadFailure('authorizationIpInvalid');
      }
      final clock = Stopwatch()..start();
      final serverTime = await futures.serverTime();
      current();
      final nonce = nonces.next(serverTime);
      final query = Uri(
        queryParameters: {
          'user': address,
          'nonce': '$nonce',
          'agentName': 'Vanta',
          'agentAddress': address,
          'expired': '${review.expiresAt.millisecondsSinceEpoch}',
          'signatureChainId': '56',
          'canSpotTrade': 'true',
          'canPerpTrade': 'true',
          'canWithdraw': '${review.canWithdraw}',
          'ipWhitelist': review.ipWhitelist,
        },
      ).query;
      final data = asterReadTypedData(query);
      data['domain'] = {...data['domain']! as Map<String, Object?>, 'chainId': 56};
      final signature = await sign(expectedAddress: address, typedData: data);
      current();
      if (!verifyAsterWalletSignature(address, data, signature)) {
        throw const AccountReadFailure('authWalletSignature');
      }
      // Fetching time and signing both count towards the strict 10s window.
      // No implicit second prompt, nonce refresh or retry after an expired one.
      if (clock.elapsed >= const Duration(seconds: 9)) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
      try {
        final result = await futures.signedPost(
          '/fapi/v3/registerAndApproveAgent',
          query: query,
          signature: signature,
        );
        // A malformed/non-success reply does not prove the grant was refused.
        return result is Map<String, dynamic> && result['code'] == 200
            ? TradingAuthorizationResult.acknowledged
            : TradingAuthorizationResult.unknown;
      } catch (_) {
        return TradingAuthorizationResult.unknown;
      }
    } on AuthFailure catch (e) {
      throw AccountReadFailure(e.key, details: ApiErrorDetails(message: e.reason));
    }
  });

  @override
  Future<TradingAuthorizationCheck> check({
    required String address,
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    bool futuresAccepted = false, spotAccepted = false;
    bool? canTrade, canWithdraw;
    String? futuresFailure, spotFailure;
    String safe(Object e) => e is AccountReadFailure ? e.key : 'accountReadFailed';
    try {
      final data = await SignedAccountRequest(
        serverTime: futures.serverTime,
        send: futures.account,
        sign: sign,
        nonces: nonces,
      ).read(address: address, isCurrent: isCurrent, onStep: (_) {});
      if (data is! Map<String, dynamic> ||
          data['assets'] is! List ||
          data['positions'] is! List ||
          data['canTrade'] is! bool) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      final account = mapAsterAccount(data, address: address, receivedAt: now().toUtc());
      canTrade = account.canTrade;
      if (data['canWithdraw'] != null && data['canWithdraw'] is! bool) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      canWithdraw = data['canWithdraw'] as bool?;
      futuresAccepted = true;
    } catch (e) {
      futuresFailure = safe(e);
    }
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    try {
      final data = await SignedAccountRequest(
        serverTime: spot.serverTime,
        send: spot.account,
        sign: sign,
        nonces: nonces,
      ).read(address: address, isCurrent: isCurrent, onStep: (_) {});
      if (data is! Map<String, dynamic> || data['balances'] is! List) {
        throw const AccountReadFailure('accountDataInvalid');
      }
      mapAsterSpotAccount(data, address: address, receivedAt: now().toUtc());
      spotAccepted = true;
    } catch (e) {
      spotFailure = safe(e);
    }
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    return TradingAuthorizationCheck(
      address: address,
      checkedAt: now().toUtc(),
      futuresReadAccepted: futuresAccepted,
      spotReadAccepted: spotAccepted,
      futuresCanTrade: futuresAccepted ? canTrade : null,
      futuresCanWithdraw: futuresAccepted ? canWithdraw : null,
      futuresFailure: futuresFailure,
      spotFailure: spotFailure,
    );
  });
}
