import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/data/aster_signature_verifier.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/data/builder_approval_journal.dart';
import 'package:vanta/features/authorization/data/builder_authorization_mapper.dart';
import 'package:vanta/features/authorization/data/builder_authorization_repository.dart';
import 'package:vanta/features/authorization/data/trading_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/trading_agent.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/authorization/domain/builder_authorization.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_signatures.dart';
import '../../support/builder.dart';
import '../../support/trading_agents.dart';

class _ApprovalStopwatch extends Stopwatch {
  Duration age = Duration.zero;
  @override
  Duration get elapsed => age;
}

void main() {
  final now = DateTime.utc(2026, 11, 16);
  final review = TradingAuthorizationReview(
    identity: const AuthIdentity(id: 'owner', walletAddress: fixtureMaster, signingAvailable: true),
    preparedAt: now,
    expiresAt: now.add(const Duration(days: 30)),
  );
  late MemoryBuilderApprovalJournal journal;
  late AsterAccountService service;
  late AsterBuilderAuthorizationRepository repo;
  late List<http.Request> requests;
  late List<Map<String, Object?>> signatures;
  late _ApprovalStopwatch approvalClock;
  late bool current, loseReply, acceptPost, malformed, signatureRefused, rejectReadback;
  Decimal? grant;
  int? errorCode;
  Future<void> Function()? duringSign;

  List<Map<String, Object?>> rows() => [
    if (grant != null)
      {
        'userAddress': fixtureMaster,
        'builderAddress': VantaBuilder.address,
        'maxFeeRate': grant.toString(),
      },
  ];
  setUp(() {
    journal = MemoryBuilderApprovalJournal();
    requests = [];
    signatures = [];
    approvalClock = _ApprovalStopwatch();
    current = true;
    loseReply = false;
    acceptPost = true;
    malformed = false;
    signatureRefused = false;
    rejectReadback = false;
    grant = null;
    errorCode = null;
    duringSign = null;
    service = AsterAccountService(
      client: MockClient((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/time')) {
          return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
        }
        if (r.method == 'GET') {
          expect(r.url.path, '/fapi/v3/builder');
          expect(r.url.queryParameters['user'], fixtureMaster);
          expect(r.url.queryParameters['signer'], fixtureChild);
          expect(
            verifyAsterWalletSignature(
              fixtureChild,
              asterReadTypedData(r.url.query.split('&signature=').first),
              r.url.queryParameters['signature']!,
            ),
            true,
          );
          if (rejectReadback && requests.any((request) => request.method == 'POST')) {
            return http.Response('{"message":"Signature check failed"}', 400);
          }
          return http.Response(jsonEncode(rows()), 200);
        }
        expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.unknown);
        final params = Uri.splitQueryString(r.body);
        expect(params['builder'], VantaBuilder.address);
        expect(params['maxFeeRate'], '0.0005');
        expect(params['signatureChainId'], '56');
        expect(params['asterChain'], 'Mainnet');
        expect(params.containsKey('signer'), false);
        expect(
          verifyAsterWalletSignature(fixtureMaster, signatures.last, params['signature']!),
          true,
        );
        if (signatureRefused) {
          return http.Response('{"message":"Signature check failed"}', 400);
        }
        if (errorCode != null) {
          return http.Response(
            jsonEncode({'code': errorCode, 'msg': 'Builder is not registered'}),
            400,
          );
        }
        if (acceptPost) grant = VantaBuilder.approvalCap;
        if (loseReply) throw TimeoutException('fixture');
        return http.Response(malformed ? '{}' : '{"code":200}', 200);
      }),
    );
    repo = AsterBuilderAuthorizationRepository(
      service,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, fixtureMaster);
        signatures.add(typedData);
        await duringSign?.call();
        return fixtureSign(typedData);
      },
      nonces: AsterReadNonces(),
      journal: journal,
      authorization: builderTestAgent,
      stopwatch: () => approvalClock,
      now: () => now,
    );
    addTearDown(service.close);
  });
  Future<TradingAuthorizationResult> enable() =>
      repo.enable(review: review, isCurrent: () => current);

  for (final update in [false, true]) {
    for (final seconds in [12, 49]) {
      test(
        'Builder ${update ? 'update' : 'approval'} accepts a ${seconds}s wallet confirmation',
        () async {
          if (update) grant = Decimal.parse('0.00001');
          duringSign = () async {
            approvalClock.age = Duration(seconds: seconds);
          };
          expect(await enable(), TradingAuthorizationResult.acknowledged);
          expect(signatures.single['primaryType'], update ? 'UpdateBuilder' : 'ApproveBuilder');
          expect(requests.where((r) => r.method == 'POST'), hasLength(1));
          expect(
            journal.records[fixtureMaster.toLowerCase()]?.status,
            BuilderApprovalStatus.approved,
          );
        },
      );
    }
  }
  for (final seconds in [50, 60]) {
    test(
      'a ${seconds}s Builder signature expires before dispatch without a new pending marker',
      () async {
        duringSign = () async {
          approvalClock.age = Duration(seconds: seconds);
        };
        await expectLater(
          enable(),
          throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountSignatureExpired')),
        );
        expect(signatures, hasLength(1));
        expect(requests.where((r) => r.method == 'POST'), isEmpty);
        expect(journal.records, isEmpty);
      },
    );
  }
  test('secure storage time counts toward Builder expiry and rolls back before dispatch', () async {
    duringSign = () async {
      approvalClock.age = const Duration(seconds: 49);
    };
    journal.onSaved = (record) {
      if (record.status == BuilderApprovalStatus.unknown) {
        approvalClock.age += const Duration(seconds: 1);
      }
    };
    await expectLater(
      enable(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountSignatureExpired')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.rejected);
    journal.onSaved = null;
    duringSign = () async {
      approvalClock.age = const Duration(seconds: 12);
    };
    expect(await enable(), TradingAuthorizationResult.acknowledged);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  test(
    'owner approves exact dynamic EIP-712 fields; agent verifies binding; repeat is read-only',
    () async {
      expect(await enable(), TradingAuthorizationResult.acknowledged);
      final data = signatures.single;
      expect(data['primaryType'], 'ApproveBuilder');
      expect((data['domain'] as Map)['chainId'], 56);
      expect((data['types'] as Map)['ApproveBuilder'], [
        {'name': 'Builder', 'type': 'string'},
        {'name': 'MaxFeeRate', 'type': 'string'},
        {'name': 'BuilderName', 'type': 'string'},
        {'name': 'AsterChain', 'type': 'string'},
        {'name': 'User', 'type': 'string'},
        {'name': 'Nonce', 'type': 'uint256'},
      ]);
      expect((data['message'] as Map)['BuilderName'], 'Vanta');
      expect((data['message'] as Map)['AsterChain'], 'Mainnet');
      expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.approved);
      expect(await enable(), TradingAuthorizationResult.acknowledged);
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(signatures, hasLength(1));
    },
  );
  test('existing insufficient cap uses UpdateBuilder without BuilderName', () async {
    grant = Decimal.parse('0.00001');
    expect(await enable(), TradingAuthorizationResult.acknowledged);
    expect(signatures.single['primaryType'], 'UpdateBuilder');
    expect((signatures.single['message'] as Map).containsKey('BuilderName'), false);
    expect((signatures.single['message'] as Map)['AsterChain'], 'Mainnet');
    expect((signatures.single['types'] as Map)['UpdateBuilder'], [
      {'name': 'Builder', 'type': 'string'},
      {'name': 'MaxFeeRate', 'type': 'string'},
      {'name': 'AsterChain', 'type': 'string'},
      {'name': 'User', 'type': 'string'},
      {'name': 'Nonce', 'type': 'uint256'},
    ]);
    expect(requests.singleWhere((r) => r.method == 'POST').url.path, '/fapi/v3/updateBuilder');
  });
  test('lost reply recovers by read after restart; no signature or approval replay', () async {
    loseReply = true;
    await expectLater(
      enable(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderApprovalUnknown')),
    );
    expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.unknown);
    repo = AsterBuilderAuthorizationRepository(
      service,
      fixtureWalletSign,
      nonces: AsterReadNonces(),
      journal: journal,
      authorization: builderTestAgent,
      now: () => now,
    );
    expect(await enable(), TradingAuthorizationResult.acknowledged);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test('an absent read never proves an unknown dispatched approval can be replayed', () async {
    loseReply = true;
    acceptPost = false;
    await expectLater(enable(), throwsA(isA<AccountReadFailure>()));
    expect(await enable(), TradingAuthorizationResult.unknown);
    expect(await enable(), TradingAuthorizationResult.unknown);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test(
    'renewed signing recovers a legacy pending Builder without registering the active Agent',
    () async {
      await journal.save(
        fixtureMaster,
        BuilderApprovalRecord(
          status: BuilderApprovalStatus.unknown,
          maxFeeRate: VantaBuilder.approvalCap,
        ),
      );
      final store = MemoryTradingAgentStorage().store(() => now);
      final agent = await store.prepare('owner', fixtureMaster, review.expiresAt);
      await store.setStatus(agent, TradingAgentStatus.unknown);
      await store.setStatus(agent, TradingAgentStatus.active);
      final spot = AsterSpotService();
      addTearDown(spot.close);
      final trading = AsterTradingAuthorizationRepository(
        service,
        spot,
        fixtureWalletSign,
        agents: store,
        builder: repo,
        nonces: AsterReadNonces(),
        now: () => now,
      );
      expect(
        await trading.enable(review: review, isCurrent: () => current),
        TradingAuthorizationResult.unknown,
      );
      expect(signatures, isEmpty);
      expect(
        await trading.enable(review: review, isCurrent: () => current, retryPendingBuilder: true),
        TradingAuthorizationResult.acknowledged,
      );
      expect(requests.where((r) => r.method == 'POST').map((r) => r.url.path), [
        '/fapi/v3/approveBuilder',
      ]);
      expect(signatures.single['primaryType'], 'ApproveBuilder');
      expect((await store.load('owner', fixtureMaster))?.address, agent.address);
      expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.approved);
    },
  );
  test('renewed request uses a sufficient live binding without another wallet signature', () async {
    loseReply = true;
    await expectLater(enable(), throwsA(isA<AccountReadFailure>()));
    expect(
      await repo.enable(review: review, isCurrent: () => current, retryPendingBuilder: true),
      TradingAuthorizationResult.acknowledged,
    );
    expect(signatures, hasLength(1));
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test('an unconfirmed renewed attempt is not automatically replayed', () async {
    await journal.save(
      fixtureMaster,
      BuilderApprovalRecord(
        status: BuilderApprovalStatus.unknown,
        maxFeeRate: VantaBuilder.approvalCap,
      ),
    );
    loseReply = true;
    acceptPost = false;
    await expectLater(
      repo.enable(review: review, isCurrent: () => current, retryPendingBuilder: true),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderApprovalUnknown')),
    );
    expect((await repo.check(address: fixtureMaster, isCurrent: () => current)).sufficient, false);
    expect(await enable(), TradingAuthorizationResult.unknown);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.unknown);
  });
  test('another renewed request cannot dispatch while the first is awaiting a signature', () async {
    final signing = Completer<void>(), release = Completer<void>();
    duringSign = () async {
      signing.complete();
      await release.future;
    };
    final first = repo.enable(review: review, isCurrent: () => current, retryPendingBuilder: true);
    await signing.future;
    await expectLater(
      repo.enable(review: review, isCurrent: () => current, retryPendingBuilder: true),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderApprovalUnknown')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    release.complete();
    expect(await first, TradingAuthorizationResult.acknowledged);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test(
    'HTTP success with malformed acknowledgement remains unknown until explicit check',
    () async {
      malformed = true;
      expect(await enable(), TradingAuthorizationResult.unknown);
      expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.unknown);
      expect((await repo.check(address: fixtureMaster, isCurrent: () => current)).sufficient, true);
      expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.approved);
    },
  );
  test(
    'concrete business refusal preserves server detail and allows only explicit retry',
    () async {
      errorCode = -1130;
      await expectLater(
        enable(),
        throwsA(
          isA<AccountReadFailure>().having(
            (e) => e.details?.message,
            'message',
            'Builder is not registered',
          ),
        ),
      );
      expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.rejected);
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      errorCode = null;
      expect(await enable(), TradingAuthorizationResult.acknowledged);
      expect(requests.where((r) => r.method == 'POST'), hasLength(2));
    },
  );
  test('HTTP 400 refusal without a numeric code permits only a new explicit attempt', () async {
    signatureRefused = true;
    await expectLater(
      enable(),
      throwsA(
        isA<AccountReadFailure>()
            .having((e) => e.key, 'key', 'accountReadFailed')
            .having((e) => e.details?.message, 'message', 'Signature check failed')
            .having((e) => e.details?.status, 'status', 400),
      ),
    );
    expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.rejected);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    signatureRefused = false;
    expect(await enable(), TradingAuthorizationResult.acknowledged);
    expect(requests.where((r) => r.method == 'POST'), hasLength(2));
  });
  test('HTTP 400 from read-back after an accepted POST never permits another approval', () async {
    rejectReadback = true;
    await expectLater(
      enable(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderApprovalUnknown')),
    );
    expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.unknown);
    rejectReadback = false;
    grant = null;
    expect(await enable(), TradingAuthorizationResult.unknown);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test('ambiguous exchange refusal codes remain unknown despite HTTP 400', () async {
    errorCode = -1007;
    await expectLater(
      enable(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'builderApprovalUnknown')),
    );
    expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.unknown);
    errorCode = null;
    expect(await enable(), TradingAuthorizationResult.unknown);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test('wallet switch during signature and storage failures prevent dispatch', () async {
    duringSign = () async {
      current = false;
    };
    await expectLater(enable(), throwsA(isA<AccountReadFailure>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(journal.records, isEmpty);
    current = true;
    duringSign = null;
    journal.failure = StateError('storage');
    await expectLater(enable(), throwsA(isA<StateError>()));
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('scope expired before start does not read or sign', () async {
    current = false;
    await expectLater(enable(), throwsA(isA<AccountReadFailure>()));
    expect(requests, isEmpty);
    expect(signatures, isEmpty);
  });
  test('a local interruption after journaling but before POST is not a pending approval', () async {
    journal.onSaved = (record) {
      if (record.status == BuilderApprovalStatus.unknown) current = false;
    };
    await expectLater(
      enable(),
      throwsA(isA<AccountReadFailure>().having((e) => e.key, 'key', 'authWalletChanged')),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.rejected);
    current = true;
    journal.onSaved = null;
    expect(await enable(), TradingAuthorizationResult.acknowledged);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });
  test('revocation is recorded by live check rather than trusting old local approval', () async {
    expect(await enable(), TradingAuthorizationResult.acknowledged);
    grant = null;
    expect((await repo.check(address: fixtureMaster, isCurrent: () => current)).bound, false);
    expect(journal.records[fixtureMaster.toLowerCase()]?.status, BuilderApprovalStatus.rejected);
  });
  test('mapper rejects mismatched owners, duplicate bindings and invalid caps', () {
    final row = {
      'userAddress': fixtureMaster,
      'builderAddress': VantaBuilder.address,
      'maxFeeRate': 0.0005,
    };
    expect(mapBuilderAuthorization([row], fixtureMaster).sufficient, true);
    expect(mapBuilderAuthorization([], fixtureMaster).bound, false);
    for (final value in [
      <String, Object?>{},
      [row, row],
      [
        {...row, 'userAddress': fixtureChild},
      ],
      [
        {...row, 'maxFeeRate': -1},
      ],
      [
        {...row, 'maxFeeRate': '0.01'},
      ],
      [
        {...row, 'maxFeeRate': true},
      ],
    ]) {
      expect(() => mapBuilderAuthorization(value, fixtureMaster), throwsFormatException);
    }
  });
  test('durable dispatch records survive reinstantiation and are partitioned by owner', () async {
    final values = <String, String>{};
    DeviceBuilderApprovalJournal store() => DeviceBuilderApprovalJournal(
      read: (k) async => values[k],
      write: (k, v) async {
        values[k] = v;
      },
    );
    await store().save(
      fixtureMaster,
      BuilderApprovalRecord(
        status: BuilderApprovalStatus.unknown,
        maxFeeRate: VantaBuilder.approvalCap,
      ),
    );
    expect((await store().load(fixtureMaster))?.status, BuilderApprovalStatus.unknown);
    expect(await store().load(fixtureChild), null);
    values[values.keys.single] = '{}';
    await expectLater(
      store().load(fixtureMaster),
      throwsA(
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'authorizationSecureStorageFailed'),
      ),
    );
  });
}
