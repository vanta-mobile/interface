import '../../../core/errors/api_error_details.dart';
import '../../../core/network/request_scope.dart';

import 'package:decimal/decimal.dart';

import '../../../core/data/aster_signature_verifier.dart';
import '../../../core/data/wallet_operation_journal.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/aster_spot_service.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../../subaccounts/data/signed_subaccount_list_repository.dart';
import '../domain/deposit_wallet.dart';
import '../domain/funding_catalog.dart';
import '../domain/funding_fee.dart';
import '../domain/withdrawal.dart';
import 'signed_withdraw_info_repository.dart';

class AsterWithdrawalRepository implements WithdrawalRepository {
  AsterWithdrawalRepository(
    this.futures,
    this.spot,
    this.catalog,
    this.fees,
    this.sign,
    this.journal, {
    required this.nonces,
    DateTime Function()? now,
    AsterAccountService? infoService,
  }) : now = now ?? DateTime.now,
       infoService = infoService ?? futures;
  final AsterAccountService futures;
  final AsterSpotService spot;
  final FundingCatalogRepository catalog;
  final FundingFeeRepository fees;
  final AccountRequestSigner sign;
  final WalletOperationJournal journal;
  final AsterReadNonces nonces;
  final DateTime Function() now;

  /// Withdrawal limits keep reported numbers exact; see [decodeWithdrawInfoJson].
  final AsterAccountService infoService;
  void _ready() {
    if (!journal.snapshot.ready || journal.snapshot.failed) {
      throw const AccountReadFailure('walletOperationStorage');
    }
  }

