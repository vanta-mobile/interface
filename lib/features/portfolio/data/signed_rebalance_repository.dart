import '../../../core/network/request_scope.dart';
import '../domain/account_snapshot.dart';
import '../domain/asset_rebalance.dart';
import 'aster_account_mapper.dart';
import 'aster_account_service.dart';
import 'aster_read_service.dart';
import 'futures_asset_mode_mapper.dart';
import 'rebalance_codec.dart';
import 'signed_account_request.dart';

class SignedRebalanceRepository implements RebalanceRepository {
  SignedRebalanceRepository(
    this.service,
    this.sign, {
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  bool _fresh(RebalanceContext c) {
    final age = now().toUtc().difference(c.receivedAt);
    return age >= Duration.zero && age < const Duration(seconds: 30);
  }

  @override
  Future<RebalanceContext> read({required String address, required bool Function() isCurrent}) =>
      RequestScope.run(isCurrent, () async {
        SignedAccountRequest request(
          Future<Object?> Function({required String query, required String signature}) send,
        ) => SignedAccountRequest(
          serverTime: service.serverTime,
          send: send,
          sign: sign,
          nonces: nonces,
          signatureLifetime: const Duration(seconds: 30),
        );
        try {
          final mode = mapFuturesAssetMode(
            await request(service.assetMode)
                .read(address: address, isCurrent: isCurrent, onStep: (_) {}),
          );
          final receivedAt = now().toUtc();
          final account = mapAsterAccount(
            await request(service.account)
                .read(address: address, isCurrent: isCurrent, onStep: (_) {}),
            address: address,
            receivedAt: now().toUtc(),
          );
          return RebalanceContext(mode: mode, account: account, receivedAt: receivedAt);
        } on FormatException {
          throw const AccountReadFailure('accountDataInvalid');
        }
      });

  @override
  Future<RebalanceReply> submit({
    required RebalanceContext context,
    required bool Function() canSubmit,
    required Future<void> Function(int nonce) beforeSend,
    required void Function() onDispatch,
  }) => RequestScope.run(canSubmit, () async {
    void check() {
      if (!canSubmit() || !_fresh(context)) throw const AccountReadFailure('rebalanceChanged');
    }

    check();
    final fresh = await read(address: context.address, isCurrent: canSubmit);
    check();
    if (!fresh.needed || fresh.terms != context.terms || !_fresh(fresh)) {
      throw const AccountReadFailure('rebalanceChanged');
    }
    final serverTime = await service.serverTime();
    check();
    final nonce = nonces.next(serverTime);
    if (nonce <= 0 || nonce > 9223372036854775807) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    final query = Uri(
      queryParameters: {'nonce': '$nonce', 'user': context.address, 'signer': context.address},
    ).query;
    final stopwatch = Stopwatch()..start();
    final signature = await sign(
      expectedAddress: context.address,
      typedData: asterReadTypedData(query),
    );
    check();
    if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
      throw const AccountReadFailure('authWalletSignature');
    }
    if (stopwatch.elapsed >= const Duration(seconds: 30)) {
      throw const AccountReadFailure('accountSignatureExpired');
    }
    await beforeSend(nonce);
    check();
    if (!_fresh(fresh) || stopwatch.elapsed >= const Duration(seconds: 30)) {
      throw const AccountReadFailure('accountSignatureExpired');
    }
    onDispatch();
    // Preserve a received response for the original wallet even after scope
    // invalidation. Only pre-dispatch checks may turn this into "not sent".
    final payload = await service.assetExchange(query: query, signature: signature);
    try {
      if (payload is AsterEmptyResponse) return const RebalanceReply.noExchange();
      if (payload is! Map<String, dynamic> ||
          payload['accountId'] is! int ||
          payload['updateTime'] is! int) {
        throw const FormatException();
      }
      return RebalanceReply(
        asset: payload['asset'] as String,
        balance: rebalanceMoney(payload['balance']),
        accountId: '${payload['accountId']}',
        updateTime: DateTime.fromMillisecondsSinceEpoch(payload['updateTime'] as int, isUtc: true),
      );
    } catch (_) {
      throw const AccountReadFailure('accountDataInvalid');
    }
  });
}
