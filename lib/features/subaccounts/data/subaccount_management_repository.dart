import '../../../core/errors/api_error_details.dart';
import '../../../core/network/request_scope.dart';

import 'package:decimal/decimal.dart';

import '../../../core/data/aster_signature_verifier.dart';
import '../../../core/data/wallet_operation_journal.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/data/aster_account_service.dart';
import '../../portfolio/data/signed_account_request.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/subaccount_management.dart';
import 'signed_subaccount_list_repository.dart';

class AsterSubaccountManagementRepository implements SubaccountManagementRepository {
  AsterSubaccountManagementRepository(
    this.service,
    this.sign,
    this.journal, {
    required this.nonces,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AsterAccountService service;
  final AccountRequestSigner sign;
  final WalletOperationJournal journal;
  final AsterReadNonces nonces;
  final DateTime Function() now;
  void _ready(String address) {
    if (!journal.snapshot.ready || journal.snapshot.failed) {
      throw const AccountReadFailure('walletOperationStorage');
    }
    if (journal.snapshot.records.any(
      (r) => !r.acknowledged && r.address.toLowerCase() == address.toLowerCase(),
    )) {
      throw const AccountReadFailure('walletOperationPending');
    }
  }

  Future<void> _parent(AuthIdentity i, WalletOperationKind kind, bool Function() current) async {
    // The transfer contract also permits a child to sign its own transfer.
    // Master-only directory reads would reject that supported account scope.
    // Relationship, freeze status and asset limits remain server-enforced.
    if (kind == WalletOperationKind.subaccountTransfer) return;
    final directory = await SignedSubaccountListRepository(
      service,
      sign,
      nonces: nonces,
      now: now,
    ).read(address: i.walletAddress!, isCurrent: current, onStep: (_) {});
    // The endpoint documents user as the authenticated master. Its successful
    // signed response is the available server qualification, not an ID/address
    // mapping. Never infer a child address or status from a list name.
    if (directory.accounts.where((r) => r.isParent).length != 1) {
      throw const AccountReadFailure('subaccountMasterRequired');
    }
    if (kind == WalletOperationKind.createSubaccount && directory.childCount >= 10) {
      throw const AccountReadFailure('subaccountLimitReached');
    }
  }

  @override
  Future<SubaccountManagementReview> prepare({
    required AuthIdentity identity,
    required WalletOperationKind kind,
    required Map<String, String> terms,
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
    if (kind == WalletOperationKind.createSubaccount && !canCreateSubaccount(identity)) {
      throw const AccountReadFailure('subaccountCreateExternalOnly');
    }
    final address = identity.walletAddress;
    if (address == null || !validOperationAddress(address) || !identity.signingAvailable) {
      throw const AccountReadFailure('authWalletReconnect');
    }
    if (kind == WalletOperationKind.withdrawal || kind == WalletOperationKind.isolatedMargin) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    try {
      // Validate user input before any signature prompt or network operation.
      final draft = WalletOperationRecord(
        kind: kind,
        address: address,
        nonce: 1,
        preparedAt: now().toUtc(),
        terms: terms,
      );
      _validate(draft);
      _ready(address);
      await _parent(identity, kind, isCurrent);
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      final time = await service.serverTime();
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      final record = WalletOperationRecord(
        kind: kind,
        address: address,
        nonce: nonces.next(time),
        preparedAt: now().toUtc(),
        terms: terms,
      );
      return SubaccountManagementReview(identity: identity, record: record, query: _query(record));
    } on AuthFailure catch (e) {
      throw AccountReadFailure(e.key);
    } on FormatException {
      throw const AccountReadFailure('subaccountInputInvalid');
    }
  });

  void _validate(WalletOperationRecord r) {
    final t = r.terms;
    if (t['child']?.toLowerCase() == r.address.toLowerCase() ||
        t['from'] != null && t['from']!.toLowerCase() == t['to']!.toLowerCase()) {
      throw const FormatException();
    }
    if (r.kind == WalletOperationKind.createSubaccount &&
        (t['name']!.trim() != t['name'] ||
            t['name']!.isEmpty ||
            t['name']!.length > 64 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(t['name']!))) {
      throw const FormatException();
    }
    if (r.kind == WalletOperationKind.subaccountTransfer) {
      if (t['from']!.toLowerCase() != r.address.toLowerCase() &&
          t['to']!.toLowerCase() != r.address.toLowerCase()) {
        throw const FormatException();
      }
      if (Decimal.parse(t['amount']!) <= Decimal.zero || Decimal.parse(t['amount']!).scale > 18) {
        throw const FormatException();
      }
    }
  }

  String _query(WalletOperationRecord r) {
    final t = r.terms;
    return Uri(
      queryParameters: switch (r.kind) {
        WalletOperationKind.createSubaccount => {
          'subAccountName': t['name']!,
          'subSourceAddr': t['child']!,
          'nonce': '${r.nonce}',
          'user': r.address,
          'signer': r.address,
        },
        WalletOperationKind.freezeSubaccount || WalletOperationKind.unfreezeSubaccount => {
          'subSourceAddr': t['child']!,
          'nonce': '${r.nonce}',
          'user': r.address,
          'signer': r.address,
          'status': r.kind == WalletOperationKind.freezeSubaccount ? 'FROZEN' : 'NORMAL',
        },
        WalletOperationKind.subaccountTransfer => {
          'toAccountAddress': t['to']!,
          'asset': t['asset']!,
          'amount': t['amount']!,
          'kindType': t['direction']!,
          'nonce': '${r.nonce}',
          'user': r.address,
          'fromAccountAddress': t['from']!,
        },
        _ => throw const FormatException(),
      },
    ).query;
  }

  @override
  Future<WalletOperationRecord> submit(
    SubaccountManagementReview review, {
    String childSignature = '',
    required bool Function() isCurrent,
  }) => RequestScope.run(isCurrent, () async {
    final r = review.record;
    void current() {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      if (r.kind == WalletOperationKind.createSubaccount && !canCreateSubaccount(review.identity)) {
        throw const AccountReadFailure('subaccountCreateExternalOnly');
      }
      if (!review.identity.signingAvailable) {
        throw const AccountReadFailure('authWalletReconnect');
      }
      final age = now().difference(r.preparedAt);
      if (age < Duration.zero || age >= const Duration(seconds: 45)) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
    }

    var saved = false, sent = false;
    try {
      current();
      _validate(r);
      _ready(r.address);
      if (r.address != review.identity.walletAddress || review.query != _query(r)) {
        throw const FormatException();
      }
      var query = review.query;
      if (r.kind == WalletOperationKind.createSubaccount) {
        if (!verifyAsterWalletSignature(r.terms['child']!, review.childTypedData, childSignature)) {
          throw const AccountReadFailure('subaccountChildSignatureInvalid');
        }
        query = '$query&childSignature=$childSignature';
      }
      // Recheck master qualification/count after the review/child signing gap.
      await _parent(review.identity, r.kind, isCurrent);
      current();
      final server = await service.serverTime();
      current();
      if ((server * 1000 - r.nonce).abs() >= 45000000) {
        throw const AccountReadFailure('accountSignatureExpired');
      }
      final data = asterReadTypedData(query),
          signature = await sign(expectedAddress: r.address, typedData: asterReadTypedData(query));
      current();
      if (!verifyAsterWalletSignature(r.address, data, signature)) {
        throw const AccountReadFailure('authWalletSignature');
      }
      await journal.prepare(r);
      saved = true;
      current();
      sent = true;
      final response = await service.signedPost(
        switch (r.kind) {
          WalletOperationKind.createSubaccount => '/fapi/v3/createSubAccount',
          WalletOperationKind.freezeSubaccount ||
          WalletOperationKind.unfreezeSubaccount => '/fapi/v3/updateSubAccount',
          WalletOperationKind.subaccountTransfer => '/fapi/v3/subAccountTransfer',
          _ => throw const FormatException(),
        },
        query: query,
        signature: signature,
      );
      if (response is! Map<String, dynamic> || response['code'] != 200) {
        throw const AccountReadFailure('walletOperationUnknown');
      }
      await journal.report(r.key);
      return r.reported();
    } catch (e) {
      if (saved && !sent) {
        await journal.removeNotSent(r.key);
      }
      if (sent) throw AccountReadFailure('walletOperationUnknown', details: errorDetailsOf(e));
      if (e is AuthFailure) throw AccountReadFailure(e.key);
      if (e is WalletOperationPending) throw const AccountReadFailure('walletOperationPending');
      if (e is WalletOperationStorageFailure) {
        throw const AccountReadFailure('walletOperationStorage');
      }
      if (e is FormatException) throw const AccountReadFailure('subaccountInputInvalid');
      rethrow;
    }
  });
}
