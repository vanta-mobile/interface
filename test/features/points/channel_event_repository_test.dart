import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/points/data/points_repository.dart';
import 'package:vanta/features/points/domain/points.dart';
import 'package:vanta/features/points/domain/trading_event.dart';

import '../../support/channel_events.dart';
import '../../support/points.dart';

void main() {
  test('channel list, detail, top10 and manual task paths are distinct and anonymous', () async {
    final requests = <http.Request>[];
    final service = PointsService(
      client: MockClient((r) async {
        requests.add(r);
        Object payload;
        if (r.url.path.endsWith('/tasks')) {
          payload = taskProgressPayload();
        } else if (r.url.path.endsWith('/channel-volume')) {
          payload = {'eventId': 17, 'eventType': 'CHANNEL', 'rows': <Object?>[]};
        } else if (r.url.path.endsWith('/17')) {
          payload = {'event': channelEventPayload()};
        } else {
          payload = {
            'items': [channelEventPayload()],
          };
        }
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(service.close);
    final r = PublicPointsRepository(service);
    expect(
      (await r.events(type: TradingEventType.channel)).value.single.type,
      TradingEventType.channel,
    );
    expect((await r.event(17)).value.engagementTasks, true);
    expect(
      (await r.eventLeaderboard(17, type: TradingEventType.channel)).value.type,
      TradingEventType.channel,
    );
    expect((await r.eventTaskProgress(17, pointsTestAddress)).value.address, pointsTestAddress);
    expect(requests.map((r) => r.url.toString()), [
      'https://api.vanta.exchange/api/trading-events?type=CHANNEL',
      'https://api.vanta.exchange/api/trading-events/17',
      'https://api.vanta.exchange/api/trading-events/17/rankings/channel-volume?limit=10',
      'https://api.vanta.exchange/api/trading-events/17/participants/$pointsTestAddress/tasks',
    ]);
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.headers.keys.map((k) => k.toLowerCase()), ['accept']);
      expect(request.followRedirects, false);
    }
  });
  test('invalid task scope never sends network', () async {
    var count = 0;
    final service = PointsService(
      client: MockClient((_) async {
        count++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.close);
    for (final id in [0, -1]) {
      await expectLater(
        () => service.eventTaskProgress(id, pointsTestAddress),
        throwsA(isA<PointsFailure>()),
      );
    }
    await expectLater(
      () => service.eventTaskProgress(17, 'invalid'),
      throwsA(isA<PointsFailure>()),
    );
    expect(count, 0);
  });
  test('malformed source mapping reports safe data failure', () async {
    final s = PointsService(
      client: MockClient(
        (_) async => http.Response(
          '{"dailyCheckIn":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(s.close);
    await expectLater(
      PublicPointsRepository(s).eventTaskProgress(17, pointsTestAddress),
      throwsA(isA<PointsFailure>().having((e) => e.key, 'key', 'pointsDataInvalid')),
    );
  });
  for (final mode in ['declared-size', 'stream-size', 'mime', 'redirect']) {
    test('task transport rejects $mode without decoding unbounded or nonJSON content', () async {
      final service = PointsService(
        client: MockClient.streaming((r, _) async {
          final chunks = mode == 'stream-size'
              ? List.generate(33, (_) => List.filled(65536, 32))
              : <List<int>>[
                  [123, 125],
                ];
          return http.StreamedResponse(
            Stream.fromIterable(chunks),
            mode == 'redirect' ? 302 : 200,
            contentLength: mode == 'declared-size' ? 2097153 : null,
            headers: {'content-type': mode == 'mime' ? 'text/html' : 'application/json'},
          );
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.eventTaskProgress(17, pointsTestAddress),
        throwsA(isA<PointsFailure>()),
      );
    });
  }
  test('task GET timeout aborts actual transport and disposal aborts pending requests', () async {
    for (final close in [false, true]) {
      final started = Completer<void>(), aborted = Completer<void>();
      final service = PointsService(
        timeout: close ? const Duration(seconds: 12) : const Duration(milliseconds: 2),
        client: MockClient.streaming((r, _) async {
          started.complete();
          await (r as http.Abortable).abortTrigger;
          aborted.complete();
          throw http.RequestAbortedException(r.url);
        }),
      );
      final future = service.eventTaskProgress(17, pointsTestAddress);
      await started.future;
      if (close) service.close();
      await expectLater(future, throwsA(isA<PointsFailure>()));
      await aborted.future;
      service.close();
    }
  });
}
