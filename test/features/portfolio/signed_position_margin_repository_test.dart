import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/data/wallet_operation_journal.dart';
import 'package:vanta/core/domain/wallet_operation.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/position_margin_mapper.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/data/signed_position_margin_repository.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/position_margin_adjustment.dart';

import '../../support/aster_account.dart';
import '../../support/position_margin_adjustment.dart';
import '../../support/wallet_connection.dart';

class _FailPrepare extends MemoryWalletOperationJournal {
  @override
  Future<void> prepare(WalletOperationRecord record) async =>
      throw const WalletOperationStorageFailure();
}

class _FailReport extends MemoryWalletOperationJournal {
  @override
  Future<void> report(String key, [String? reference]) async =>
      throw const WalletOperationStorageFailure();
}

void main() {
  late SignedPositionMarginRepository repository;
  late AsterAccountService service;
  late MemoryWalletOperationJournal journal;
  late List<http.Request> requests;
  late List<String> messages;
  late Object? account, risks, tiers, history;
  late bool current, canSubmit;
  late int code, status, refuse;
  late DateTime now;
  Completer<http.Response>? postGate;
  var slowFinalSignature = false;
  void create() {
    service = AsterAccountService(
      decodeResponse: decodePositionMarginJson,
      client: MockClient((r) async {
        requests.add(r);
        expect(r.followRedirects, false);
        expect(r.url.host, 'fapi.asterdex.com');
        if (r.url.path.endsWith('/time')) {
          return http.Response(jsonEncode({'serverTime': marginClock.millisecondsSinceEpoch}), 200);
        }
        if (r.url.path.endsWith('/exchangeInfo')) {
          return http.Response(jsonEncode(contractPayload()), 200);
        }
        if (r.method == 'POST') {
          expect(r.url.path, '/fapi/v3/positionMargin');
          expect(journal.snapshot.records.single.acknowledged, false); // Durable BEFORE dispatch.
          return postGate?.future ??
              http.Response(
                jsonEncode({'code': code, 'amount': '10', 'type': 1, 'msg': 'private raw message'}),
                status,
              );
        }
        final payload = switch (r.url.path) {
          '/fapi/v3/accountWithJoinMargin' => account,
          '/fapi/v3/positionRisk' => risks,
          '/fapi/v3/leverageBrackets' => tiers,
          '/fapi/v3/positionMargin/history' => history,
          _ => throw StateError('Unexpected test path'),
        };
        return http.Response(jsonEncode(payload), 200);
      }),
    );
    repository = SignedPositionMarginRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, accountAddress);
        expect((typedData['domain'] as Map)['chainId'], 1666);
        if (slowFinalSignature && messages.length == 3) now = now.add(const Duration(seconds: 31));
        messages.add((typedData['message'] as Map)['msg'] as String);
        if (messages.length == refuse) throw const AuthFailure('authWalletRejected');
        return TestWalletConnection.signature;
      },
      journal,
      nonces: AsterReadNonces(),
      now: () => now,
    );
  }

  setUp(() {
    requests = [];
    messages = [];
    current = canSubmit = true;
    now = marginClock;
    code = 200;
    status = 200;
    refuse = 0;
    postGate = null;
    slowFinalSignature = false;
    account = marginAccount();
    risks = [marginRisk()];
    tiers = marginBrackets();
    history = [marginHistoryRow()];
    journal = MemoryWalletOperationJournal();
    create();
  });
  tearDown(() async {
    service.close();
    await journal.close();
  });
  Future<MarginAdjustmentResult> change({MarginDirection direction = MarginDirection.add}) =>
      repository.change(
        intent: PositionMarginIntent(
          context: marginContext(),
          direction: direction,
          amount: md('10'),
          reference: marginReference,
          revision: 0,
        ),
        isCurrent: () => current,
        canSubmit: () => canSubmit,
        onStep: (_) {},
      );
  Future<PositionMarginContext> read() => repository.read(
    address: accountAddress,
    symbol: 'BTCUSDT',
    side: 'BOTH',
    isCurrent: () => current,
    onStep: (_) {},
  );
  test('explicit read signs full account, scoped position and tiers with original EOA', () async {
    final c = await read();
    expect(c.addMax, md('80'));
    expect(c.removeMax, md('30'));
    final signed = requests.where((r) => r.url.queryParameters.containsKey('signature')).toList();
    expect(signed.map((r) => r.url.path), [
      '/fapi/v3/accountWithJoinMargin',
      '/fapi/v3/positionRisk',
      '/fapi/v3/leverageBrackets',
    ]);
    for (var i = 0; i < signed.length; i++) {
      expect(signed[i].url.query.split('&signature=').first, messages[i]);
      expect(signed[i].url.queryParameters['user'], accountAddress);
      expect(signed[i].url.queryParameters['signer'], accountAddress);
    }
    expect(signed.map((r) => r.url.queryParameters['nonce']).toSet().length, 3);
  });
  test(
    'confirmed POST exact positive amount, side, type and id; history verifies independently',
    () async {
      final result = await change();
      expect(result.verified, true);
      expect(result.context, isNotNull);
      final post = requests.singleWhere((r) => r.method == 'POST');
      final params = Uri.splitQueryString(post.body);
      expect(params, containsPair('clientTranId', marginReference));
      expect(params, containsPair('positionSide', 'BOTH'));
      expect(params, containsPair('type', '1'));
      expect(params, containsPair('amount', '10'));
      expect(params, containsPair('user', accountAddress));
      expect(params, containsPair('signer', accountAddress));
      expect(post.body.split('&signature=').first, messages[3]);
      expect(post.url.query, isEmpty);
      expect(params.keys.toSet(), {
        'symbol',
        'positionSide',
        'amount',
        'type',
        'clientTranId',
        'nonce',
        'user',
        'signer',
        'signature',
      });
      expect(journal.snapshot.records.single.reference, marginReference);
      expect(result.account, isNotNull);
      expect(result.positions, isNotNull);
      final after = requests.lastWhere((r) => r.url.path == '/fapi/v3/positionRisk');
      expect(
        after.url.queryParameters.containsKey('symbol'),
        false,
      ); // Full scope for the primary list.
    },
  );
  test('remove sends type 2; matching original direction required', () async {
    history = [marginHistoryRow(type: '2')];
    expect((await change(direction: MarginDirection.remove)).verified, true);
    expect(Uri.splitQueryString(requests.singleWhere((r) => r.method == 'POST').body)['type'], '2');
  });
  test('200 ACK without matching history is pending even if balances changed', () async {
    history = [];
    final result = await change();
    expect(result.verified, false);
    expect(journal.snapshot.records.single.acknowledged, false);
    expect(result.failure?.key, 'marginAdjustUnknown');
    history = [marginHistoryRow()];
    final recovered = await repository.check(
      record: journal.snapshot.records.single,
      isCurrent: () => current,
      onStep: (_) {},
    );
    expect(recovered.verified, true);
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test('timeout may be verified by exact history without a retry', () async {
    postGate = Completer<http.Response>();
    final pending = change();
    await Future<void>.delayed(Duration.zero);
    postGate!.completeError(TimeoutException('sensitive'));
    expect((await pending).verified, true);
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  test(
    'server rejection retains safe reason, saves rejected outcome and re-reads limits',
    () async {
      code = -4050;
      status = 400;
      history = [];
      final result = await change();
      expect(result.verified, false);
      expect(result.rejected, true);
      expect(result.failure?.key, 'marginAdjustInsufficient');
      expect(result.failure?.code, -4050);
      expect(result.context?.addMax, md('80'));
      expect(journal.snapshot.records.single.reference, 'rejected:-4050');
    },
  );
  test('ambiguous server error is retained as pending, never mistaken for rejection', () async {
    code = -1000;
    status = 503;
    history = [];
    expect((await change()).verified, false);
    expect(journal.snapshot.records.single.acknowledged, false);
  });
  test('known rejection whose report cannot be persisted stays blocked', () async {
    service.close();
    await journal.close();
    journal = _FailReport();
    create();
    code = -4050;
    status = 400;
    history = [];
    final result = await change();
    expect(result.verified, false);
    expect(journal.snapshot.records.single.acknowledged, false);
  });
  test(
    'journal failure prevents dispatch; wallet refusal never creates a pending intent',
    () async {
      service.close();
      await journal.close();
      journal = _FailPrepare();
      create();
      await expectLater(
        change(),
        throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'marginAdjustStorage')),
      );
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
  test('rejected final signing sends no POST or journal entry', () async {
    refuse = 4;
    await expectLater(
      change(),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'authWalletRejected')),
    );
    expect(journal.snapshot.records, isEmpty);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test(
    'wallet switch during POST leaves original public record and sends no query signature',
    () async {
      postGate = Completer<http.Response>();
      final pending = change();
      await Future<void>.delayed(Duration.zero);
      current = false;
      postGate!.complete(http.Response('{"code":200}', 200));
      final result = await pending;
      expect(result.verified, false);
      expect(messages.length, 4);
      expect(journal.snapshot.records.single.address, accountAddress);
      expect(journal.snapshot.records.single.acknowledged, false);
    },
  );
  test('late final signature cannot dispatch after both context deadlines', () async {
    slowFinalSignature = true;
    await expectLater(
      change(),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'marginAdjustExpired')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(journal.snapshot.records, isEmpty);
  });
  test('stale original context prevents even preflight', () async {
    now = now.add(const Duration(seconds: 30));
    await expectLater(change(), throwsA(isA<AccountReadFailure>()));
    expect(requests, isEmpty);
  });
  test('fresh preflight must agree on quantity, entry and wallet', () async {
    risks = [marginRisk(wallet: '51')];
    (account as Map)['positions'] = (marginAccount(wallet: '51')['positions']);
    await expectLater(
      change(),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'marginAdjustChanged')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('lower new max rejects old amount before dispatch', () async {
    account = marginAccount(available: '9');
    await expectLater(
      change(),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'marginAdjustAmount')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('closed or crossed position never provides a margin adjustment context', () async {
    risks = [];
    await expectLater(
      read(),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'marginAdjustClosed')),
    );
    risks = [marginRisk()..['marginType'] = 'cross'];
    await expectLater(
      read(),
      throwsA(isA<AccountReadFailure>().having((f) => f.key, 'key', 'marginAdjustUnsupported')),
    );
  });
  test('malformed same-ID history remains pending; other-ID match never verifies', () async {
    history = [marginHistoryRow()..['asset'] = 'BNB'];
    final result = await change();
    expect(result.verified, false);
    expect(result.failure?.key, 'accountDataInvalid');
    expect(journal.snapshot.records.single.acknowledged, false);
  });
  test('history exact success survives later failed account decoding but no new context', () async {
    await journal.prepare(marginRecord());
    account = {};
    final result = await repository.check(
      record: marginRecord(),
      isCurrent: () => true,
      onStep: (_) {},
    );
    expect(result.verified, true);
    expect(result.context, null);
    expect(result.failure?.key, 'accountDataInvalid');
  });
}
