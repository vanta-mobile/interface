import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/auth/domain/auth_session.dart';
import 'package:vanta/features/auth/domain/wallet_message_signer.dart';
import 'package:vanta/features/points/data/event_engagement_mapper.dart';
import 'package:vanta/features/points/data/trading_event_mapper.dart';
import 'package:vanta/features/points/data/event_engagement_repository.dart';
import 'package:vanta/features/points/domain/event_engagement.dart';
import 'package:vanta/features/points/domain/event_registration.dart';
import 'package:vanta/features/points/domain/points.dart';
import 'package:vanta/features/points/domain/trading_event.dart';

import '../../support/channel_events.dart';
import '../../support/points.dart';

EventTaskProgress taskProgressFromRaw(Object? raw) =>
    mapEventTaskProgress(raw, eventId: 17, address: pointsTestAddress);
TradingEvent channelEventFromRaw(Object? raw) => mapTradingEvent({'event': raw}, eventId: 17);

class _Signer implements WalletMessageSigner {
  final calls = <String>[];
  Future<void> Function()? onSign;
  String signature = '0x${'1' * 130}';
  @override
  Future<String> signPersonalMessage({
    required String expectedAddress,
    required String message,
  }) async {
    expect(expectedAddress, pointsTestAddress);
    calls.add(message);
    await onSign?.call();
    return signature;
  }
}