  @override
  Future<WithdrawalReview> prepare({
    required AuthIdentity identity,
    required DepositWalletQuery query,
    required String amount,
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    void current() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    }

    try {
      current();
      final address = identity.walletAddress, asset = query.asset;
      if (address == null || !validOperationAddress(address) || !identity.signingAvailable) {
        throw const AccountReadFailure('authWalletReconnect');
      }
      if (amount.length > 160 || !RegExp(r'^(0|[1-9]\d*)(?:\.\d+)?$').hasMatch(amount)) {
        throw const FormatException();
      }
      final value = Decimal.parse(amount);
      if (value <= Decimal.zero ||
          value.scale > asset.decimals ||
          !fundingEvmChainIds.contains(asset.chainId) ||
          asset.routeType != 'autoWithdraw') {
        throw const FormatException();
      }
      _ready();
      final started = now().toUtc();
      final assets = await catalog.read(
        FundingCatalogQuery(query.market, FundingOperation.withdraw),
      );
      current();
      if (!assets.assets.any(
        (a) =>
            a.asset == asset.asset &&
            a.chainId == asset.chainId &&
            a.tokenAddress.toLowerCase() == asset.tokenAddress.toLowerCase() &&
            a.decimals == asset.decimals &&
            a.isNative == asset.isNative &&
            a.routeType == asset.routeType,
      )) {
        throw const AccountReadFailure('withdrawalAssetChanged');
      }
      // user is the documented master address. An accepted signed master-only
      // directory response is required; the app never treats an ID as address.
      final directory = await SignedSubaccountListRepository(
        futures,
        sign,
        nonces: nonces,
        now: now,
      ).read(address: address, isCurrent: isCurrent, onStep: (_) {});
      current();
      if (directory.accounts.where((r) => r.isParent).length != 1) {
        throw const AccountReadFailure('subaccountMasterRequired');
      }
      final info = await SignedWithdrawInfoRepository(
        infoService,
        sign,
        nonces: nonces,
        now: now,
      ).read(address: address, isCurrent: isCurrent, onStep: (_) {});
      current();
      final fee = await fees.read(
        FundingFeeQuery(market: query.market, chainId: asset.chainId, asset: asset.asset),
      );
      current();
      final review = WithdrawalReview(
        identity: identity,
        query: query,
        amount: value,
        fee: fee,
        info: info,
        preparedAt: started,
      );
      validateWithdrawalReview(review, now().toUtc());
      return review;
    } on FormatException {
      throw const AccountReadFailure('withdrawalAmountInvalid');
    }
  });

  @override
  Future<WalletOperationRecord> submit(
    WithdrawalReview review, {
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    void current() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    }

    WalletOperationRecord? record;
    var saved = false, sent = false;
    try {
      current();
      validateWithdrawalReview(review, now().toUtc());
      final address = review.identity.walletAddress!;
      _ready();
      final fresh = await prepare(
        identity: review.identity,
        query: review.query,
        amount: review.amount.toString(),
        isCurrent: isCurrent,
      );
      current();
      if (fresh.fee.assetFee != review.fee.assetFee) {
        throw const AccountReadFailure('withdrawalFeeChanged');
      }
      validateWithdrawalReview(fresh, now().toUtc());
      final server = await futures.serverTime();
      current();
      // The Action field table, numeric EVM examples and current official web
      // client use milliseconds x1000 for the business nonce. The API envelope
      // uses a distinct microsecond nonce as required by the live V3 validator.
      // See implementation.md for the conflicting funding demo documentation.
      final userNonce = nonces.next(server), data = withdrawalTypedData(fresh, userNonce);
      final business = await sign(expectedAddress: address, typedData: data);
      current();
      if (!verifyAsterWalletSignature(address, data, business)) {
        throw const AccountReadFailure('authWalletSignature');
      }
      validateWithdrawalReview(fresh, now().toUtc());
      final apiClock = Stopwatch()..start(), apiTime = await futures.serverTime();
      current();
      final nonce = nonces.next(apiTime);
      final query = Uri(
        queryParameters: {
          'chainId': '${fresh.query.asset.chainId}',
          'asset': fresh.query.asset.asset,
          'amount': fresh.amount.toString(),
          'fee': fresh.fee.assetFee.toString(),
          'receiver': address,
          'userNonce': '$userNonce',
          'signatureType': 'EOA',
          'userSignature': business,
          'nonce': '$nonce',
          'user': address,
          'signer': address,
        },
      ).query;
      final apiData = asterReadTypedData(query),
          signature = await sign(expectedAddress: address, typedData: asterReadTypedData(query));
      current();
      if (!verifyAsterWalletSignature(address, apiData, signature)) {
        throw const AccountReadFailure('authWalletSignature');
      }
      validateWithdrawalReview(fresh, now().toUtc());
      record = WalletOperationRecord(
        kind: WalletOperationKind.withdrawal,
        address: address,
        nonce: nonce,
        preparedAt: now().toUtc(),
        terms: {
          'chain': '${fresh.query.asset.chainId}',
          'market': fresh.query.market.name,
          'asset': fresh.query.asset.asset,
          'amount': fresh.amount.toString(),
          'fee': fresh.fee.assetFee.toString(),
          'receiver': address,
        },
      );
      await journal.prepare(record);
      saved = true;
      current();
      validateWithdrawalReview(fresh, now().toUtc());
      if (apiClock.elapsed >= const Duration(seconds: 29)) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
      sent = true;
      final result = await (fresh.query.market.name == 'spot' ? spot : futures).signedPostQuery(
        fresh.query.market.name == 'spot'
            ? '/api/v3/aster/user-withdraw'
            : '/fapi/v3/aster/user-withdraw',
        query: query,
        signature: signature,
      );
      if (result is! Map<String, dynamic> ||
          result['withdrawId'] is! String ||
          !RegExp(r'^[a-zA-Z0-9_.:-]{1,128}$').hasMatch(result['withdrawId'] as String) ||
          result['hash'] is! String ||
          !RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(result['hash'] as String)) {
        throw const AccountReadFailure('walletOperationUnknown');
      }
      final id = result['withdrawId'] as String;
      // hash is the signature digest, never an on-chain transaction hash.
      await journal.report(record.key, id);
      return record.reported(id);
    } catch (e) {
      if (saved && !sent && record != null) await journal.removeNotSent(record.key);
      if (sent) throw AccountReadFailure('walletOperationUnknown', details: errorDetailsOf(e));
      if (e is AuthFailure) throw AccountReadFailure(e.key);
      if (e is WalletOperationPending) throw const AccountReadFailure('walletOperationPending');
      if (e is WalletOperationStorageFailure) {
        throw const AccountReadFailure('walletOperationStorage');
      }
      rethrow;
    }
  });
}

