import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/portfolio/data/aster_user_stream.dart';
import 'package:vanta/features/portfolio/domain/account_change_stream.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../support/open_order_updates.dart';
import '../../support/notifications.dart';

import 'package:vanta/features/notifications/domain/account_notification.dart';

import '../../support/account_updates.dart';

void main() {
  late HttpServer server;
  late List<WebSocket> sockets;
  late List<Uri> uris;
  late List<Object?> sent;
  const key = 'exampleKeyOnlyForLocalTests00000001';
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    sockets = [];
    uris = [];
    sent = [];
  });
  tearDown(() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  });
  AsterUserStream stream() => AsterUserStream(key, (uri) {
    uris.add(uri);
    return WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/private'));
  });
  void respond(List<Object?> events, {bool disconnect = false}) {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen(sent.add);
      for (final event in events) {
        socket.add(jsonEncode(event));
      }
      if (disconnect) await socket.close();
    });
  }

  test(
    'uses private raw URL without a public subscription and preserves out-of-order signals',
    () async {
      respond([
        accountUpdatePayload(time: 200),
        orderUpdatePayload(eventTime: 100),
        {'e': 'ACCOUNT_CONFIG_UPDATE', 'E': 100},
        marginNotificationPayload(time: 201),
        {'e': 'FUTURE_NEW_EVENT', 'E': 202},
      ]);
      final events = await stream().events.take(6).toList().timeout(const Duration(seconds: 3));
      expect(uris.single.toString(), 'wss://fstream.asterdex.com/ws/$key');
      expect(sent, isEmpty);
      expect(events.first.connected, true);
      expect(events.skip(1).map((e) => e.kind), AccountChangeKind.values);
      expect(events[2].time!.millisecondsSinceEpoch, 100);
      expect(events[1].account?.positions.single.quantity.toString(), '-0.2');
      expect(events[1].notification, isA<BalanceNotification>());
      expect(
        (events[1].notification as BalanceNotification).balances.single.walletBalance.toString(),
        '102.000000000000000001',
      );
      expect(events[2].notification, isA<OrderNotification>());
      expect((events[4].notification as MarginNotification).positions.length, 2);
    },
  );
  test(
    'liquidation and ADL bypass ordinary open-order reconciliation and retain risk details',
    () async {
      final liquidation = notificationOrderPayload();
      (liquidation['o'] as Map<String, dynamic>)
        ..['c'] = 'autoclose-123'
        ..['X'] = 'NEW_INSURANCE'
        ..['x'] = 'CALCULATED';
      final adl = notificationOrderPayload();
      (adl['o'] as Map<String, dynamic>)
        ..['c'] = 'adl_autoclose'
        ..['X'] = 'NEW_ADL';
      respond([liquidation, adl, notificationOrderPayload(tradeId: 43)]);
      final events = await stream().events.take(4).toList().timeout(const Duration(seconds: 3));
      expect(events[1].order, null);
      expect(events[2].order, null);
      expect((events[1].notification as OrderNotification).risk, OrderRisk.liquidation);
      expect((events[2].notification as OrderNotification).risk, OrderRisk.adl);
      expect(events[3].order, isNotNull);
    },
  );
  test('expiry is terminal and never automatically reconnects', () async {
    respond([
      {'e': 'listenKeyExpired', 'E': 200},
    ]);
    final events = await stream().events.toList().timeout(const Duration(seconds: 3));
    expect(events.last.expired, true);
    expect(uris.length, 1);
  });
  test('silent subscription cancellation closes the native socket', () async {
    final closed = Completer<void>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen(
        sent.add,
        onDone: () {
          if (!closed.isCompleted) closed.complete();
        },
      );
    });
    final events = await stream().events.take(1).toList().timeout(const Duration(seconds: 3));
    expect(events.single.connected, true);
    await closed.future.timeout(const Duration(seconds: 3));
    expect(sent, isEmpty);
  });
  test('transport close emits a safe failure and completes without replay', () async {
    respond([], disconnect: true);
    final events = <AccountChangeEvent>[];
    final errors = <Object>[];
    final complete = Completer<void>();
    stream().events.listen(events.add, onError: errors.add, onDone: complete.complete);
    await complete.future.timeout(const Duration(seconds: 3));
    expect(events.single.connected, true);
    expect(errors.single, isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountNetwork'));
    expect(uris.length, 1);
  });
  for (final invalid in [
    {'e': 'ACCOUNT_UPDATE', 'E': '200'},
    {'e': 'ACCOUNT_UPDATE', 'E': -1},
    {'e': 'ACCOUNT_UPDATE', 'E': 253402300800000},
    accountUpdatePayload()
      ..['a'] = {
        'm': 'ORDER',
        'B': [
          {'a': 'USDT', 'wb': 1.01},
        ],
      },
    {'code': -1, 'msg': key},
    <Object?>[],
  ]) {
    test('malformed event terminates safely: $invalid', () async {
      respond([invalid]);
      final errors = <Object>[];
      final complete = Completer<void>();
      stream().events.listen((_) {}, onError: errors.add, onDone: complete.complete);
      await complete.future.timeout(const Duration(seconds: 3));
      expect(
        errors.single,
        isA<AccountReadFailure>().having((e) => e.key, 'key', 'accountDataInvalid'),
      );
      expect(errors.single.toString().contains(key), false);
    });
  }
}
