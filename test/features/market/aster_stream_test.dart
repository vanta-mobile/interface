import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vanta/features/market/data/aster_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('Aster market streams', () {
    late HttpServer server;
    late http.Client client;
    late List<Uri> connections;
    late List<Map<String, dynamic>> subscriptions;
    late List<WebSocket> sockets;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      client = MockClient((_) => throw StateError('Unexpected HTTP'));
      connections = [];
      subscriptions = [];
      sockets = [];
    });
    tearDown(() async {
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
      client.close();
    });

    AsterService service() => AsterService(
      client,
      connect: (uri) {
        connections.add(uri);
        return WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/stream'));
      },
    );

    void respond(List<Object?> events) {
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((raw) {
          if (socket.readyState != WebSocket.open) return;
          subscriptions.add(jsonDecode(raw as String) as Map<String, dynamic>);
          socket.add(jsonEncode({'result': null, 'id': 1}));
          for (final event in events) {
            socket.add(jsonEncode(event));
          }
        });
      });
    }

    test(
      'subscribes on Aster combined endpoint, skips ack and accepts combined and raw events',
      () async {
        final kline = <String, Object?>{
          'e': 'kline',
          'E': 120001,
          'k': {
            't': 60000,
            's': 'BTCUSDT',
            'i': '1m',
            'o': '100',
            'h': '120',
            'l': '90',
            'c': '110',
            'v': '2.5',
            'x': true,
          },
        };
        respond([
          {'stream': 'btcusdt@kline_1m', 'data': kline},
          {'e': 'aggTrade', 's': 'BTCUSDT', 'p': '110', 'q': '2.5', 'm': false, 'T': 120001},
        ]);
        final events = await service()
            .stream(['btcusdt@kline_1m', 'btcusdt@aggTrade'])
            .take(3)
            .toList();
        expect(connections.single.toString(), 'wss://fstream.asterdex.com/stream');
        expect(subscriptions.single, {
          'method': 'SUBSCRIBE',
          'params': ['btcusdt@kline_1m', 'btcusdt@aggTrade'],
          'id': 1,
        });
        expect(events.first['connected'], true);
        expect(events.skip(1).map((e) => e['e']), ['kline', 'aggTrade']);
        final candle = AsterService.liveCandle(events[1]);
        expect(candle.time, 60000);
        expect(candle.close, 110);
        expect(candle.volume, 2.5);
        expect(candle.closed, true);
        expect(candle.eventTime, 120001);
      },
    );

    test('book uses depth20 snapshots and trades with independent channel tags', () async {
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((raw) {
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          subscriptions.add(message);
          final stream = (message['params'] as List<dynamic>).single as String;
          final depth = stream.contains('@depth20');
          socket.add(
            jsonEncode({
              'stream': stream,
              'data': {
                'e': depth ? 'depthUpdate' : 'aggTrade',
                's': 'BTCUSDT',
                if (depth) ...{
                  'b': [
                    ['100', '2'],
                  ],
                  'a': [
                    ['101', '3'],
                  ],
                } else ...{
                  'p': '100',
                  'q': '1',
                  'T': 120000,
                  'm': false,
                },
              },
            }),
          );
        });
      });
      final events = await service()
          .bookStream('btcusdt')
          .where((e) => e['e'] != null)
          .take(2)
          .toList()
          .timeout(const Duration(seconds: 2));
      expect(connections.every((u) => u.toString() == 'wss://fstream.asterdex.com/stream'), true);
      expect(
        subscriptions.expand((s) => s['params'] as List<dynamic>),
        unorderedEquals(['btcusdt@depth20@500ms', 'btcusdt@aggTrade']),
      );
      expect(events.singleWhere((e) => e['channel'] == 'depth')['e'], 'depthUpdate');
      expect(events.singleWhere((e) => e['channel'] == 'trades')['e'], 'aggTrade');
    });

    test(
      'all-market streams accept raw and combined delta arrays without dropping symbols',
      () async {
        respond([
          [
            {'e': '24hrTicker', 's': 'BTCUSDT', 'E': 100, 'c': '100'},
            {'e': '24hrTicker', 's': 'ETHUSDT', 'E': 100, 'c': '200'},
          ],
          {
            'stream': '!markPrice@arr@1s',
            'data': [
              {'e': 'markPriceUpdate', 's': 'ETHUSDT', 'E': 101, 'r': '0.0001'},
            ],
          },
          [
            {'e': '24hrTicker', 's': 'BTCUSDT', 'E': 102, 'c': '101'},
          ],
        ]);
        final events = await service()
            .stream(['!ticker@arr', '!markPrice@arr@1s'])
            .take(5)
            .toList()
            .timeout(const Duration(seconds: 2));
        expect(subscriptions.single['params'], ['!ticker@arr', '!markPrice@arr@1s']);
        expect(events.skip(1).map((event) => event['s']), [
          'BTCUSDT',
          'ETHUSDT',
          'ETHUSDT',
          'BTCUSDT',
        ]);
        expect(events[3]['r'], '0.0001');
        expect(events.last['c'], '101');
      },
    );

    test('cancelling a silent subscription closes without waiting for a market event', () async {
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((_) {});
      });
      final events = await service()
          .stream(['btcusdt@kline_1m'])
          .take(1)
          .toList()
          .timeout(const Duration(seconds: 2));
      expect(events.single['connected'], true);
      expect(connections, hasLength(1));
    });

    test('subscription rejection disconnects and resubscribes', () async {
      respond([
        {'code': 2, 'msg': 'Invalid subscription'},
      ]);
      final events = await service().stream(['btcusdt@kline_1m']).take(4).toList();
      expect(events.map((e) => e.keys.single), [
        'connected',
        'disconnected',
        'connected',
        'disconnected',
      ]);
      expect(subscriptions, hasLength(2));
    });

    test('rejects more than the documented 200 streams before opening a socket', () async {
      await expectLater(
        service().stream(List.filled(201, 'btcusdt@kline_1m')),
        emitsError(isArgumentError),
      );
      expect(connections, isEmpty);
    });
  });
}
