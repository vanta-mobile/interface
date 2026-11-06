import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/funding/data/withdrawal_repository.dart';
import 'package:vanta/features/funding/domain/deposit_wallet.dart';
import 'package:vanta/features/funding/domain/funding_fee.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/funding/domain/withdrawal.dart';
import 'package:vanta/features/funding/domain/withdrawal_recovery.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_signatures.dart';
import '../../support/deposit_wallet.dart';
import '../../support/funding_info.dart';

class _Fee implements FundingFeeRepository {
  _Fee(this.clock);
  final DateTime Function() clock;
  String fee = '0.1';
  @override
  Future<FundingFeeQuote> read(FundingFeeQuery q) async => FundingFeeQuote(
    query: q,
    receivedAt: clock(),
    assetFee: Decimal.parse(fee),
    usdFee: Decimal.parse(fee),
    assetPriceUsd: Decimal.one,
  );
}

void main() {
  var now = DateTime.utc(2026, 11, 4, 8);
  const identity = AuthIdentity(
    id: 'master',
    walletAddress: fixtureMaster,
    walletKind: WalletKind.external,
    signingAvailable: true,
  );
  late AsterWithdrawalRepository repo;
  late MemoryWalletOperationJournal journal;
  late _Fee fees;
  late List<http.Request> requests;
  late List<Map<String, Object?>> signed;
  late TestFundingCatalogRepository catalog;
  late bool current;
  Object? postFailure;
  Future<void> Function(Map<String, Object?>)? signHook;
  Future<void> Function()? postHook;
  late Map<String, Object?> info;
  late bool parent;
  Object? reply;
  setUp(() {
    now = DateTime.utc(2026, 11, 4, 8);
    journal = MemoryWalletOperationJournal();
    requests = [];
    signed = [];
    current = true;
    postFailure = null;
    signHook = null;
    postHook = null;
    parent = true;
    reply = {'withdrawId': '1234567', 'hash': '0x${'c' * 64}'};
    info = withdrawInfoPayload();
    catalog = TestFundingCatalogRepository();
    fees = _Fee(() => now);
    final client = MockClient((r) async {
      requests.add(r);
      expect(r.followRedirects, false);
      if (r.url.path.endsWith('/time')) {
        return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
      }
      if (r.url.path.endsWith('/getSubAccountList')) {
        return http.Response(
          jsonEncode(
            parent
                ? [
                    {'accountId': 1, 'subAccountName': '', 'parentAccount': true},
                  ]
                : [],
          ),
          200,
        );
      }
      if (r.url.path.endsWith('/user-withdraw-info')) return http.Response(jsonEncode(info), 200);
      expect(r.url.path.endsWith('/user-withdraw'), true);
      expect(journal.snapshot.records.single.acknowledged, false);
      expect(encodeWalletOperations(journal.snapshot.records).contains('Signature'), false);
      await postHook?.call();
      if (postFailure != null) throw postFailure!;
      return http.Response(jsonEncode(reply), 200);
    });
    addTearDown(client.close);
    addTearDown(journal.close);
    repo = AsterWithdrawalRepository(
      AsterAccountService(client: client),
      AsterSpotService(client: client),
      catalog,
      fees,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, fixtureMaster);
        signed.add(typedData);
        await signHook?.call(typedData);
        return fixtureSign(typedData);
      },
      journal,
      nonces: AsterReadNonces(),
      now: () => now,
    );
  });
  DepositWalletQuery query({TransferMarket market = TransferMarket.perp}) =>
      depositQuery(route: 'autoWithdraw', minimum: null, market: market);
  Future<WithdrawalReview> prepare({
    TransferMarket market = TransferMarket.perp,
    String amount = '1',
  }) => repo.prepare(
    identity: identity,
    query: query(market: market),
    amount: amount,
    isCurrent: () => current,
  );
  for (final market in TransferMarket.values) {
    test(
      '$market revalidates qualification/fee/limits and binds both signatures with separate nonce units',
      () async {
        final r = await prepare(market: market);
        expect(requests.where((r) => r.url.path.endsWith('/user-withdraw')), isEmpty);
        final result = await repo.submit(r, isCurrent: () => current);
        expect(result.reference, '1234567');
        final post = requests.singleWhere((r) => r.url.path.endsWith('/user-withdraw')),
            p = post.url.queryParameters;
        expect(
          post.url.host,
          market == TransferMarket.spot ? 'sapi.asterdex.com' : 'fapi.asterdex.com',
        );
        expect(post.method, 'POST');
        expect(post.body, isEmpty);
        expect(p['receiver'], fixtureMaster);
        expect(p['user'], fixtureMaster);
        expect(p['signer'], fixtureMaster);
        expect(p['amount'], '1');
        expect(p['fee'], '0.1');
        expect(int.parse(p['userNonce']!) ~/ 1000, now.millisecondsSinceEpoch);
        expect(int.parse(p['nonce']!) ~/ 1000000, now.millisecondsSinceEpoch);
        final action = signed.singleWhere((d) => d['primaryType'] == 'Action');
        expect((action['domain'] as Map)['name'], 'Aster');
        expect((action['domain'] as Map)['chainId'], 56);
        final message = action['message'] as Map;
        expect(message['destination Chain'], 'BSC');
        expect(message['nonce'], p['userNonce']);
        expect(message['amount'], p['amount']);
        expect(message['fee'], p['fee']);
        expect(post.url.query.endsWith('signature=${p['signature']}'), true);
        expect(journal.snapshot.records.single.reference, '1234567');
        expect(catalog.calls.length, 2);
        expect(requests.where((r) => r.url.path.endsWith('/getSubAccountList')).length, 2);
      },
    );
  }
  test('fee change requires a new review and sends no business signature or withdrawal', () async {
    final r = await prepare();
    fees.fee = '0.2';
    await expectLater(
      repo.submit(r, isCurrent: () => current),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'withdrawalFeeChanged')),
    );
    expect(signed.where((d) => d['primaryType'] == 'Action'), isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
  for (final field in ['userRemainingDailyLimit', 'totalRemainingDailyLimit']) {
    test('unknown USD limit $field blocks preparation', () async {
      info.remove(field);
      await expectLater(
        prepare(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'withdrawalLimitsUnknown')),
      );
      expect(journal.snapshot.records, isEmpty);
    });
    test('zero USD limit $field is enforced rather than treated as missing', () async {
      info[field] = '0';
      await expectLater(
        prepare(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'withdrawalLimitExceeded')),
      );
    });
  }
  test('amount plus fee stays in exact asset units and exceeds precise chain limit', () async {
    await expectLater(
      prepare(amount: '2.240000000000000003'),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'withdrawalLimitExceeded')),
    );
  });
  test('master qualification missing prevents a withdraw-info signature or submission', () async {
    parent = false;
    await expectLater(
      prepare(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'subaccountMasterRequired')),
    );
    expect(signed.length, 1);
  });
  for (final bad in ['0', '-1', '1e2', '1.0000000000000000001', 'NaN']) {
    test('invalid amount $bad rejected before signing', () async {
      await expectLater(prepare(amount: bad), throwsA(isA<AccountReadFailure>()));
      expect(signed, isEmpty);
      expect(requests, isEmpty);
    });
  }
  test('catalog change prevents signing', () async {
    catalog.rows = [];
    await expectLater(
      prepare(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'withdrawalAssetChanged')),
    );
    expect(signed, isEmpty);
  });
  test('unknown result is durable, never retried and blocks new operations', () async {
    final r = await prepare();
    postFailure = TimeoutException('fixture');
    await expectLater(
      repo.submit(r, isCurrent: () => current),
      throwsA(
        isA<AccountReadFailure>()
            .having((e) => e.key, 'key', 'walletOperationUnknown')
            .having((e) => e.details?.cause, 'cause', ApiErrorCause.timeout),
      ),
    );
    expect(journal.snapshot.records.single.acknowledged, false);
    await expectLater(
      prepare(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'walletOperationPending')),
    );
    expect(requests.where((r) => r.url.path.endsWith('/user-withdraw')).length, 1);
  });
  test('scope lost during business signing never submits or persists', () async {
    final r = await prepare();
    signHook = (d) async {
      if (d['primaryType'] == 'Action') current = false;
    };
    await expectLater(repo.submit(r, isCurrent: () => current), throwsA(isA<AccountReadFailure>()));
    expect(journal.snapshot.records, isEmpty);
    expect(requests.where((r) => r.url.path.endsWith('/user-withdraw')), isEmpty);
  });
  test('late response after logout persists original wallet request ID', () async {
    final r = await prepare();
    postHook = () async {
      current = false;
    };
    await repo.submit(r, isCurrent: () => current);
    expect(journal.snapshot.records.single.reference, '1234567');
  });
  test('review expiring while business signing prevents dispatch', () async {
    final r = await prepare();
    signHook = (d) async {
      if (d['primaryType'] == 'Action') now = now.add(const Duration(seconds: 30));
    };
    await expectLater(repo.submit(r, isCurrent: () => true), throwsA(isA<AccountReadFailure>()));
    expect(journal.snapshot.records, isEmpty);
  });
  test('withdrawal recovery requires exact returned ID, market, asset, chain and amount', () async {
    final op = (await repo.submit(await prepare(), isCurrent: () => true));
    TransferHistory history({
      String address = fixtureMaster,
      String id = '1234567',
      String asset = 'USDT',
      int chain = 56,
      String amount = '1',
      TransferMarket market = TransferMarket.perp,
    }) => TransferHistory(
      address: address,
      receivedAt: now,
      records: [
        TransferRecord(
          id: id,
          market: market,
          type: TransferType.withdraw,
          status: TransferStatus.success,
          asset: asset,
          amount: Decimal.parse(amount),
          recordTime: now,
          chainId: chain,
        ),
      ],
    );
    expect(reconcileWithdrawal(op, history())?.status, TransferStatus.success);
    expect(reconcileWithdrawal(op, history(id: 'other')), null);
    expect(reconcileWithdrawal(op, history(asset: 'BNB')), null);
    expect(reconcileWithdrawal(op, history(chain: 1)), null);
    expect(reconcileWithdrawal(op, history(amount: '1.000000000000000001')), null);
    expect(reconcileWithdrawal(op, history(market: TransferMarket.spot)), null);
    expect(reconcileWithdrawal(op, history(address: fixtureChild)), null);
    final pending = WalletOperationRecord(
      kind: op.kind,
      address: op.address,
      nonce: op.nonce,
      preparedAt: op.preparedAt,
      terms: op.terms,
    );
    expect(reconcileWithdrawal(pending, history()), null);
  });
}
