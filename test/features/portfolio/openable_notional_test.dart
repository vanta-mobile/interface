import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/portfolio/data/aster_account_service.dart';
import 'package:vanta/features/portfolio/data/openable_notional_mapper.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

import '../../support/live_order.dart';

void main() {
  for (final raw in ['-1', '0', '200000', '0.000000000000000001']) {
    test('documented remaining capacity $raw retains scope and sentinel', () {
      final result = mapSymbolOpenableNotional(
        {'remainingOpenableNotionalValue': raw},
        symbol: 'BTCUSDT',
        leverage: 20,
        receivedAt: liveOrderClock,
      );
      expect(result.symbol, 'BTCUSDT');
      expect(result.leverage, 20);
      expect(result.receivedAt, liveOrderClock);
      expect(result.unlimited, raw == '-1');
      expect(result.remaining, raw == '-1' ? null : Decimal.parse(raw));
    });
  }
  for (final raw in <Object?>[
    null,
    -1,
    0,
    0.1,
    true,
    '-1.0',
    '-2',
    ' -1',
    'NaN',
    '1e6',
    '.1',
    '1.',
    '+1',
    '9' * 161,
  ]) {
    test('invalid or absent remaining capacity is unknown, never unlimited: $raw', () {
      expect(
        () => mapSymbolOpenableNotional(
          {'remainingOpenableNotionalValue': raw},
          symbol: 'BTCUSDT',
          leverage: 20,
          receivedAt: liveOrderClock,
        ),
        throwsFormatException,
      );
    });
  }
  for (final payload in <Object?>[
    null,
    [],
    {},
    '0',
    {'code': -4028},
  ]) {
    test('invalid payload cannot become zero capacity ${payload.runtimeType} $payload', () {
      expect(
        () => mapSymbolOpenableNotional(
          payload,
          symbol: 'BTCUSDT',
          leverage: 20,
          receivedAt: liveOrderClock,
        ),
        throwsFormatException,
      );
    });
  }
  test('public cap GET contains only symbol and leverage, never a wallet or signer', () async {
    var calls = 0;
    final service = AsterAccountService(
      client: MockClient((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(request.url.origin, 'https://fapi.asterdex.com');
        expect(request.url.path, '/fapi/v3/remainingOpenableNotionalValue');
        expect(request.url.queryParameters, {'symbol': 'BTCUSDT', 'leverage': '20'});
        expect(request.followRedirects, false);
        expect(request.body, isEmpty);
        expect(
          request.headers.keys.map((s) => s.toLowerCase()).toSet().difference({'accept'}),
          isEmpty,
        );
        return http.Response(jsonEncode({'remainingOpenableNotionalValue': '200000'}), 200);
      }),
    );
    addTearDown(service.close);
    final payload = await service.remainingOpenableNotionalValue(symbol: 'BTCUSDT', leverage: 20);
    expect(
      mapSymbolOpenableNotional(
        payload,
        symbol: 'BTCUSDT',
        leverage: 20,
        receivedAt: liveOrderClock,
      ).remaining,
      Decimal.fromInt(200000),
    );
    expect(calls, 1);
  });
  test('bad local scope is rejected before any HTTP request', () async {
    var calls = 0;
    final service = AsterAccountService(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.close);
    for (final (symbol, leverage) in [
      ('', 20),
      ('BTCUSDT&user=other', 20),
      ('BTCUSDT', 0),
      ('BTCUSDT', -1),
    ]) {
      expect(
        () => service.remainingOpenableNotionalValue(symbol: symbol, leverage: leverage),
        throwsFormatException,
      );
      expect(
        () => mapSymbolOpenableNotional(
          {'remainingOpenableNotionalValue': '0'},
          symbol: symbol,
          leverage: leverage,
          receivedAt: liveOrderClock,
        ),
        throwsFormatException,
      );
    }
    expect(calls, 0);
  });
  for (final (status, payload, key) in [
    (200, '{"code":-4028}', 'accountReadFailed'),
    (429, '{}', 'accountRateLimited'),
    (302, '{}', 'accountReadFailed'),
    (200, 'bad json', 'accountDataInvalid'),
  ]) {
    test('failed public cap $status $key stays failed with no retry', () async {
      var calls = 0;
      final service = AsterAccountService(
        client: MockClient((_) async {
          calls++;
          return http.Response(payload, status);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.remainingOpenableNotionalValue(symbol: 'BTCUSDT', leverage: 20),
        throwsA(isA<AccountReadFailure>().having((e) => e.key, 'safe failure', key)),
      );
      expect(calls, 1);
    });
  }
}
