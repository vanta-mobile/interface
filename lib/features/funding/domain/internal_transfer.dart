import '../../../core/errors/api_error_details.dart';

import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../../portfolio/domain/aster_account.dart';
import '../../portfolio/domain/aster_spot_account.dart';
import '../../portfolio/domain/futures_asset_mode.dart';

enum InternalTransferDirection {
  spotToFutures('SPOT_FUTURE'),
  futuresToSpot('FUTURE_SPOT');

  const InternalTransferDirection(this.wire);
  final String wire;
}

class InternalTransferAsset {
  const InternalTransferAsset(this.asset, this.precision);
  final String asset;

  /// Website input policy (at most eight places), not token-chain decimals.
  final int precision;
  Decimal get step => Decimal.parse(precision == 0 ? '1' : '0.${'0' * (precision - 1)}1');
  Decimal floor(Decimal value) => Decimal.fromBigInt((value / step).floor()) * step;
}

class InternalTransferCatalog {
  InternalTransferCatalog({
    required Iterable<InternalTransferAsset> assets,
    required this.receivedAt,
  }) : assets = List.unmodifiable(assets);
  final List<InternalTransferAsset> assets;
  final DateTime receivedAt;
}

class InternalTransferContext {
  const InternalTransferContext({
    required this.address,
    required this.direction,
    required this.assetName,
    required this.catalog,
    required this.spot,
    required this.futures,
    required this.mode,
    required this.receivedAt,
    this.maximum,
    this.sourcePermission,
    this.destinationPermission,
  });
  final String address, assetName;
  final InternalTransferDirection direction;
  final InternalTransferCatalog catalog;
  final AsterSpotAccount spot;
  final AsterAccount futures;
  final FuturesAssetMode mode;
  final DateTime receivedAt;
  final Decimal? maximum;
  final bool? sourcePermission, destinationPermission;
  InternalTransferAsset? get asset =>
      catalog.assets.where((a) => a.asset == assetName).singleOrNull;
  Decimal? get spotFree => spot.balances.where((a) => a.asset == assetName).singleOrNull?.free;
  Decimal? get futuresWallet =>
      futures.assets.where((a) => a.asset == assetName).singleOrNull?.walletBalance;
  Decimal? get maxInput =>
      asset == null || maximum == null || maximum! < Decimal.zero ? null : asset!.floor(maximum!);
  String get terms => jsonEncode([
    address.toLowerCase(),
    direction.name,
    assetName,
    asset?.precision,
    '$maximum',
    '$spotFree',
    '$futuresWallet',
    sourcePermission,
    destinationPermission,
    mode.name,
  ]);
  String? validate(String text) {
    if (asset == null) return 'internalTransferAssetUnavailable';
    if (sourcePermission != true || destinationPermission != true) {
      return 'internalTransferPermission';
    }
    if (maximum == null || maximum! < Decimal.zero) return 'internalTransferMaximumUnknown';
    final amount = parseInternalTransferAmount(text);
    if (amount == null || amount <= Decimal.zero) return 'internalTransferInvalidAmount';
    if (amount.scale > asset!.precision) return 'internalTransferPrecision';
    if (amount > maximum!) return 'internalTransferTooLarge';
    return null;
  }
}

Decimal? parseInternalTransferAmount(String text) =>
    text.length <= 80 && RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text) ? Decimal.tryParse(text) : null;

class InternalTransferReview {
  const InternalTransferReview({
    required this.context,
    required this.amount,
    required this.clientId,
  });
  final InternalTransferContext context;
  final String amount, clientId;
}

class InternalTransferReply {
  InternalTransferReply(this.transactionId) {
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(transactionId) ||
        BigInt.parse(transactionId) > (BigInt.one << 63) - BigInt.one) {
      throw const FormatException();
    }
  }
  final String transactionId;
}

class InternalTransferRecord {
  InternalTransferRecord({
    required this.address,
    required this.asset,
    required this.amount,
    required this.direction,
    required this.clientId,
    required this.nonce,
    required this.preparedAt,
    this.reply,
  }) {
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address) ||
        BigInt.parse(address.substring(2), radix: 16) == BigInt.zero ||
        !RegExp(r'^[A-Za-z0-9_.-]{1,60}$').hasMatch(asset) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(clientId) ||
        nonce <= 0 ||
        nonce > 9223372036854775807 ||
        preparedAt.millisecondsSinceEpoch <= 0 ||
        preparedAt.year > 9999 ||
        (parseInternalTransferAmount(amount) ?? Decimal.zero) <= Decimal.zero) {
      throw const FormatException();
    }
  }
  final String address, asset, amount, clientId;
  final InternalTransferDirection direction;
  final int nonce;
  final DateTime preparedAt;
  final InternalTransferReply? reply;
  String get key => '${address.toLowerCase()}:$clientId';
  InternalTransferRecord reported(InternalTransferReply value) {
    if (reply != null && reply!.transactionId != value.transactionId) throw const FormatException();
    return InternalTransferRecord(
      address: address,
      asset: asset,
      amount: amount,
      direction: direction,
      clientId: clientId,
      nonce: nonce,
      preparedAt: preparedAt,
      reply: value,
    );
  }
}

class InternalTransferStorage {
  InternalTransferStorage({
    Iterable<InternalTransferRecord> records = const [],
    this.ready = true,
    this.failure = false,
  }) : records = List.unmodifiable(records);
  final List<InternalTransferRecord> records;
  final bool ready, failure;
}

abstract interface class InternalTransferJournal {
  InternalTransferStorage get snapshot;
  Stream<InternalTransferStorage> get changes;
  Future<void> reload();
  Future<void> prepare(InternalTransferRecord record);
  Future<void> report(String key, InternalTransferReply reply);
  Future<void> complete(String key);
  Future<void> close();
}

abstract interface class InternalTransferRepository {
  Future<InternalTransferContext> read({
    required String address,
    required String asset,
    required InternalTransferDirection direction,
    required bool Function() isCurrent,
  });
  Future<InternalTransferReply> submit({
    required InternalTransferReview review,
    required bool Function() canSubmit,
    required Future<void> Function(int nonce) beforeSend,
    required void Function() onDispatch,
  });
}

enum InternalTransferStep { idle, reading, reviewing, signing, submitting, checking }

class InternalTransferState {
  const InternalTransferState({
    this.asset = 'USDT',
    this.direction = InternalTransferDirection.spotToFutures,
    this.amount = '',
    this.context,
    this.review,
    this.record,
    this.failure,
    this.errorDetails,
    this.step = InternalTransferStep.idle,
    this.stale = true,
  });
  final String asset, amount;
  final InternalTransferDirection direction;
  final InternalTransferContext? context;
  final InternalTransferReview? review;
  final InternalTransferRecord? record;
  final ApiErrorDetails? errorDetails;
  final String? failure;
  final InternalTransferStep step;
  final bool stale;
  bool get busy => step != InternalTransferStep.idle && step != InternalTransferStep.reviewing;
}