void main() {
  late DateTime now;
  late TestPointsRepository points;
  late MemoryEventEngagementJournal journal;
  late _Signer signer;
  late VantaEventEngagementRepository repository;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) response;
  late bool current;
  EventEngagementApproval approval([
    EventEngagementAction action = EventEngagementAction.checkIn,
  ]) => EventEngagementApproval(
    event: channelEventFixture(),
    identity: const AuthIdentity(
      id: 'user',
      walletAddress: pointsTestAddress,
      walletKind: WalletKind.external,
      signingAvailable: true,
    ),
    action: action,
    day: eventUtcDay(now),
  );
  Future<EventRegistrationPhase> submit([
    EventEngagementAction action = EventEngagementAction.checkIn,
  ]) => repository.submit(approval(action), isCurrent: () => current, onStep: (_) {});
  Matcher failure(String key, {bool? sent}) => throwsA(
    isA<EventRegistrationFailure>()
        .having((e) => e.key, 'key', key)
        .having((e) => sent == null || e.mayHaveSent == sent, 'sent', true),
  );
  setUp(() {
    now = DateTime.utc(2026, 11, 4, 12);
    points = TestPointsRepository(now: () => now)
      ..eventValue = channelEventFixture()
      ..registered = true
      ..taskProgress = taskProgressFixture();
    journal = MemoryEventEngagementJournal();
    signer = _Signer();
    current = true;
    requests = [];
    response = (_) async {
      points.taskProgress = taskProgressFixture(checked: true, wallet: true);
      return http.Response('', 200);
    };
    repository = VantaEventEngagementRepository(
      points: points,
      journal: journal,
      signer: () => signer,
      now: () => now,
      timeout: const Duration(milliseconds: 30),
      client: MockClient((r) {
        expect(journal.entries.length, 1);
        requests.add(r);
        return response(r);
      }),
    );
  });
  tearDown(() => repository.close());
  for (final action in EventEngagementAction.values) {
    test(
      'exact ${action.path} message/body, fresh twice, journal before one POST and separate verification',
      () async {
        expect(await submit(action), EventRegistrationPhase.verified);
        expect(requests.length, 1);
        expect(
          signer.calls.single,
          [
            action == EventEngagementAction.checkIn
                ? 'Vanta Trading Event Check-In'
                : 'Vanta Trading Event Wallet Connect',
            'Event ID: 17',
            'Address: $pointsTestAddress',
            if (action == EventEngagementAction.checkIn) 'Date: 2026-11-04',
            'Timestamp: ${now.millisecondsSinceEpoch}',
          ].join('\n'),
        );
        final r = requests.single;
        expect(r.method, 'POST');
        expect(r.url.toString(), 'https://api.vanta.exchange/api/trading-events/17/${action.path}');
        expect(r.followRedirects, false);
        expect(
          r.headers.keys.map((k) => k.toLowerCase()),
          unorderedEquals(['accept', 'content-type']),
        );
        expect(jsonDecode(r.body), {
          'address': pointsTestAddress,
          'timestamp': now.millisecondsSinceEpoch,
          'signature': signer.signature,
        });
        expect(points.calls.where((c) => c == 'event:17').length, 2);
        expect(points.calls.where((c) => c.startsWith('participant:')).length, 2);
        expect(points.calls.where((c) => c.startsWith('tasks:')).length, 3);
        expect(journal.entries, isEmpty);
      },
    );
  }
  test('completed task preflight requires no signature or POST', () async {
    points.taskProgress = taskProgressFixture(checked: true);
    expect(await submit(), EventRegistrationPhase.verified);
    expect(signer.calls, isEmpty);
    expect(requests, isEmpty);
  });
  for (final reason in ['ended', 'below target', 'wrong date']) {
    test('ineligible $reason stops before signature', () async {
      if (reason == 'ended') now = DateTime.utc(2026, 11, 11);
      if (reason == 'below target') {
        final raw = taskProgressPayload();
        (raw['dailyCheckIn'] as Map)['todayVolume'] = '999';
        points.taskProgress = taskProgressFromRaw(raw);
      }
      if (reason == 'wrong date') points.taskProgress = taskProgressFixture(today: '2026-11-03');
      await expectLater(
        submit(),
        failure(reason == 'ended' ? 'eventRegistrationChanged' : 'eventEngagementIneligible'),
      );
      expect(signer.calls, isEmpty);
      expect(requests, isEmpty);
    });
  }
  test('registered alone does not prove wallet task registration completed', () async {
    points.taskProgress = const EventTaskProgress(
      eventId: 17,
      address: pointsTestAddress,
      newUser: EventNewUserProgress(walletCompleted: false),
    );
    await expectLater(
      submit(EventEngagementAction.walletConnect),
      failure('eventEngagementIneligible'),
    );
    expect(requests, isEmpty);
  });
  test('conditions can become complete while signing without duplicate POST', () async {
    signer.onSign = () async {
      points.taskProgress = taskProgressFixture(checked: true);
    };
    expect(await submit(), EventRegistrationPhase.verified);
    expect(signer.calls.length, 1);
    expect(requests, isEmpty);
  });
  test('rule mutation after wallet signature requires new review', () async {
    signer.onSign = () async {
      final raw = channelEventPayload();
      (raw['tasks'] as List).last['trackMetric'] = 'totalVolume';
      points.eventValue = channelEventFromRaw(raw);
    };
    await expectLater(submit(), failure('eventRegistrationChanged'));
    expect(requests, isEmpty);
    expect(journal.entries, isEmpty);
  });
  test('UTC midnight during signature invalidates approval before POST', () async {
    now = DateTime.utc(2026, 11, 4, 23, 59, 59);
    signer.onSign = () async {
      now = DateTime.utc(2026, 11, 5);
      points.taskProgress = taskProgressFixture(today: '2026-11-05');
    };
    await expectLater(submit(), failure('eventRegistrationChanged'));
    expect(requests, isEmpty);
  });
  test('local signature age and clock rollback both stop sending', () async {
    for (final offset in [const Duration(minutes: 3), const Duration(seconds: -1)]) {
      signer.onSign = () async {
        now = now.add(offset);
      };
      await expectLater(submit(), failure('eventRegistrationChanged'));
    }
    expect(requests, isEmpty);
  });
  test('refused wallet leaves no pending entry or request', () async {
    signer.onSign = () async {
      throw const AuthFailure('authWalletRejected');
    };
    await expectLater(submit(), throwsA(isA<AuthFailure>()));
    expect(journal.entries, isEmpty);
    expect(requests, isEmpty);
  });
  test('scope switch while signing prevents POST', () async {
    signer.onSign = () async {
      current = false;
    };
    await expectLater(submit(), failure('eventRegistrationChanged'));
    expect(requests, isEmpty);
  });
  test('invalid signature stops without persisting sensitive data', () async {
    signer.signature = 'secret';
    await expectLater(submit(), throwsA(isA<AuthFailure>()));
    expect(journal.entries, isEmpty);
  });
  for (final mode in ['read', 'write']) {
    test('journal $mode failure stops before POST', () async {
      journal.failRead = mode == 'read';
      journal.failAdd = mode == 'write';
      await expectLater(submit(), failure('eventEngagementStorage'));
      expect(requests, isEmpty);
    });
  }
  test('scope changes while persisting intent remove known unsent marker', () async {
    journal.addGate = Completer<void>();
    final future = submit();
    while (signer.calls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);
    current = false;
    journal.addGate!.complete();
    await expectLater(future, failure('eventRegistrationChanged'));
    expect(journal.entries, isEmpty);
    expect(requests, isEmpty);
  });
  for (final code in [302, 400, 500]) {
    test('HTTP $code is unknown and journal blocks retries', () async {
      response = (_) async => http.Response('', code);
      await expectLater(submit(), failure('eventEngagementUnknown', sent: true));
      expect(journal.entries.length, 1);
      await expectLater(submit(), failure('eventEngagementUnknown', sent: true));
      expect(requests.length, 1);
    });
  }
  test('transport timeout preserves intent and prevents second POST', () async {
    final gate = Completer<http.Response>();
    response = (_) => gate.future;
    await expectLater(submit(), failure('eventEngagementUnknown', sent: true));
    expect(journal.entries.length, 1);
    gate.complete(http.Response('', 200));
    await expectLater(submit(), failure('eventEngagementUnknown', sent: true));
    expect(requests.length, 1);
  });
  test('successful HTTP without task completion remains acknowledged', () async {
    response = (_) async => http.Response('', 200);
    expect(await submit(), EventRegistrationPhase.acknowledged);
    expect(journal.entries.length, 1);
    expect(await repository.reconcile(eventId: 17, address: pointsTestAddress), false);
    expect(journal.entries.length, 1);
  });
  test('reconciliation of original UTC date works after day advances', () async {
    response = (_) async => http.Response('', 200);
    await submit();
    now = DateTime.utc(2026, 11, 5);
    final raw = taskProgressPayload(today: '2026-11-05');
    (raw['dailyCheckIn'] as Map)['checkedInDates'] = ['2026-11-04'];
    points.taskProgress = taskProgressFromRaw(raw);
    expect(await repository.reconcile(eventId: 17, address: pointsTestAddress), true);
    expect(journal.entries, isEmpty);
    expect(requests.length, 1);
  });
  test('unverified/old/wrong-scoped response cannot clear a journal', () async {
    response = (_) async => http.Response('', 200);
    await submit();
    points.wrongAddress = true;
    points.taskProgress = null;
    await expectLater(
      repository.reconcile(eventId: 17, address: pointsTestAddress),
      throwsA(isA<PointsFailure>()),
    );
    expect(journal.entries.length, 1);
  });
  test('failed journal deletion retains acknowledged lock despite completion', () async {
    journal.failRemove = true;
    expect(await submit(), EventRegistrationPhase.acknowledged);
    expect(journal.entries.length, 1);
    journal.failRemove = false;
    expect(await repository.reconcile(eventId: 17, address: pointsTestAddress), true);
  });
  test('global submit mutex rejects parallel actions while wallet pending', () async {
    final gate = Completer<void>();
    signer.onSign = () => gate.future;
    final first = submit();
    while (signer.calls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await expectLater(submit(EventEngagementAction.walletConnect), failure('eventEngagementBusy'));
    gate.complete();
    await first;
    expect(requests.length, 1);
  });
  test('old wallet late response stays with original journal only', () async {
    final gate = Completer<http.Response>();
    response = (_) => gate.future;
    final first = submit();
    while (requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    current = false;
    gate.complete(http.Response('', 200));
    expect(await first, EventRegistrationPhase.acknowledged);
    expect(journal.entries.single.address, pointsTestAddress);
  });
  test('freshness beyond five minutes blocks even mocked repository', () async {
    points.receivedAt = now.subtract(const Duration(minutes: 6));
    await expectLater(submit(), failure('eventRegistrationChanged'));
    expect(signer.calls, isEmpty);
  });
  test('signature expiry during journal write is checked again before send', () async {
    journal.addGate = Completer<void>();
    final future = submit();
    while (signer.calls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(minutes: 3));
    journal.addGate!.complete();
    await expectLater(future, failure('eventRegistrationChanged'));
    expect(requests, isEmpty);
    expect(journal.entries, isEmpty);
  });
  test('transport timeout explicitly aborts request while preserving unknown journal', () async {
    final aborted = Completer<void>();
    repository.close();
    repository = VantaEventEngagementRepository(
      points: points,
      journal: journal,
      signer: () => signer,
      now: () => now,
      timeout: const Duration(milliseconds: 2),
      client: MockClient.streaming((r, _) async {
        await (r as http.Abortable).abortTrigger;
        aborted.complete();
        throw http.RequestAbortedException(r.url);
      }),
    );
    await expectLater(submit(), failure('eventEngagementUnknown', sent: true));
    await aborted.future;
    expect(journal.entries.length, 1);
  });
  test('service close aborts active request and leaves durable recovery entry', () async {
    final started = Completer<void>(), aborted = Completer<void>();
    repository.close();
    repository = VantaEventEngagementRepository(
      points: points,
      journal: journal,
      signer: () => signer,
      now: () => now,
      client: MockClient.streaming((r, _) async {
        started.complete();
        await (r as http.Abortable).abortTrigger;
        aborted.complete();
        throw http.RequestAbortedException(r.url);
      }),
    );
    final future = submit();
    await started.future;
    repository.close();
    await expectLater(future, failure('eventEngagementUnknown', sent: true));
    await aborted.future;
    expect(journal.entries.length, 1);
  });
}
