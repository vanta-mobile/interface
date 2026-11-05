import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/data/aster_read_service.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../../portfolio/data/futures_asset_mode_mapper.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/internal_transfer.dart';
import 'internal_transfer_mapper.dart';

class InternalTransferCatalogService extends AsterReadService {
  InternalTransferCatalogService({super.client, super.timeout})
    : super(origin: Uri.https('www.asterdex.com'));
  Future<Object?> assets() => get('/bapi/spot/v2/public/spot/asset/transferable');
  Future<Object?> precision() => get('/bapi/futures/v1/public/future/asset/p-m-asset');
}

class SignedInternalTransferRepository implements InternalTransferRepository {
  SignedInternalTransferRepository(
    this.futures,
    this.spot,
    this.catalog,
    this.sign, {
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService futures;
  final AsterSpotService spot;
  final InternalTransferCatalogService catalog;
  final AccountRequestSigner sign;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  bool _fresh(InternalTransferContext c) {
    final age = now().toUtc().difference(c.receivedAt);
    return age >= Duration.zero && age < const Duration(seconds: 30);
  }

  @override
  Future<InternalTransferContext> read({
    required String address,
    required String asset,
    required InternalTransferDirection direction,
    required bool Function() isCurrent,
  }) async {
    final started = now().toUtc();
    void check() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    }

    Future<Object?> signed(
      AsterReadService service,
      Future<Object?> Function({required String query, required String signature}) send,
    ) => SignedAccountRequest(
      serverTime: service.serverTime,
      send: send,
      sign: sign,
      nonces: nonces,
      signatureLifetime: const Duration(seconds: 30),
    ).read(address: address, isCurrent: isCurrent, onStep: (_) {});
    try {
      check();
      final supported = await catalog.assets();
      check();
      final precision = await catalog.precision();
      check();
      final supportedAssets = mapInternalTransferCatalog(supported, precision, started);
      final mode = mapFuturesAssetMode(await signed(futures, futures.assetMode));
      final spotPayload = await signed(spot, spot.account);
      final futuresPayload = await signed(futures, futures.account);
      check();
      final c = mapInternalTransferContext(
        spotPayload: spotPayload,
        futuresPayload: futuresPayload,
        catalog: supportedAssets,
        address: address,
        asset: asset,
        direction: direction,
        mode: mode,
        receivedAt: started,
        completedAt: now().toUtc(),
      );
      if (!_fresh(c)) throw const AccountReadFailure('internalTransferChanged');
      return c;
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }

  @override
  Future<InternalTransferReply> submit({
    required InternalTransferReview review,
    required bool Function() canSubmit,
    required Future<void> Function(int nonce) beforeSend,
    required void Function() onDispatch,
  }) async {
    final c = review.context;
    void check() {
      if (!canSubmit() || !_fresh(c)) throw const AccountReadFailure('internalTransferChanged');
    }

    check();
    if (c.validate(review.amount) != null ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(review.clientId)) {
      throw const AccountReadFailure('internalTransferChanged');
    }
    final fresh = await read(
      address: c.address,
      asset: c.assetName,
      direction: c.direction,
      isCurrent: canSubmit,
    );
    check();
    if (fresh.terms != c.terms || fresh.validate(review.amount) != null) {
      throw const AccountReadFailure('internalTransferChanged');
    }
    final serverTime = await futures.serverTime();
    check();
    final nonce = nonces.next(serverTime);
    if (nonce <= 0 || nonce > 9223372036854775807) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    final query = Uri(
      queryParameters: {
        'amount': review.amount,
        'asset': c.assetName,
        'clientTranId': review.clientId,
        'kindType': c.direction.wire,
        'nonce': '$nonce',
        'user': c.address,
        'signer': c.address,
      },
    ).query;
    final stopwatch = Stopwatch()..start();
    final signature = await sign(expectedAddress: c.address, typedData: asterReadTypedData(query));
    check();
    if (!RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
      throw const AccountReadFailure('authWalletSignature');
    }
    await beforeSend(nonce);
    check();
    if (!_fresh(fresh) || stopwatch.elapsed >= const Duration(seconds: 30)) {
      throw const AccountReadFailure('accountSignatureExpired');
    }
    onDispatch();
    // Once dispatched, preserve the original wallet's reported response even
    // if its UI/auth scope has since changed. Never resubmit on any failure.
    final payload = await futures.signedPost(
      '/fapi/v3/asset/wallet/transfer',
      query: query,
      signature: signature,
    );
    try {
      return mapInternalTransferReply(payload);
    } on FormatException {
      throw const AccountReadFailure('accountDataInvalid');
    }
  }
}
