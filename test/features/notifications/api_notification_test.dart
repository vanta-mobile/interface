import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';
import 'package:vanta/features/notifications/data/api_notification_mapper.dart';
import 'package:vanta/features/notifications/data/api_notification_repository.dart';
import 'package:vanta/features/notifications/domain/api_notification.dart';
import 'package:vanta/features/notifications/domain/notification_status.dart';

import '../../support/api_notifications.dart';
import '../../support/vanta_api.dart';

void main() {
  test('sparse payloads preserve absent financial facts and ignore unknown extensions', () {
    final entry = mapApiNotification(
      inboxItem(
        payload: {
          'extension': {'anything': true},
        },
      ),
    );
    expect(entry.payload.numbers, isEmpty);
    expect(entry.payload.status, isNull);
    expect(entry.payload.market, isNull);
    expect(
      () => entry.payload.numbers[NotificationNumber.price] = Decimal.one,
      throwsUnsupportedError,
    );
  });
  test('numeric JSON payload lexemes and long order references retain exact precision', () {
    final decoded = decodeNotificationJson(
      jsonEncode(inboxItem(payload: {'order_id': '1234567890123456789'})).replaceFirst(
        '"payload":{',
        '"payload":{"price":0.1234567890123456789,"qty":0.000000000000000001,',
      ),
    ) as Map<String, Object?>;
    final entry = mapApiNotification(decoded);
    expect(entry.payload.numbers[NotificationNumber.price], Decimal.parse('0.1234567890123456789'));
    expect(
      entry.payload.numbers[NotificationNumber.quantity],
      Decimal.parse('0.000000000000000001'),
    );
    expect(entry.payload.orderId, '1234567890123456789');
  });
  test('malformed required and financial fields reject instead of inventing defaults', () {
    for (final entry in [
      {...inboxItem(), 'read': 'false'},
      {...inboxItem(), 'type': 'UNKNOWN'},
      {...inboxItem(), 'id': 1.5},
      {...inboxItem(), 'created_at': '2026-11-12'},
      inboxItem(payload: {'price': 'NaN'}),
      inboxItem(payload: {'qty': true}),
      inboxItem(broadcast: true, type: 'FILL'),
    ]) {
      expect(() => mapApiNotification(entry), throwsFormatException);
    }
    for (final page in [
      {'items': <Object?>[], 'unread': 0},
      {'items': <Object?>[], 'unread': -1, 'next_cursor': null},
      {'items': 'bad', 'unread': 0, 'next_cursor': null},
    ]) {
      expect(() => mapNotificationPage(page), throwsFormatException);
    }
  });
  test('read body and idempotency key are unchanged after session refresh', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    await f.start();
    var attempts = 0;
    f.backend.routes['POST /v1/notifications/read'] = (_) => ++attempts == 1
        ? json({'code': 'session_expired', 'message': 'Session expired'}, 401)
        : json({'marked': 1});
    f.backend.routes['POST /v1/auth/refresh'] = (_) => json(issued('new-access', 'new-refresh'));
    await ApiNotificationRepository(f.repository)
        .markRead(entry: mapApiNotification(inboxItem()), idempotencyKey: 'stable-key');
    final requests = f.backend.requests.where((r) => r.url.path.endsWith('/read')).toList();
    expect(requests, hasLength(2));
    expect(requests.map((r) => r.headers['Idempotency-Key']), everyElement('stable-key'));
    expect(requests.first.body, requests.last.body);
    expect(requests.last.headers['Authorization'], 'Bearer new-access');
    expect(f.signer.calls, 0);
  });
  test('backend errors on HTTP 200 retain their safe message', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    await f.start();
    f.backend.routes['GET /v1/notifications'] = (_) =>
        json({'code': 'internal_error', 'message': 'Inbox offline'});
    await expectLater(
      ApiNotificationRepository(f.repository)
          .read(category: NotificationFilter.all, unreadOnly: false),
      throwsA(isA<VantaApiFailure>().having((e) => e.details?.message, 'message', 'Inbox offline')),
    );
  });
  test('request decoder remains scoped to the notifications read', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    await f.start();
    f.backend.routes['GET /v1/notifications'] = (_) =>
        http.Response('{"items":[],"next_cursor":null,"unread":2}', 200);
    expect(
      (await ApiNotificationRepository(
        f.repository,
      ).read(category: NotificationFilter.all, unreadOnly: false)).unread,
      2,
    );
    f.backend.routes['GET /other'] = (_) => http.Response('{"value":1.25}', 200);
    expect((await f.repository.get('/other'))['value'], 1.25);
  });
}
