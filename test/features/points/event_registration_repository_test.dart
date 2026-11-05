import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_message_signer.dart';
import 'package:vanta/features/points/data/event_registration_repository.dart';
import 'package:vanta/features/points/domain/event_registration.dart';

import '../../support/points.dart';
import '../../support/trading_events.dart';

class _Signer implements WalletMessageSigner {
  final calls = <(String, String)>[];
  Future<void> Function()? onSign;
  String signature = '0x${'1' * 130}';
  @override
  Future<String> signPersonalMessage({
    required String expectedAddress,
    required String message,
  }) async {
    calls.add((expectedAddress, message));
    await onSign?.call();
    return signature;
  }
}

void main() {
  late DateTime now;
  late TestPointsRepository points;
  late _Signer signer;
  late bool current;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) response;
  late VantaEventRegistrationRepository repository;
  late List<EventRegistrationPhase> steps;
  EventRegistrationApproval approval() => EventRegistrationApproval(
    event: tradingEventFixture(),
    identity: const AuthIdentity(
      id: 'test',
      walletAddress: pointsTestAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
  );
  Future<EventRegistrationPhase> register({void Function(EventRegistrationPhase)? step}) =>
      repository.register(approval(), isCurrent: () => current, onStep: step ?? steps.add);
  setUp(() {
    now = DateTime.utc(2026, 11, 4, 12);
    points = TestPointsRepository(now: () => now);
    signer = _Signer();
    current = true;
    requests = [];
    steps = [];
    response = (_) async {
      points.registered = true;
      return http.Response('', 200);
    };
    repository = VantaEventRegistrationRepository(
      points: points,
      signer: () => signer,
      now: () => now,
      client: MockClient((r) {
        requests.add(r);
        return response(r);
      }),
      timeout: const Duration(milliseconds: 20),
    );
  });
  tearDown(() => repository.close());
  test('one current-wallet message and JSON POST; two fresh preflights then verify registration', () async {
    expect(await register(), EventRegistrationPhase.verified);
    expect(signer.calls.single, (
      pointsTestAddress,
      'Vanta Trading Event Registration\nEvent ID: 11\nAddress: $pointsTestAddress\nTimestamp: ${now.millisecondsSinceEpoch}',
    ));
    expect(requests.length, 1);
    final r = requests.single;
    expect(r.url.toString(), 'https://api.vanta.exchange/api/trading-events/11/register');
    expect(r.method, 'POST');
    expect(r.followRedirects, false);
    expect(r.headers, {'Accept': 'application/json', 'Content-Type': 'application/json'});
    expect(jsonDecode(r.body), {
      'address': pointsTestAddress,
      'timestamp': now.millisecondsSinceEpoch,
      'signature': signer.signature,
    });
    expect(points.calls, [
      'event:11',
      'participant:11:$pointsTestAddress',
      'event:11',
      'participant:11:$pointsTestAddress',
      'participant:11:$pointsTestAddress',
    ]);
    expect(steps, [
      EventRegistrationPhase.checking,
      EventRegistrationPhase.signing,
      EventRegistrationPhase.checking,
      EventRegistrationPhase.sending,
    ]);
  });
  test('existing registration never signs or resubmits', () async {
    points.registered = true;
    expect(await register(), EventRegistrationPhase.verified);
    expect(signer.calls, isEmpty);
    expect(requests, isEmpty);
  });
  for (final issue in ['ended', 'blocked', 'wrongEvent', 'wrongAddress', 'changedRules', 'scope']) {
    test('preflight $issue prevents signature and POST', () async {
      if (issue == 'ended') points.eventValue = tradingEventFixture(status: 'ENDED');
      if (issue == 'blocked') points.blockReason = 'blacklist';
      if (issue == 'wrongEvent') points.wrongEvent = 12;
      if (issue == 'wrongAddress') points.wrongAddress = true;
      if (issue == 'changedRules') points.eventValue = tradingEventFixture(id: 9);
      if (issue == 'scope') current = false;
      await expectLater(register(), throwsA(isA<EventRegistrationFailure>()));
      expect(signer.calls, isEmpty);
      expect(requests, isEmpty);
    });
  }
  for (final issue in ['scope', 'ended', 'blocked', 'expired', 'clockRollback', 'signature']) {
    test('post-signature $issue cannot dispatch', () async {
      signer.onSign = () async {
        if (issue == 'scope') current = false;
        if (issue == 'ended') points.eventValue = tradingEventFixture(status: 'ENDED');
        if (issue == 'blocked') points.blockReason = 'exclusive';
        if (issue == 'expired') now = now.add(const Duration(minutes: 2, milliseconds: 1));
        if (issue == 'clockRollback') now = now.subtract(const Duration(seconds: 1));
      };
      if (issue == 'signature') signer.signature = 'not-a-signature';
      await expectLater(
        register(),
        throwsA(anyOf(isA<EventRegistrationFailure>(), isA<AuthFailure>())),
      );
      expect(signer.calls.length, 1);
      expect(requests, isEmpty);
    });
  }
  test('another client completing registration while wallet signs does not resubmit', () async {
    signer.onSign = () async {
      points.registered = true;
    };
    expect(await register(), EventRegistrationPhase.verified);
    expect(requests, isEmpty);
  });
  test(
    'wallet scope changed during event preflight prevents subsequent address disclosure',
    () async {
      points.gates['event:11'] = Completer();
      final pending = register();
      current = false;
      points.gates.remove('event:11')!.complete();
      await expectLater(pending, throwsA(isA<EventRegistrationFailure>()));
      expect(points.calls, ['event:11']);
      expect(signer.calls, isEmpty);
      expect(requests, isEmpty);
    },
  );
  test('scope change at final sending boundary still makes no network request', () async {
    await expectLater(
      register(
        step: (phase) {
          if (phase == EventRegistrationPhase.sending) current = false;
        },
      ),
      throwsA(isA<EventRegistrationFailure>()),
    );
    expect(requests, isEmpty);
  });
  for (final status in [302, 400, 403, 409, 429, 500]) {
    test('HTTP$status is unknown without raw errors, redirect or auto retry', () async {
      response = (_) async => http.Response(
        'sensitive server body',
        status,
        headers: {'location': 'https://untrusted.invalid'},
      );
      await expectLater(
        register(),
        throwsA(
          isA<EventRegistrationFailure>()
              .having((e) => e.key, 'key', 'eventRegistrationUnknown')
              .having((e) => e.mayHaveSent, 'unknown', true),
        ),
      );
      expect(requests.length, 1);
    });
  }
  test('timeout is unknown, late completion never resends', () async {
    final gate = Completer<http.Response>();
    response = (_) => gate.future;
    await expectLater(
      register(),
      throwsA(isA<EventRegistrationFailure>().having((e) => e.mayHaveSent, 'unknown', true)),
    );
    gate.complete(http.Response('', 200));
    expect(requests.length, 1);
  });
  test(
    'successful acknowledgement without verified personal read is not registration success',
    () async {
      response = (_) async => http.Response('accepted', 200);
      expect(await register(), EventRegistrationPhase.acknowledged);
      expect(requests.length, 1);
    },
  );
}
