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
import 'package:vanta/features/auth/domain/wallet_signing_preparation.dart';
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

class _Network implements WalletSigningPreparation {
  final chains = <int>[];
  @override
  Future<void> prepareSigning({
    required String expectedAddress,
    required int chainId,
    required bool Function() isCurrent,
  }) async {
    expect(expectedAddress, fixtureMaster);
    chains.add(chainId);
  }
}

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
  late int replyStatus;
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
    replyStatus = 200;
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
      expect(journal.snapshot.records.last.acknowledged, false);
      expect(encodeWalletOperations(journal.snapshot.records).contains('Signature'), false);
      await postHook?.call();
      if (postFailure != null) throw postFailure!;
      return http.Response(jsonEncode(reply), replyStatus);
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
      '$market revalidates qualification/fee/limits and binds both signatures with distinct microsecond nonces',
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
        expect(int.parse(p['nonce']!) ~/ 1000, now.millisecondsSinceEpoch);
        expect(int.parse(p['nonce']!), greaterThan(int.parse(p['userNonce']!)));
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
  for (final chain in [56, 1]) {
    test(
      'chain $chain: agent signs the review reads; owner signs the Action and envelope',
      () async {
        if (chain != 56) {
          catalog.rows = [fundingAssetRow(chain: chain)];
          info = withdrawInfoPayload();
          ((info['balances'] as Map)['USDT'] as Map)['chainBalances'] = {
            '$chain': withdrawChainRow()..['chainId'] = chain,
          };
        }
        final client = MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/time')) {
            return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
          }
          if (r.url.path.endsWith('/getSubAccountList')) {
            return http.Response(
              jsonEncode([
                {'accountId': 1, 'subAccountName': '', 'parentAccount': true},
              ]),
              200,
            );
          }
          if (r.url.path.endsWith('/user-withdraw-info')) {
            return http.Response(jsonEncode(info), 200);
          }
          return http.Response(jsonEncode(reply), 200);
        });
        addTearDown(client.close);
        final agentSigned = <Map<String, Object?>>[], network = _Network();
        repo = AsterWithdrawalRepository(
          AsterAccountService(client: client),
          AsterSpotService(client: client),
          catalog,
          fees,
          ({required expectedAddress, required typedData}) async {
            expect(expectedAddress, fixtureMaster);
            signed.add(typedData);
            return fixtureSign(typedData);
          },
          journal,
          nonces: AsterReadNonces(),
          authorization: (owner) async => AccountRequestIdentity(
            address: fixtureChild,
            sign: ({required expectedAddress, required typedData}) async {
              expect(expectedAddress, fixtureChild);
              agentSigned.add(typedData);
              return fixtureSign(typedData, child: true);
            },
          ),
          signingPreparation: network,
          now: () => now,
        );
        final review = await repo.prepare(
          identity: identity,
          query: depositQuery(route: 'autoWithdraw', minimum: null, chain: chain),
          amount: '1',
          isCurrent: () => current,
        );
        final result = await repo.submit(review, isCurrent: () => current);
        expect(result.reference, '1234567');
        // Two reads per review: the explicit prepare and the one repeated at submit.
        expect(agentSigned, hasLength(4));
        expect(agentSigned.every((d) => (d['domain'] as Map)['chainId'] == 1666), true);
        expect(signed.map((d) => d['primaryType']), ['Action', 'Message']);
        expect((signed.first['domain'] as Map)['chainId'], chain);
        expect((signed.last['domain'] as Map)['chainId'], 56);
        expect(network.chains, chain == 56 ? [56] : [chain, 56]);
        final post = requests.singleWhere((r) => r.url.path.endsWith('/user-withdraw')),
            p = post.url.queryParameters;
        expect(p['user'], fixtureMaster);
        expect(p['signer'], fixtureMaster);
        expect(p['signatureChainId'], '56');
        expect(p['chainId'], '$chain');
        expect((signed.last['message'] as Map)['msg'], post.url.query.split('&signature=').first);
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
  test('unknown result stays durable without blocking a separately signed withdrawal', () async {
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
    expect(journal.snapshot.records.last.acknowledged, false);
    final next = await prepare();
    expect(requests.where((r) => r.url.path.endsWith('/user-withdraw')).length, 1);
    postFailure = null;
    reply = {'withdrawId': 'new-withdrawal', 'hash': '0x${'d' * 64}'};
    final submitted = await repo.submit(next, isCurrent: () => current);
    expect(submitted.reference, 'new-withdrawal');
    expect(journal.snapshot.records, hasLength(2));
    expect(journal.snapshot.records.first.acknowledged, false);
    expect(journal.snapshot.records.last.acknowledged, true);
    expect(journal.snapshot.records.map((r) => r.key).toSet(), hasLength(2));
    expect(requests.where((r) => r.url.path.endsWith('/user-withdraw')).length, 2);
  });
  test('an explicit Aster refusal shows its error and clears the record', () async {
    final r = await prepare();
    replyStatus = 401;
    reply = {'code': -2015, 'msg': 'Invalid API-key, IP, or permissions for action.'};
    await expectLater(
      repo.submit(r, isCurrent: () => current),
      throwsA(
        isA<AccountReadFailure>()
            .having((e) => e.code, 'code', -2015)
            .having(
              (e) => e.details?.message,
              'message',
              'Invalid API-key, IP, or permissions for action.',
            ),
      ),
    );
    expect(journal.snapshot.records, isEmpty);
  });
  for (final status in [429, 500, 503]) {
    test('HTTP $status after dispatch keeps the outcome for recovery', () async {
      final r = await prepare();
      replyStatus = status;
      reply = {'code': -1000, 'msg': 'error'};
      await expectLater(
        repo.submit(r, isCurrent: () => current),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'walletOperationUnknown')),
      );
      expect(journal.snapshot.records.single.acknowledged, false);
    });
  }
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

  group('entered receiver', () {
    const embedded = AuthIdentity(
      id: 'master',
      walletAddress: fixtureMaster,
      signingAvailable: true,
    );
    // EIP-55 reference vector.
    const receiver = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
    Future<WithdrawalReview> prepareFor(AuthIdentity who, String? to) => repo.prepare(
      identity: who,
      query: query(),
      amount: '1',
      receiver: to,
      isCurrent: () => current,
    );

    test('embedded wallet signs and sends the entered destination from its own account', () async {
      final r = await prepareFor(embedded, receiver);
      await repo.submit(r, isCurrent: () => current);
      final p = requests
          .singleWhere((r) => r.url.path.endsWith('/user-withdraw'))
          .url
          .queryParameters;
      expect(p['receiver'], receiver);
      expect(p['user'], fixtureMaster);
      expect(p['signer'], fixtureMaster);
      final action = signed.singleWhere((d) => d['primaryType'] == 'Action');
      expect((action['message'] as Map)['destination'], receiver);
      expect(journal.snapshot.records.single.address, fixtureMaster);
      expect(journal.snapshot.records.single.terms['receiver'], receiver);
      // The journal round-trips a record whose receiver is not the signer.
      expect(
        decodeWalletOperations(encodeWalletOperations(journal.snapshot.records)).single.terms,
        journal.snapshot.records.single.terms,
      );
    });

    for (final bad in [
      null,
      '',
      '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeD',
      '0x${'0' * 40}',
      '5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
    ]) {
      test('embedded wallet rejects receiver $bad before any request', () async {
        await expectLater(
          prepareFor(embedded, bad),
          throwsA(
            isA<AccountReadFailure>().having((e) => e.key, 'key', 'withdrawalReceiverInvalid'),
          ),
        );
        expect(signed, isEmpty);
        expect(requests, isEmpty);
      });
    }

    test('external wallet always withdraws to itself', () async {
      final r = await prepareFor(identity, receiver);
      expect(r.receiver, fixtureMaster);
      await repo.submit(r, isCurrent: () => current);
      final p = requests
          .singleWhere((r) => r.url.path.endsWith('/user-withdraw'))
          .url
          .queryParameters;
      expect(p['receiver'], fixtureMaster);
    });
  });
}
