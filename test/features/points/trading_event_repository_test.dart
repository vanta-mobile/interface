import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/points/data/points_repository.dart';
import 'package:vanta/features/points/domain/points.dart';

import '../../support/points.dart';
import '../../support/trading_events.dart';

void main() {
  test('fixed anonymous RETAIL reads; participant address only in explicit request', () async {
    final calls = <http.Request>[];
    final service = PointsService(
      client: MockClient((r) async {
        calls.add(r);
        expect(r.method, 'GET');
        expect(r.body, '');
        expect(r.followRedirects, false);
        expect(r.headers, {'Accept': 'application/json'});
        final Object payload = switch (r.url.path) {
          '/api/trading-events' => {
            'items': [eventPayload()],
          },
          '/api/trading-events/11' => {'event': eventPayload()},
          '/api/trading-events/11/rankings/retail-volume' => {
            'eventId': 11,
            'eventType': 'RETAIL',
            'rows': [
              {'rank': 1, 'address': pointsTestAddress, 'volume': '10.000000000000000001'},
            ],
          },
          '/api/trading-events/11/participants/$pointsTestAddress' => {'registered': false},
          _ => throw StateError('unexpected path'),
        };
        return http.Response(jsonEncode(payload), 200);
      }),
    );
    addTearDown(service.close);
    final repo = PublicPointsRepository(service);
    expect((await repo.events()).value.length, 1);
    expect((await repo.event(11)).value.id, 11);
    expect(
      (await repo.eventLeaderboard(11)).value.rows.single.volume.toString(),
      '10.000000000000000001',
    );
    expect(calls.length, 3);
    expect(calls.any((r) => r.url.path.contains(pointsTestAddress)), false);
    expect((await repo.eventParticipant(11, pointsTestAddress)).value.registered, false);
    expect(calls.map((r) => r.url.toString()), [
      'https://api.vanta.exchange/api/trading-events?type=RETAIL',
      'https://api.vanta.exchange/api/trading-events/11',
      'https://api.vanta.exchange/api/trading-events/11/rankings/retail-volume?limit=30',
      'https://api.vanta.exchange/api/trading-events/11/participants/$pointsTestAddress',
    ]);
  });
  test('invalid event IDs and participant paths never access network', () async {
    var calls = 0;
    final service = PointsService(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.close);
    final repo = PublicPointsRepository(service);
    await expectLater(repo.event(0), throwsA(isA<PointsFailure>()));
    await expectLater(repo.eventLeaderboard(-1), throwsA(isA<PointsFailure>()));
    await expectLater(
      repo.eventParticipant(11, '$pointsTestAddress/../admin'),
      throwsA(isA<PointsFailure>()),
    );
    expect(calls, 0);
  });
  test('raw numeric API threshold and volume preserve exact fractional digits', () async {
    final source = jsonEncode({'event': eventPayload()})
        .replaceFirst('"243134683.03089294"', '243134683.03089294');
    final service = PointsService(client: MockClient((_) async => http.Response(source, 200)));
    addTearDown(service.close);
    expect(
      (await PublicPointsRepository(service).event(11)).value.volume.toString(),
      '243134683.03089294',
    );
  });
}
