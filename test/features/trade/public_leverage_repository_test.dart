import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/market_failure.dart';
import 'package:vanta/features/market/data/public_leverage_repository.dart';

void main() {
  test('read-only public POST contains no identity or credentials', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.host, 'www.asterdex.com');
      expect(request.url.path, '/bapi/futures/v1/friendly/future/common/brackets');
      expect(request.body, '{}');
      expect(request.headers.keys.any((k) => k.toLowerCase() == 'authorization'), false);
      return http.Response(
        jsonEncode({
          'success': true,
          'code': '000000',
          'data': {
            'brackets': [
              {
                'symbol': 'BTCUSDT',
                'riskBrackets': [
                  {'minOpenPosLeverage': 1, 'maxOpenPosLeverage': 200},
                ],
              },
            ],
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    expect((await PublicLeverageRepository(client).read())['BTCUSDT']!.defaultLeverage(), 20);
  });
  test('do not retry rate limits or turn failures into default capability', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{"msg":"Please try later"}', 429);
    });
    addTearDown(client.close);
    await expectLater(PublicLeverageRepository(client).read(), throwsA(isA<MarketFailure>()));
    expect(calls, 1);
  });
}
