import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/authorization/data/trading_authorization_repository.dart';
import 'package:vanta/features/authorization/domain/trading_authorization.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/aster_spot_service.dart';
import 'package:vanta/features/portfolio/data/signed_account_request.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/aster_signatures.dart';
import '../../support/aster_account.dart';
import '../../support/aster_spot_account.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 8);
  final review = TradingAuthorizationReview(
    identity: const AuthIdentity(
      id: 'test',
      walletAddress: fixtureMaster,
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
    preparedAt: now,
    expiresAt: now.add(const Duration(days: 30)),
  );
  late List<http.Request> requests;
  late List<Map<String, Object?>> signed;
  late AsterTradingAuthorizationRepository repository;
  late bool current;
  Object? reply;
  Object? futuresReply, spotReply;
  Object? failure;
  Future<void> Function()? duringSign;
  setUp(() {
    requests = [];
    signed = [];
    current = true;
    reply = {'code': 200, 'msg': 'success'};
    failure = null;
    duringSign = null;
    futuresReply = accountPayload()..['canTrade'] = true;
    spotReply = spotPayload();
    final client = MockClient((r) async {
      requests.add(r);
      expect(r.followRedirects, false);
      if (r.url.path.endsWith('/time')) {
        return http.Response(jsonEncode({'serverTime': now.millisecondsSinceEpoch}), 200);
      }
      if (r.url.path.endsWith('registerAndApproveAgent')) {
        if (failure != null) throw failure!;
        return http.Response(jsonEncode(reply), 200);
      }
      return http.Response(
        jsonEncode(r.url.host.startsWith('sapi') ? spotReply : futuresReply),
        200,
      );
    });
    final futures = AsterAccountService(client: client), spot = AsterSpotService(client: client);
    repository = AsterTradingAuthorizationRepository(
      futures,
      spot,
      ({required expectedAddress, required typedData}) async {
        expect(expectedAddress, fixtureMaster);
        signed.add(typedData);
        await duringSign?.call();
        return fixtureSign(typedData);
      },
      nonces: AsterReadNonces(),
      now: () => now,
    );
    addTearDown(client.close);
  });
  test('same EOA grant has exact chain56 payload, 30days and no withdrawal/key/builder', () async {
    expect(
      await repository.enable(review: review, isCurrent: () => current),
      TradingAuthorizationResult.acknowledged,
    );
    final data = signed.single;
    expect((data['domain'] as Map)['chainId'], 56);
    final r = requests.last, p = Uri.splitQueryString(r.body);
    expect(r.method, 'POST');
    expect(r.url.path, '/fapi/v3/registerAndApproveAgent');
    expect(r.url.query, isEmpty);
    expect(p['user'], fixtureMaster);
    expect(p['agentAddress'], fixtureMaster);
    expect(p['canWithdraw'], 'false');
    expect(p['canSpotTrade'], 'true');
    expect(p['canPerpTrade'], 'true');
    expect(p['ipWhitelist'], '');
    expect(p['expired'], '${review.expiresAt.millisecondsSinceEpoch}');
    expect(p.keys.toSet(), {
      'user',
      'nonce',
      'agentName',
      'agentAddress',
      'expired',
      'signatureChainId',
      'canSpotTrade',
      'canPerpTrade',
      'canWithdraw',
      'ipWhitelist',
      'signature',
    });
    expect((data['message'] as Map)['msg'], r.body.split('&signature=').first);
  });
  test('explicit withdrawal grant signs exact encoded IP/CIDR whitelist bytes', () async {
    const ip = '203.0.113.8 2001:db8::/64';
    final grant = TradingAuthorizationReview(
      identity: review.identity,
      preparedAt: now,
      expiresAt: review.expiresAt,
      canWithdraw: true,
      ipWhitelist: ip,
    );
    expect(
      await repository.enable(review: grant, isCurrent: () => true),
      TradingAuthorizationResult.acknowledged,
    );
    final body = requests.last.body;
    expect(Uri.splitQueryString(body)['ipWhitelist'], ip);
    expect(Uri.splitQueryString(body)['canWithdraw'], 'true');
    expect(body, contains('ipWhitelist=203.0.113.8+2001%3Adb8%3A%3A%2F64'));
    expect((signed.single['message'] as Map)['msg'], body.split('&signature=').first);
  });
  for (final invalid in [
    '',
    'asterdex.com',
    '*',
    '203.0.113.1:443',
    'fe80::1%eth0',
    '1.2.3.4/33',
    '::1/129',
    '1.2.3.4/01',
    '1.2.3.4 1.2.3.4',
    List.filled(17, '1.2.3.4').join(' '),
  ]) {
    test('invalid withdrawal whitelist is rejected before network or signing: $invalid', () async {
      expect(normalizeAgentIpWhitelist(invalid), null);
      final grant = TradingAuthorizationReview(
        identity: review.identity,
        preparedAt: now,
        expiresAt: review.expiresAt,
        canWithdraw: true,
        ipWhitelist: invalid,
      );
      await expectLater(
        repository.enable(review: grant, isCurrent: () => true),
        throwsA(isA<AccountReadFailure>()),
      );
      expect(signed, isEmpty);
      expect(requests, isEmpty);
    });
  }
  test('withdrawal permission requires explicit selection even when whitelist supplied', () async {
    final grant = TradingAuthorizationReview(
      identity: review.identity,
      preparedAt: now,
      expiresAt: review.expiresAt,
      ipWhitelist: '203.0.113.8',
    );
    await expectLater(
      repository.enable(review: grant, isCurrent: () => true),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(requests, isEmpty);
    expect(signed, isEmpty);
  });
  test('literal whitelist normalization accepts bounded IPv4/IPv6 prefixes', () {
    expect(
      normalizeAgentIpWhitelist(' 203.0.113.1/32 \n 2001:db8::/64 '),
      '203.0.113.1/32 2001:db8::/64',
    );
    expect(normalizeAgentIpWhitelist('0.0.0.0/0 ::/0'), '0.0.0.0/0 ::/0');
  });
  for (final value in [true, false, null, 'true']) {
    test('withdraw permission account field is validated: $value', () async {
      futuresReply = accountPayload()..['canWithdraw'] = value;
      final r = await repository.check(address: fixtureMaster, isCurrent: () => true);
      expect(r.futuresReadAccepted, value is! String);
      expect(r.futuresCanWithdraw, value is bool ? value : null);
      expect(r.futuresCanTrade, value is String ? null : false);
    });
  }
  test('checks direct user/signer for both markets and preserves canTrade false', () async {
    futuresReply = accountPayload();
    final result = await repository.check(address: fixtureMaster, isCurrent: () => current);
    expect(result.futuresReadAccepted, true);
    expect(result.futuresCanTrade, false);
    expect(result.spotReadAccepted, true);
    expect(signed.length, 2);
    for (final d in signed) {
      expect((d['domain'] as Map)['chainId'], 1666);
      final p = Uri.splitQueryString((d['message'] as Map)['msg'] as String);
      expect(p['user'], fixtureMaster);
      expect(p['signer'], fixtureMaster);
    }
  });
  test('malformed money never establishes accepted access', () async {
    futuresReply = {
      'canTrade': true,
      'assets': [
        {'asset': 'USDT', 'walletBalance': 'oops'},
      ],
      'positions': <Object?>[],
    };
    spotReply = {'balances': 'bad'};
    final r = await repository.check(address: fixtureMaster, isCurrent: () => true);
    expect(r.futuresReadAccepted, false);
    expect(r.futuresCanTrade, null);
    expect(r.spotReadAccepted, false);
  });
  test('scope change after signature never posts', () async {
    duringSign = () async {
      current = false;
    };
    await expectLater(
      repository.enable(review: review, isCurrent: () => current),
      throwsA(isA<AccountReadFailure>()),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('timeout or malformed success is unknown without retry', () async {
    failure = TimeoutException('fixture');
    expect(
      await repository.enable(review: review, isCurrent: () => true),
      TradingAuthorizationResult.unknown,
    );
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
  for (final value in [
    null,
    {'code': 0},
    {'code': '200'},
    {'ok': true},
  ]) {
    test('noncontract acknowledgement $value is unknown', () async {
      reply = value;
      expect(
        await repository.enable(review: review, isCurrent: () => true),
        TradingAuthorizationResult.unknown,
      );
    });
  }
}
