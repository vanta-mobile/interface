import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/points/data/points_repository.dart';
import 'package:vanta/features/points/domain/points.dart';

import '../../support/points.dart';
import '../../support/points_payloads.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4);
  PublicPointsRepository repository(
    Future<http.Response> Function(http.Request) handle, {
    Duration timeout = const Duration(seconds: 12),
  }) {
    final service = PointsService(client: MockClient(handle), timeout: timeout);
    addTearDown(service.close);
    return PublicPointsRepository(service, now: () => now);
  }

  test(
    'five read paths are fixed anonymous GETs; address is disclosed only by explicit reads',
    () async {
      final requests = <http.Request>[];
      final repo = repository((r) async {
        requests.add(r);
        expect(r.method, 'GET');
        expect(r.body, '');
        expect(r.headers, {'Accept': 'application/json'});
        expect(r.followRedirects, false);
        expect(r.url.host, 'api.vanta.exchange');
        expect(r.url.scheme, 'https');
        expect(r.url.query, '');
        final path = r.url.path;
        final Object payload = switch (path) {
          '/api/campaign/current' => {'campaign': cycle()},
          '/api/campaigns' => {
            'items': [cycle()],
          },
          '/api/leaderboard/total' => {
            'items': [ranking()],
          },
          '/api/leaderboard/campaign/17' => {
            'items': [ranking(campaign: 17)],
          },
          '/api/points/$pointsTestAddress' => {'totalPoint': '0', 'currentPoint': '0'},
          '/api/points/$pointsTestAddress/campaigns' => {'items': <Object>[]},
          _ => throw StateError('unexpected request'),
        };
        return http.Response(jsonEncode(payload), 200);
      });
      expect((await repo.currentCampaign()).value!.number, 17);
      expect((await repo.campaigns()).value.length, 1);
      expect((await repo.leaderboard(null)).value.rows.first.rank, 1);
      expect((await repo.leaderboard(17)).value.campaign, 17);
      expect(requests.length, 4);
      expect(requests.every((r) => !r.url.path.contains(pointsTestAddress)), true);
      expect((await repo.wallet(pointsTestAddress)).value.total.toString(), '0');
      expect((await repo.walletHistory(pointsTestAddress)).value.rows, isEmpty);
      expect(requests.map((r) => r.url.path), [
        '/api/campaign/current',
        '/api/campaigns',
        '/api/leaderboard/total',
        '/api/leaderboard/campaign/17',
        '/api/points/$pointsTestAddress',
        '/api/points/$pointsTestAddress/campaigns',
      ]);
    },
  );
  test('raw JSON numerical points retain exact precision at the transport boundary', () async {
    final repo = repository(
      (_) async => http.Response(
        '{"totalPoint":12345678901234567890.000000000000000001,"currentPoint":0}',
        200,
      ),
    );
    final snapshot = await repo.wallet(pointsTestAddress);
    expect(snapshot.receivedAt, now);
    expect(snapshot.value.total.toString(), '12345678901234567890.000000000000000001');
  });
  for (final pair in [
    (302, 'pointsUnavailable'),
    (401, 'pointsUnavailable'),
    (403, 'pointsUnavailable'),
    (418, 'pointsRateLimited'),
    (429, 'pointsRateLimited'),
    (500, 'pointsUnavailable'),
  ]) {
    test('HTTP ${pair.$1} maps a safe reason without redirect or retry', () async {
      var calls = 0;
      final repo = repository((_) async {
        calls++;
        return http.Response(
          'sensitive server body',
          pair.$1,
          headers: {'location': 'https://untrusted.invalid'},
        );
      });
      await expectLater(
        repo.campaigns(),
        throwsA(isA<PointsFailure>().having((e) => e.key, 'key', pair.$2)),
      );
      expect(calls, 1);
    });
  }
  for (final payload in [
    '<html>SPA</html>',
    '{}',
    'null',
    '{"items":null}',
    '{"items":[],"items":[]}',
    '{"items":[{"campaignNumber":1}]}',
  ]) {
    test('invalid/HTML response is never a successful empty result: ${payload.hashCode}', () async {
      final repo = repository((_) async => http.Response(payload, 200));
      await expectLater(
        repo.campaigns(),
        throwsA(isA<PointsFailure>().having((e) => e.key, 'key', 'pointsDataInvalid')),
      );
    });
  }
  test('invalid campaign or wallet path makes no network request', () async {
    var calls = 0;
    final repo = repository((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    for (final id in [0, -1]) {
      await expectLater(repo.leaderboard(id), throwsA(isA<PointsFailure>()));
    }
    for (final address in ['', '$pointsTestAddress/../admin', 'not-a-wallet']) {
      await expectLater(repo.wallet(address), throwsA(isA<PointsFailure>()));
      await expectLater(repo.walletHistory(address), throwsA(isA<PointsFailure>()));
    }
    expect(calls, 0);
  });
  test('cycle response cannot substitute another requested cycle', () async {
    final repo = repository(
      (_) async => http.Response(
        jsonEncode({
          'items': [ranking(campaign: 2)],
        }),
        200,
      ),
    );
    await expectLater(
      repo.leaderboard(1),
      throwsA(isA<PointsFailure>().having((e) => e.key, 'key', 'pointsDataInvalid')),
    );
  });
  test('timeout is a safe network reason without retry', () async {
    final gate = Completer<http.Response>();
    var calls = 0;
    final repo = repository((_) {
      calls++;
      return gate.future;
    }, timeout: const Duration(milliseconds: 1));
    await expectLater(
      repo.currentCampaign(),
      throwsA(isA<PointsFailure>().having((e) => e.key, 'key', 'pointsNetwork')),
    );
    gate.complete(http.Response('{"campaign":null}', 200));
    expect(calls, 1);
  });
}
