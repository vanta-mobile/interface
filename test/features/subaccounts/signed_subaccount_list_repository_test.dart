import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/subaccounts/data/signed_subaccount_list_repository.dart';
import 'package:vanta/features/subaccounts/domain/subaccount_directory.dart';

import '../../support/aster_account.dart';
import '../../support/subaccounts.dart';
import '../../support/wallet_connection.dart';

void main() {
  late AsterAccountService service;
  late SignedSubaccountListRepository repository;
  late List<http.Request> requests;
  late List<Map<String, Object?>> messages;
  late AsterReadNonces nonces;
  late bool current;
  late String response;
  late int status;
  AuthFailure? failure;
  Completer<String>? signatureGate;
  Completer<http.Response>? readGate;
  const serverMilliseconds = 1793707200000;
  setUp(() {
    requests = [];
    messages = [];
    nonces = AsterReadNonces();
    current = true;
    response = jsonEncode(subaccountRows());
    status = 200;
    failure = null;
    signatureGate = null;
    readGate = null;
    service = AsterAccountService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.url.host, 'fapi.asterdex.com');
        expect(request.url.scheme, 'https');
        expect(request.followRedirects, false);
        expect(request.method, 'GET');
        if (request.url.path == '/fapi/v3/time') {
          return http.Response('{"serverTime":$serverMilliseconds}', 200);
        }
        expect(request.url.path, '/fapi/v3/getSubAccountList');
        return readGate?.future ?? http.Response.bytes(utf8.encode(response), status);
      }),
    );
    repository = SignedSubaccountListRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        messages.add(typedData);
        if (failure case final error?) throw error;
        return signatureGate?.future ?? TestWalletConnection.signature;
      },
      nonces: nonces,
      now: () => DateTime.fromMillisecondsSinceEpoch(serverMilliseconds, isUtc: true),
    );
  });
  tearDown(() => service.close());
  Future<SubaccountDirectory> read() =>
      repository.read(address: accountAddress, isCurrent: () => current, onStep: (_) {});
  test('only documented nonce/user/signer bytes are signed by connected EOA then GET; no wallet creation', () async {
    final steps = <AccountReadStep>[];
    final result = await repository.read(
      address: accountAddress,
      isCurrent: () => current,
      onStep: steps.add,
    );
    expect(result.childCount, 1);
    expect(result.address, accountAddress);
    expect(steps, [AccountReadStep.preparing, AccountReadStep.signing, AccountReadStep.loading]);
    expect(requests.map((r) => r.url.path), ['/fapi/v3/time', '/fapi/v3/getSubAccountList']);
    final typed = messages.single;
    expect((typed['domain'] as Map)['chainId'], 1666);
    expect(
      typed,
      asterReadTypedData(
        'nonce=${serverMilliseconds * 1000}&user=$accountAddress&signer=$accountAddress',
      ),
    );
    final request = requests.last;
    expect(request.url.query.split('&signature=').first, (typed['message'] as Map)['msg']);
    expect(request.url.queryParameters.keys, ['nonce', 'user', 'signer', 'signature']);
    expect(request.url.queryParameters['signature'], TestWalletConnection.signature);
    expect(request.body, isEmpty);
    expect(
      request.headers.keys.any(
        (k) => k.toLowerCase().contains('api') || k.toLowerCase() == 'authorization',
      ),
      false,
    );
  });
  test('shares monotonic microsecond counter across requests', () async {
    final prior = nonces.next(serverMilliseconds);
    await read();
    await read();
    final signed = requests.where((r) => r.url.path.endsWith('getSubAccountList')).toList();
    expect(signed.map((r) => r.url.queryParameters['nonce']), ['${prior + 1}', '${prior + 2}']);
  });
  test('rejected signing and invalid signature never send a private GET', () async {
    failure = const AuthFailure('authWalletRejected');
    await expectLater(
      read(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletRejected')),
    );
    expect(requests.length, 1);
    failure = null;
    signatureGate = Completer<String>()..complete('bad signature');
    await expectLater(
      read(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletSignature')),
    );
    expect(requests.every((r) => r.url.path.endsWith('/time')), true);
  });
  test(
    'scope loss while signing prevents send and scope loss after GET prevents acceptance',
    () async {
      signatureGate = Completer();
      final pending = read();
      await Future<void>.delayed(Duration.zero);
      current = false;
      signatureGate!.complete(TestWalletConnection.signature);
      await expectLater(pending, throwsA(isA<AccountReadFailure>()));
      expect(requests.length, 1);
      current = true;
      signatureGate = null;
      readGate = Completer();
      final next = read();
      await Future<void>.delayed(Duration.zero);
      current = false;
      readGate!.complete(http.Response.bytes(utf8.encode(response), 200));
      await expectLater(
        next,
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
      );
    },
  );
  test(
    'malformed list is a safe data failure; server authorization error keeps its safe code',
    () async {
      response = '{}';
      await expectLater(
        read(),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid')),
      );
      response = '{"code":-2015,"msg":"raw sensitive server detail"}';
      status = 403;
      await expectLater(
        read(),
        throwsA(
          isA<AccountReadFailure>()
              .having((e) => e.key, 'key', 'accountPermissionRequired')
              .having((e) => e.code, 'code', -2015),
        ),
      );
    },
  );
  test('redirects are rejected without forwarding a signed URL', () async {
    response = '{}';
    status = 302;
    await expectLater(read(), throwsA(isA<AccountReadFailure>()));
    expect(requests.length, 2);
    expect(requests.last.followRedirects, false);
  });
}
