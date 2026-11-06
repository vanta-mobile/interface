import 'dart:async';

import 'package:vanta/core/errors/api_error_details.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/data/subaccount_management_repository.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_management.dart';

import '../../support/aster_signatures.dart';

void main() {
  var now = DateTime.utc(2026, 11, 4, 8);
  const identity = AuthIdentity(
    id: 'master',
    walletAddress: fixtureMaster,
    walletKind: WalletKind.external,
    signingAvailable: true,
  );
  late AsterSubaccountManagementRepository repo;
  late MemoryWalletOperationJournal journal;
  late List<http.Request> requests;
  late bool current;
  late AuthIdentity activeIdentity;
  int signatures = 0;
  int children = 0;
  Object? postFailure;
  Object? reply;
  Future<void> Function()? signHook;
  Future<void> Function()? postHook;
  setUp(() {
    now = DateTime.utc(2026, 11, 4, 8);
    requests = [];
    current = true;
    activeIdentity = identity;
    signatures = 0;
    children = 0;
    postFailure = null;
    signHook = null;
    postHook = null;
    reply = {'code': 200, 'msg': 'success'};
    journal = MemoryWalletOperationJournal();
    final client = MockClient((r) async {
      requests.add(r);
      expect(r.followRedirects, false);
      if (r.url.path.endsWith('/time')) {
        return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
      }
      if (r.url.path.endsWith('/getSubAccountList')) {
        return http.Response(
          jsonEncode([
            {'accountId': 1, 'subAccountName': '', 'parentAccount': true},
            for (var i = 0; i < children; i++)
              {'accountId': i + 2, 'subAccountName': 'Desk $i', 'parentAccount': false},
          ]),
          200,
        );
      }
      expect(journal.snapshot.records.single.acknowledged, false);
      expect(encodeWalletOperations(journal.snapshot.records).contains('signature'), false);
      await postHook?.call();
      if (postFailure != null) throw postFailure!;
      return http.Response(jsonEncode(reply), 200);
    });
    addTearDown(client.close);
    addTearDown(journal.close);
    repo = AsterSubaccountManagementRepository(
      AsterAccountService(client: client),
      ({required expectedAddress, required typedData}) async {
        signatures++;
        await signHook?.call();
        return fixtureSign(typedData);
      },
      journal,
      nonces: AsterReadNonces(),
      now: () => now,
    );
  });
  Future<SubaccountManagementReview> prepare(
    WalletOperationKind kind, [
    Map<String, String>? terms,
  ]) => repo.prepare(
    identity: activeIdentity,
    kind: kind,
    terms: terms ?? {'child': fixtureChild, 'name': 'Desk A'},
    isCurrent: () => current,
  );
  for (final signable in [false, true]) {
    test(
      'Privy create signable=$signable is blocked before any signature, HTTP or journal',
      () async {
        activeIdentity = AuthIdentity(
          id: 'master',
          email: 'master@example.com',
          walletAddress: fixtureMaster,
          signingAvailable: signable,
        );
        await expectLater(
          prepare(WalletOperationKind.createSubaccount),
          throwsA(
            isA<AccountReadFailure>().having((e) => e.key, 'key', 'subaccountCreateExternalOnly'),
          ),
        );
        expect(signatures, 0);
        expect(requests, isEmpty);
        expect(journal.snapshot.records, isEmpty);
      },
    );
    test('forged Privy review signable=$signable cannot submit even a valid child proof', () async {
      final original = await prepare(WalletOperationKind.createSubaccount);
      final forged = SubaccountManagementReview(
        identity: AuthIdentity(
          id: identity.id,
          walletAddress: fixtureMaster,
          signingAvailable: signable,
        ),
        record: original.record,
        query: original.query,
      );
      final beforeRequests = requests.length, beforeSignatures = signatures;
      await expectLater(
        repo.submit(
          forged,
          childSignature: fixtureSign(forged.childTypedData, child: true),
          isCurrent: () => true,
        ),
        throwsA(
          isA<AccountReadFailure>().having((e) => e.key, 'key', 'subaccountCreateExternalOnly'),
        ),
      );
      expect(signatures, beforeSignatures);
      expect(requests.length, beforeRequests);
      expect(journal.snapshot.records, isEmpty);
    });
  }
  test('EOA with a linked email still creates with its own user and signer', () async {
    activeIdentity = const AuthIdentity(
      id: 'master',
      email: 'master@example.com',
      walletAddress: fixtureMaster,
      walletKind: WalletKind.external,
      signingAvailable: true,
    );
    final r = await prepare(WalletOperationKind.createSubaccount);
    await repo.submit(
      r,
      childSignature: fixtureSign(r.childTypedData, child: true),
      isCurrent: () => true,
    );
    final p = Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body);
    expect(p['user'], fixtureMaster);
    expect(p['signer'], fixtureMaster);
    expect(journal.snapshot.records.single.acknowledged, true);
  });
  test('disconnected external creation cannot prepare or submit a retained review', () async {
    final original = await prepare(WalletOperationKind.createSubaccount);
    activeIdentity = const AuthIdentity(
      id: 'master',
      walletAddress: fixtureMaster,
      walletKind: WalletKind.external,
    );
    final beforeRequests = requests.length, beforeSignatures = signatures;
    final reconnect = throwsA(
      isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletReconnect'),
    );
    await expectLater(prepare(WalletOperationKind.createSubaccount), reconnect);
    await expectLater(
      repo.submit(
        SubaccountManagementReview(
          identity: activeIdentity,
          record: original.record,
          query: original.query,
        ),
        childSignature: fixtureSign(original.childTypedData, child: true),
        isCurrent: () => true,
      ),
      reconnect,
    );
    expect(requests.length, beforeRequests);
    expect(signatures, beforeSignatures);
    expect(journal.snapshot.records, isEmpty);
  });
  test('margin operation cannot enter subaccount preparation or sign', () async {
    await expectLater(
      prepare(WalletOperationKind.isolatedMargin),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(requests, isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
  test('create independently verifies child and appends proof before master signs, persists unsigned terms', () async {
    final r = await prepare(WalletOperationKind.createSubaccount);
    expect((r.childTypedData['message'] as Map)['msg'], r.query);
    final child = fixtureSign(r.childTypedData, child: true);
    final result = await repo.submit(r, childSignature: child, isCurrent: () => current);
    expect(result.acknowledged, true);
    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '/fapi/v3/createSubAccount');
    expect(post.body.startsWith('${r.query}&childSignature=$child&signature='), true);
    final p = Uri.splitQueryString(post.body);
    expect(p['user'], fixtureMaster);
    expect(p['signer'], fixtureMaster);
    expect(p['subSourceAddr'], fixtureChild);
    expect(journal.snapshot.records.single.terms['child'], fixtureChild);
    expect(encodeWalletOperations(journal.snapshot.records), isNot(contains(child)));
  });
  test('wrong child proof prevents master submit signature and HTTP POST', () async {
    final r = await prepare(WalletOperationKind.createSubaccount);
    await expectLater(
      repo.submit(r, childSignature: fixtureSign(r.childTypedData), isCurrent: () => true),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'subaccountChildSignatureInvalid'),
      ),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
  for (final walletKind in WalletKind.values) {
    for (final k in [
      WalletOperationKind.freezeSubaccount,
      WalletOperationKind.unfreezeSubaccount,
    ]) {
      test(
        '$walletKind $k sends only selected child and explicit status, never guesses prior state',
        () async {
          activeIdentity = AuthIdentity(
            id: 'master',
            walletAddress: fixtureMaster,
            walletKind: walletKind,
            signingAvailable: true,
          );
          final r = await prepare(k, {'child': fixtureChild});
          await repo.submit(r, isCurrent: () => current);
          final post = requests.singleWhere((r) => r.method == 'POST'),
              p = Uri.splitQueryString(post.body);
          expect(post.url.path, '/fapi/v3/updateSubAccount');
          expect(p['status'], k == WalletOperationKind.freezeSubaccount ? 'FROZEN' : 'NORMAL');
          expect(p.containsKey('subAccountName'), false);
        },
      );
    }
    for (final direction in ['FUTURE_FUTURE', 'FUTURE_SPOT', 'SPOT_FUTURE', 'SPOT_SPOT']) {
      for (final reverse in [false, true]) {
        test(
          '$walletKind $direction reverse=$reverse preserves exact transfer terms and direct user signature',
          () async {
            activeIdentity = AuthIdentity(
              id: 'master',
              walletAddress: fixtureMaster,
              walletKind: walletKind,
              signingAvailable: true,
            );
            final terms = {
              'from': reverse ? fixtureChild : fixtureMaster,
              'to': reverse ? fixtureMaster : fixtureChild,
              'asset': 'USDT',
              'amount': '0.000000000000000001',
              'direction': direction,
            };
            final r = await prepare(WalletOperationKind.subaccountTransfer, terms);
            await repo.submit(r, isCurrent: () => current);
            final post = requests.singleWhere((r) => r.method == 'POST'),
                p = Uri.splitQueryString(post.body);
            expect(post.url.path, '/fapi/v3/subAccountTransfer');
            expect(p['amount'], terms['amount']);
            expect(p['fromAccountAddress'], terms['from']);
            expect(p['toAccountAddress'], terms['to']);
            expect(p['kindType'], direction);
            expect(p['user'], fixtureMaster);
            expect(p.containsKey('signer'), false);
          },
        );
      }
    }
  }
  test('ten-child creation rule blocks prepare without a create signature', () async {
    children = 10;
    await expectLater(
      prepare(WalletOperationKind.createSubaccount),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'subaccountLimitReached')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('count is rechecked after child signs and prevents racing eleventh creation', () async {
    final r = await prepare(WalletOperationKind.createSubaccount);
    children = 10;
    await expectLater(
      repo.submit(
        r,
        childSignature: fixtureSign(r.childTypedData, child: true),
        isCurrent: () => true,
      ),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('expired review does not sign or send', () async {
    final r = await prepare(WalletOperationKind.freezeSubaccount, {'child': fixtureChild});
    now = now.add(const Duration(seconds: 45));
    await expectLater(repo.submit(r, isCurrent: () => true), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('unknown result survives and blocks a new request without automatic retry', () async {
    final r = await prepare(WalletOperationKind.freezeSubaccount, {'child': fixtureChild});
    postFailure = TimeoutException('fixture');
    await expectLater(
      repo.submit(r, isCurrent: () => true),
      throwsA(
        isA<AccountReadFailure>()
            .having((e) => e.key, 'key', 'walletOperationUnknown')
            .having((e) => e.details?.cause, 'cause', ApiErrorCause.timeout),
      ),
    );
    expect(journal.snapshot.records.single.acknowledged, false);
    await expectLater(
      prepare(WalletOperationKind.freezeSubaccount, {'child': fixtureChild}),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'walletOperationPending')),
    );
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test('late response after logout is recorded for the original master', () async {
    final r = await prepare(WalletOperationKind.freezeSubaccount, {'child': fixtureChild});
    postHook = () async {
      current = false;
    };
    await repo.submit(r, isCurrent: () => current);
    expect(journal.snapshot.records.single.acknowledged, true);
    expect(journal.snapshot.records.single.address, fixtureMaster);
  });
  test('scope loss while master signs never writes or posts', () async {
    final r = await prepare(WalletOperationKind.freezeSubaccount, {'child': fixtureChild});
    signHook = () async {
      current = false;
    };
    await expectLater(repo.submit(r, isCurrent: () => current), throwsA(isA<AccountReadFailure>()));
    expect(journal.snapshot.records, isEmpty);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('same master/child and external-to-external transfer are rejected before reads', () async {
    await expectLater(
      prepare(WalletOperationKind.freezeSubaccount, {'child': fixtureMaster}),
      throwsA(isA<AccountReadFailure>()),
    );
    await expectLater(
      prepare(WalletOperationKind.subaccountTransfer, {
        'from': fixtureChild,
        'to': '0x3333333333333333333333333333333333333333',
        'asset': 'USDT',
        'amount': '1',
        'direction': 'SPOT_SPOT',
      }),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(requests, isEmpty);
  });
}
