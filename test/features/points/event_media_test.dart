import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/points/data/event_media_service.dart';
import 'package:vanta/features/points/domain/points.dart';

void main() {
  final uri = Uri.parse(
    'https://nltkngcwiuydkpmqrili.supabase.co/storage/v1/object/public/trading-event-content/events/a.png',
  );
  test('approved public raster uses a fixed anonymous request without redirects', () async {
    final service = EventMediaService(
      client: MockClient((r) async {
        expect(r.url, uri);
        expect(r.method, 'GET');
        expect(r.followRedirects, false);
        expect(r.headers, isEmpty);
        expect(r.body, '');
        return http.Response.bytes([1, 2, 3], 200, headers: {'content-type': 'image/png'});
      }),
    );
    addTearDown(service.close);
    expect(await service.read(uri), [1, 2, 3]);
  });
  for (final pair in [
    (302, 'image/png'),
    (200, 'text/html'),
    (200, 'image/svg+xml'),
    (404, 'image/png'),
  ]) {
    test('invalid media ${pair.$1}/${pair.$2} fails safely', () async {
      final service = EventMediaService(
        client: MockClient(
          (_) async => http.Response('sensitive', pair.$1, headers: {'content-type': pair.$2}),
        ),
      );
      addTearDown(service.close);
      await expectLater(service.read(uri), throwsA(isA<PointsFailure>()));
    });
  }
  test('unapproved image origin never makes a network request', () async {
    var calls = 0;
    final service = EventMediaService(
      client: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    addTearDown(service.close);
    await expectLater(
      service.read(Uri.https('untrusted.invalid', '/a.png')),
      throwsA(isA<PointsFailure>()),
    );
    expect(calls, 0);
  });
  test('streaming bound prevents an oversized image even without Content-Length', () async {
    final service = EventMediaService(
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.value(List.filled(5242881, 0)),
          200,
          headers: {'content-type': 'image/png'},
        ),
      ),
    );
    addTearDown(service.close);
    await expectLater(service.read(uri), throwsA(isA<PointsFailure>()));
  });
}
