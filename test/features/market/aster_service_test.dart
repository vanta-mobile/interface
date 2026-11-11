import 'package:vanta/features/market/data/market_catalog_repository.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/core/market_failure.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/features/market/data/aster_service.dart';

Map<String, Object?> instrument(
  String base, {
  String status = 'TRADING',
  String contract = 'PERPETUAL',
  String quote = 'USDT',
}) => {
  'symbol': '$base$quote',
  'baseAsset': base,
  'quoteAsset': quote,
  'status': status,
  'contractType': contract,
  'filters': [
    {'filterType': 'PRICE_FILTER', 'tickSize': '0.00000001'},
    {'filterType': 'LOT_SIZE', 'stepSize': '0.05'},
  ],
};

Map<String, Object?> ticker(String symbol, int volume) => {
  'symbol': symbol,
  'lastPrice': '100.25',
  'openPrice': '100',
  'priceChangePercent': '0.25',
  'highPrice': '110',
  'lowPrice': '90',
  'quoteVolume': '$volume',
};

http.Response jsonResponse(Object? body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

void main() {
  group('Aster V3 REST', () {
    test('joins every eligible public perpetual without a 100-contract truncation', () async {
      final symbols = [
        for (var i = 0; i < 105; i++) instrument('COIN$i'),
        instrument('SOL'),
        {
          ...instrument('BTC'),
          'name': 'Bitcoin',
          'tags': ['比特币'],
          'underlyingSubType': ['Top', 'AI'],
        },
        instrument('ETH'),
        instrument('HALTED', status: 'PENDING_TRADING'),
        instrument('DATED', contract: 'CURRENT_QUARTER'),
        instrument('OTHER', quote: 'USD1'),
        instrument('MISSING'),
      ];
      final requests = <String>[];
      final now = DateTime.now().millisecondsSinceEpoch + 120000;
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.host, 'fapi.asterdex.com');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers.containsKey('x-mbx-apikey'), false);
        requests.add(request.url.path);
        return switch (request.url.path) {
          '/fapi/v3/exchangeInfo' => jsonResponse({'symbols': symbols}),
          '/fapi/v3/time' => jsonResponse({'serverTime': now}),
          '/fapi/v3/ticker/24hr' => jsonResponse([
            for (final data in symbols.where((s) => s['symbol'] != 'MISSINGUSDT'))
              ticker(data['symbol']! as String, symbols.indexOf(data) + 1),
          ]),
          // Deliberately shuffled to catch accidental index-based joins.
          '/fapi/v3/premiumIndex' => jsonResponse([
            {'symbol': 'ETHUSDT', 'markPrice': '200', 'lastFundingRate': '0.0002'},
            {'symbol': 'BTCUSDT', 'markPrice': '101', 'lastFundingRate': '0.0001'},
          ]),
          _ => throw StateError('Unexpected endpoint ${request.url}'),
        };
      });
      addTearDown(client.close);
      final service = AsterService(client);
      final result = await MarketCatalogRepository(service).read();
      expect(
        requests,
        unorderedEquals([
          '/fapi/v3/exchangeInfo',
          '/fapi/v3/time',
          '/fapi/v3/ticker/24hr',
          '/fapi/v3/premiumIndex',
        ]),
      );
      expect(result, hasLength(108));
      expect(result.take(4).map((i) => i.symbol), ['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'COIN104USDT']);
      expect(result.map((i) => i.symbol).toSet(), hasLength(108));
      expect(result.first.ticker['markPrice'], '101');
      expect(result[1].ticker['lastFundingRate'], '0.0002');
      expect(result[3].ticker['quoteVolume'], '105');
      expect(result.first.base, 'BTC');
      expect(result.first.descriptor.name, 'Bitcoin');
      expect(result.first.descriptor.aliases, ['比特币']);
      expect(result.first.precision.priceTick, '0.00000001');
      expect(result.first.precision.quantityStep, '0.05');
      expect((service.serverNow - now).abs(), lessThan(2000));
      expect(() => result.clear(), throwsUnsupportedError);
    });

    test('initial volume order uses exact decimals, stable ties and missing values last', () async {
      final values = <String, String?>{
        'COINB': '100000000000000000.000000000000000002',
        'COINC': '100000000000000000.000000000000000001',
        'COINA': '100000000000000000.000000000000000002',
        'UNKNOWN': null,
      };
      final client = MockClient(
        (request) async => switch (request.url.path) {
          '/fapi/v3/exchangeInfo' => jsonResponse({
            'symbols': [for (final base in values.keys) instrument(base), instrument('COINA')],
          }),
          '/fapi/v3/ticker/24hr' => jsonResponse([
            for (final entry in values.entries)
              {...ticker('${entry.key}USDT', 1), 'quoteVolume': entry.value},
          ]),
          '/fapi/v3/time' => jsonResponse({'serverTime': DateTime.now().millisecondsSinceEpoch}),
          '/fapi/v3/premiumIndex' => jsonResponse([]),
          _ => throw StateError('Unexpected transport'),
        },
      );
      addTearDown(client.close);
      final result = await MarketCatalogRepository(AsterService(client)).read();
      expect(result.map((row) => row.symbol), [
        'COINAUSDT',
        'COINBUSDT',
        'COINCUSDT',
        'UNKNOWNUSDT',
      ]);
    });

    test('Unicode symbols and aliases survive UTF-8 responses without charset headers', () async {
      final client = MockClient(
        (request) async => switch (request.url.path) {
          '/fapi/v3/exchangeInfo' => jsonResponse({
            'symbols': [
              {
                ...instrument('币安人生'),
                'tags': ['BIANRENSHENG', '币安'],
              },
            ],
          }),
          '/fapi/v3/ticker/24hr' => jsonResponse([ticker('币安人生USDT', 1)]),
          '/fapi/v3/time' => jsonResponse({'serverTime': DateTime.now().millisecondsSinceEpoch}),
          '/fapi/v3/premiumIndex' => jsonResponse([]),
          _ => throw StateError('Unexpected request'),
        },
      );
      addTearDown(client.close);
      final result = await MarketCatalogRepository(AsterService(client)).read();
      expect(result.single.symbol, '币安人生USDT');
      expect(result.single.descriptor.aliases, ['BIANRENSHENG', '币安']);
    });

    test(
      'refresh keeps quote volume and fractional funding fields associated with their symbol',
      () async {
        final client = MockClient((request) async {
          expect(request.url.host, 'fapi.asterdex.com');
          return switch (request.url.path) {
            '/fapi/v3/ticker/24hr' => jsonResponse([
              ticker('BTCUSDT', 400),
              ticker('ETHUSDT', 200),
            ]),
            '/fapi/v3/premiumIndex' => jsonResponse([
              {'symbol': 'ETHUSDT', 'lastFundingRate': '0.000345', 'nextFundingTime': 180000},
              {'symbol': 'BTCUSDT', 'lastFundingRate': '-0.0001', 'nextFundingTime': 240000},
            ]),
            _ => throw StateError('Unexpected endpoint ${request.url}'),
          };
        });
        addTearDown(client.close);
        final result = await AsterService(client).refreshTickers();
        expect(result['BTCUSDT']!['quoteVolume'], '400');
        expect(result['ETHUSDT']!['priceChangePercent'], '0.25');
        expect(result['ETHUSDT']!['lastFundingRate'], '0.000345');
        expect(result['BTCUSDT']!['nextFundingTime'], 240000);
      },
    );

    test('refreshes only the current chart symbol with single-symbol payloads', () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        expect(request.url.queryParameters, {'symbol': 'BTCUSDT'});
        paths.add(request.url.path);
        if (request.url.path == '/fapi/v3/ticker/24hr') {
          return jsonResponse({'symbol': 'BTCUSDT', 'quoteVolume': '400'});
        }
        return jsonResponse({'symbol': 'BTCUSDT', 'lastFundingRate': '0.0001'});
      });
      addTearDown(client.close);
      final result = await AsterService(client).refreshTickers(symbol: 'BTCUSDT');
      expect(paths, ['/fapi/v3/ticker/24hr', '/fapi/v3/premiumIndex']);
      expect(result.keys, ['BTCUSDT']);
      expect(result['BTCUSDT']!['quoteVolume'], '400');
      expect(result['BTCUSDT']!['lastFundingRate'], '0.0001');
    });

    test('maps historical candles and sends inclusive pagination parameters', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final client = MockClient((request) async {
        expect(request.url.host, 'fapi.asterdex.com');
        expect(request.url.path, '/fapi/v3/klines');
        expect(request.url.queryParameters, {
          'symbol': 'ASTERUSDT',
          'interval': '5m',
          'limit': '1000',
          'startTime': '60000',
          'endTime': '659999',
        });
        return jsonResponse([
          [60000, '100', '120', '90', '110', '2.5', 359999, '275', 3],
          [360000, '110', '125', '100', '115', '3.5', now + 300000, '400', 4],
        ]);
      });
      addTearDown(client.close);
      final result = await AsterService(client)
          .history('ASTERUSDT', '5m', start: 60000, end: 659999, limit: 1000);
      expect(result.map((c) => c.time), [60000, 360000]);
      expect(result.first.open, 100);
      expect(result.first.high, 120);
      expect(result.first.low, 90);
      expect(result.first.close, 110);
      expect(result.first.volume, 2.5);
      expect(result.first.closed, true);
      expect(result.last.closed, false);
    });

    test('rejects out-of-range history limits before transport', () async {
      final client = MockClient((_) => throw StateError('Unexpected HTTP'));
      addTearDown(client.close);
      final service = AsterService(client);
      for (final limit in [0, 1501]) {
        await expectLater(service.history('BTCUSDT', '1m', limit: limit), throwsArgumentError);
      }
    });

    test('rejects non-finite and inconsistent OHLC data', () async {
      for (final high in ['NaN', 'Infinity', '95']) {
        final client = MockClient(
          (_) async => jsonResponse([
            [60000, '100', high, '90', '110', '2', 119999],
          ]),
        );
        addTearDown(client.close);
        await expectLater(
          AsterService(client).history('BTCUSDT', '1m'),
          throwsA(isA<MarketFailure>()),
        );
      }
    });

    test('HTML errors and invalid JSON produce safe errors without response bodies', () async {
      for (final status in [200, 502]) {
        final client = MockClient(
          (_) async => http.Response('<html>private upstream details</html>', status),
        );
        addTearDown(client.close);
        await expectLater(
          AsterService(client).request('/fapi/v3/time'),
          throwsA(
            isA<MarketFailure>()
                .having(
                  (e) => e.message,
                  'safe reason',
                  status == 200 ? 'Invalid Aster response' : 'Aster HTTP 502',
                )
                .having(
                  (e) => e.details?.cause,
                  'cause',
                  status == 200 ? ApiErrorCause.invalidResponse : isNull,
                )
                .having(
                  (e) => e.details?.endpoint,
                  'fixed endpoint without response body',
                  status == 200 ? '/fapi/v3/time' : isNull,
                ),
          ),
        );
      }
    });
  });
}