void validateWithdrawalReview(WithdrawalReview r, DateTime now) {
  final asset = r.query.asset, address = r.identity.walletAddress;
  final age = now.difference(r.preparedAt);
  if (age < Duration.zero ||
      age >= const Duration(seconds: 30) ||
      r.info.receivedAt.isAfter(now) ||
      r.fee.receivedAt.isAfter(now) ||
      r.fee.receivedAt.isBefore(r.preparedAt) ||
      r.info.receivedAt.isBefore(r.preparedAt)) {
    throw const AccountReadFailure('accountSignatureExpired');
  }
  if (address == null ||
      r.info.address.toLowerCase() != address.toLowerCase() ||
      r.fee.query !=
          FundingFeeQuery(market: r.query.market, chainId: asset.chainId, asset: asset.asset) ||
      r.amount <= Decimal.zero ||
      r.amount.scale > asset.decimals ||
      r.fee.assetFee < Decimal.zero) {
    throw const AccountReadFailure('accountDataInvalid');
  }
  final info = r.info.assets[asset.asset],
      chain = info?.chains[asset.chainId],
      price = r.fee.assetPriceUsd;
  final quantities = [
    info?.total(r.query.market),
    chain?.maximum(r.query.market),
    chain?.chainLimit,
  ];
  final dollars = [
    r.info.userRemainingDailyLimitUsd,
    r.info.totalRemainingDailyLimitUsd,
    info?.dailyLimitUsd,
  ];
  if (quantities.any((v) => v == null) ||
      dollars.any((v) => v == null) ||
      price == null ||
      price <= Decimal.zero) {
    throw const AccountReadFailure('withdrawalLimitsUnknown');
  }
  final total = r.amount + r.fee.assetFee, usd = total * price;
  if (quantities.any((v) => total > v!) || dollars.any((v) => usd > v!)) {
    throw const AccountReadFailure('withdrawalLimitExceeded');
  }
}

Map<String, Object?> withdrawalTypedData(WithdrawalReview r, int nonce) => {
  'types': {
    'EIP712Domain': [
      {'name': 'name', 'type': 'string'},
      {'name': 'version', 'type': 'string'},
      {'name': 'chainId', 'type': 'uint256'},
      {'name': 'verifyingContract', 'type': 'address'},
    ],
    'Action': [
      {'name': 'type', 'type': 'string'},
      {'name': 'destination', 'type': 'address'},
      {'name': 'destination Chain', 'type': 'string'},
      {'name': 'token', 'type': 'string'},
      {'name': 'amount', 'type': 'string'},
      {'name': 'fee', 'type': 'string'},
      {'name': 'nonce', 'type': 'uint256'},
      {'name': 'aster chain', 'type': 'string'},
    ],
  },
  'primaryType': 'Action',
  'domain': {
    'name': 'Aster',
    'version': '1',
    'chainId': r.query.asset.chainId,
    'verifyingContract': '0x0000000000000000000000000000000000000000',
  },
  'message': {
    'type': 'Withdraw',
    'destination': r.identity.walletAddress,
    'destination Chain': switch (r.query.asset.chainId) {
      1 => 'ETH',
      56 => 'BSC',
      42161 => 'Arbitrum',
      _ => throw const FormatException(),
    },
    'token': r.query.asset.asset,
    'amount': r.amount.toString(),
    'fee': r.fee.assetFee.toString(),
    'nonce': '$nonce',
    'aster chain': 'Mainnet',
  },
};
