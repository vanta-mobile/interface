import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:vanta/features/portfolio/data/aster_user_stream.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';

import '../../support/notifications.dart';

void main() {
  late HttpServer server;
  late List<WebSocket> sockets;
  late List<Object?> sent;
  late List<Uri> uris;
  const key = 'spotLocalTestKey00000000000001';
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    sockets = [];
    sent = [];
    uris = [];
  });
  tearDown(() async {
    for (final s in sockets) {
      await s.close();
    }
    await server.close(force: true);
  });
  void respond(List<Object> events) {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen(sent.add);
      for (final event in events) {
        socket.add(jsonEncode(event));
      }
    });
  }

  AsterUserStream stream() => AsterUserStream.spot(key, (uri) {
    uris.add(uri);
    return WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/private'));
  });
  test(
    'spot URL is raw /ws/key; no subscription; typed orders never enter futures reconciliation',
    () async {
      respond([
        spotNotificationPayload(),
        spotNotificationPayload(tradeId: 43, time: 200),
        {'e': 'outboundAccountPosition', 'E': 201, 'T': 200, 'B': <Object?>[]},
        {'e': 'unknown', 'E': 202},
      ]);
      final events = await stream().events.take(5).toList().timeout(const Duration(seconds: 3));
      expect(uris.single.toString(), 'wss://sstream.asterdex.com/ws/$key');
      expect(sent, isEmpty);
      expect(events.first.connected, true);
      expect(events[1].notification, isA<SpotOrderNotification>());
      expect(events[1].order, null);
      expect(events[1].spotOrder!.order.orderId, '1917641');
      expect(events[1].spotOrder!.order.quoteFilled.toString(), '8000.001');
      expect(events[1].spotOrder!.order.time, null);
      expect(events[1].account, null);
      expect(events[2].time!.millisecondsSinceEpoch, 200);
      expect(events[3].kind, AccountChangeKind.account);
      expect(events[3].notification, null);
      expect(events[4].kind, AccountChangeKind.unknown);
    },
  );
  test('expiry is terminal and later orders do not leak', () async {
    respond([
      {'e': 'listenKeyExpired', 'E': 200},
      spotNotificationPayload(),
    ]);
    final events = await stream().events.toList().timeout(const Duration(seconds: 3));
    expect(events.length, 2);
    expect(events.last.expired, true);
    expect(uris.length, 1);
  });
  for (final broken in ['quantity', 'time', 'shape']) {
    test('malformed $broken terminates with safe failure and no secret', () async {
      final raw = spotNotificationPayload();
      if (broken == 'quantity') {
        raw['q'] = 0.4;
      }
      if (broken == 'time') {
        raw['E'] = -1;
      }
      respond([broken == 'shape' ? <Object>[] : raw]);
      final errors = <Object>[], done = Completer<void>();
      stream().events.listen((_) {}, onError: errors.add, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 3));
      expect(
        errors.single,
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid'),
      );
      expect(errors.single.toString(), isNot(contains(key)));
    });
  }
}
