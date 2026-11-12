import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/auth/application/vanta_api_session_provider.dart';
import 'package:vanta/features/notifications/application/api_notification_provider.dart';
import 'package:vanta/features/notifications/application/notification_provider.dart';
import 'package:vanta/features/notifications/domain/notification_status.dart';

import '../../support/api_notifications.dart';
import '../../support/notifications.dart';
import '../../support/vanta_api.dart';

void main() {
  test('navigation and refresh never sign; explicit session sign-in loads the inbox', () async {
    final f = InboxFixture(storedSession: false);
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    await f.start();
    await f.controller.refresh();
    expect(f.signer.calls, 0);
    expect(f.state.items, isEmpty);
    await f.container.read(vantaApiSessionProvider.notifier).ensure();
    await f.settle();
    expect(f.signer.calls, 1);
    expect(f.state.items, hasLength(1));
  });
  test('server list and global badge exclude the local journal', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    f.extraUnread = 12;
    await f.start();
    final journal = f.container.read(notificationRepositoryProvider);
    await journal.reload();
    await journal.add(vantaTestAddress, notificationOrder());
    expect(f.state.items.map((e) => e.key), ['event:1']);
    expect(f.container.read(serverUnreadNotificationsProvider), 13);
    // Local journal state is still available to transfer/recovery consumers.
    expect(journal.snapshot.entries, hasLength(1));
  });
  test('filters are server parameters and do not narrow the global unread count', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.addAll([
      inboxItem(),
      inboxItem(id: 2, type: 'TRANSFER'),
      inboxItem(id: 3, type: 'FUNDING', read: true),
      inboxItem(id: 4, type: 'ANNOUNCE', broadcast: true),
    ]);
    await f.start();
    await f.controller.filter(NotificationFilter.transfers, true);
    expect(f.state.items.map((e) => e.key), ['event:2']);
    expect(f.state.unread, 3);
    expect(f.backend.requests.last.url.queryParameters, {
      'category': 'transfers',
      'unread_only': 'true',
      'limit': '50',
    });
  });
  test('pagination sorts and deduplicates, rejects cursor cycles and refresh resets', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.backend.routes['GET /v1/notifications'] = (r) => json({
      'items': [inboxItem(id: r.url.queryParameters['cursor'] == null ? 1 : 2)],
      'next_cursor': 'same',
      'unread': 9,
    });
    await f.start();
    await f.controller.loadMore();
    expect(f.state.error, isNotNull);
    expect(f.state.items.map((e) => e.id), [1]);
    f.backend.routes['GET /v1/notifications'] = (r) => json({
      'items': [inboxItem(id: 1), if (r.url.queryParameters['cursor'] != null) inboxItem(id: 2)],
      'next_cursor': r.url.queryParameters['cursor'] == null ? 'second' : null,
      'unread': 9,
    });
    await f.controller.refresh();
    await f.controller.loadMore();
    expect(f.state.items.map((e) => e.id), [2, 1]);
    expect(f.state.nextCursor, isNull);
    expect(f.state.unread, 9);
    await f.controller.refresh();
    expect(f.state.items.map((e) => e.id), [1]);
  });
  test('pull refresh cancels pagination and waits for a fresh first page', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.backend.routes['GET /v1/notifications'] = (_) => json({
      'items': [inboxItem()],
      'next_cursor': 'second',
      'unread': 1,
    });
    await f.start();
    final pageGate = Completer<void>(), refreshGate = Completer<void>();
    f.backend.routes['GET /v1/notifications'] = (request) async {
      final more = request.url.queryParameters.containsKey('cursor');
      await (more ? pageGate : refreshGate).future;
      return json({
        'items': [inboxItem(id: more ? 2 : 3)],
        'next_cursor': null,
        'unread': 8,
      });
    };
    final pagination = f.controller.loadMore();
    await f.settle();
    var done = false;
    final refresh = f.controller.refresh().then((_) => done = true);
    await f.settle();
    await pagination;
    expect(done, isFalse);
    refreshGate.complete();
    await refresh;
    expect(f.state.items.single.id, 3);
    pageGate.complete();
    await f.settle();
    expect(f.state.items.single.id, 3);
  });

  test('read one event preserves the others and reconciles the server badge', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.addAll([inboxItem(), inboxItem(id: 2)]);
    f.extraUnread = 20;
    await f.start();
    await f.controller.markRead(f.state.cache['event:1']);
    expect(f.state.cache['event:1']!.read, isTrue);
    expect(f.state.cache['event:2']!.read, isFalse);
    expect(f.state.unread, 21);
    final post = f.backend.requests.singleWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body), {
      'event_keys': ['event:1'],
    });
    expect(post.headers['Idempotency-Key'], isNotEmpty);
  });
  test('broadcast cursor reads earlier broadcasts while keeping personal events unread', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.addAll([
      inboxItem(),
      inboxItem(id: 2, type: 'ANNOUNCE', broadcast: true),
      inboxItem(id: 3, type: 'MAINTENANCE', broadcast: true),
    ]);
    await f.start();
    await f.controller.markRead(f.state.cache['broadcast:3']);
    expect(f.state.unread, 1);
    expect(f.state.cache['broadcast:2']!.read, isTrue);
    expect(f.state.cache['event:1']!.read, isFalse);
    expect(jsonDecode(f.backend.requests.singleWhere((r) => r.method == 'POST').body), {
      'broadcast_up_to': 3,
    });
  });
  test('mark all is global even with unread/category filters and unloaded entries', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.extraUnread = 100;
    f.items.addAll([inboxItem(), inboxItem(id: 2, type: 'TRANSFER')]);
    await f.start();
    await f.controller.filter(NotificationFilter.orders, true);
    await f.controller.markRead();
    expect(f.state.unread, 0);
    expect(f.state.items, isEmpty);
    expect(jsonDecode(f.backend.requests.singleWhere((r) => r.method == 'POST').body), {
      'all': true,
    });
  });
  test('read failure preserves unread state and explicit retry reuses its operation key', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    await f.start();
    f.writeFailure = true;
    await f.controller.markRead(f.state.items.single);
    expect(f.state.cache['event:1']!.read, isFalse);
    expect(f.state.unread, 1);
    expect(f.state.error, isNotNull);
    f.writeFailure = false;
    await f.controller.markRead(f.state.items.single);
    final writes = f.backend.requests.where((r) => r.method == 'POST').toList();
    expect(writes[0].headers['Idempotency-Key'], writes[1].headers['Idempotency-Key']);
    expect(f.state.unread, 0);
  });
  test('refresh awaits response bodies and preserves old data after failure', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    await f.start();
    f.listGate = Completer<void>();
    f.listFailure = true;
    var done = false;
    final refresh = f.controller.refresh().then((_) => done = true);
    await f.settle();
    expect(done, isFalse);
    expect(f.state.items, hasLength(1));
    f.listGate!.complete();
    await refresh;
    expect(f.state.error, isNotNull);
    expect(f.state.items, hasLength(1));
  });
  test('wallet change cancels late reads and clears private detail snapshots and badge', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    await f.start();
    f.listGate = Completer<void>();
    final refresh = f.controller.refresh();
    await f.settle();
    f.auth.setWallet('0x${'ab' * 20}');
    await f.settle();
    await refresh;
    expect(f.state.items, isEmpty);
    expect(f.state.cache, isEmpty);
    expect(f.state.unread, 0);
    f.listGate!.complete();
    await f.settle();
    expect(f.state.items, isEmpty);
    expect(f.signer.calls, 0);
  });
  test('switching filters cancels a late old page without changing new results', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    await f.start();
    final gate = Completer<void>();
    f.backend.routes['GET /v1/notifications'] = (r) async {
      if (r.url.queryParameters['category'] == 'all') await gate.future;
      return json({
        'items': [
          inboxItem(type: r.url.queryParameters['category'] == 'orders' ? 'ORDER' : 'TRANSFER'),
        ],
        'next_cursor': null,
        'unread': 2,
      });
    };
    final old = f.controller.refresh();
    await f.settle();
    await f.controller.filter(NotificationFilter.orders, false);
    await old;
    expect(f.state.category, NotificationFilter.orders);
    expect(f.state.items.single.type.name, 'order');
    gate.complete();
    await f.settle();
    expect(f.state.items.single.type.name, 'order');
  });
  test('logout cancels an in-flight read marker and prevents a late count update', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    await f.start();
    f.writeGate = Completer<void>();
    final marking = f.controller.markRead(f.state.items.single);
    await f.settle();
    f.auth.setWallet(null);
    await f.settle();
    await marking;
    expect(f.state.items, isEmpty);
    expect(f.state.cache, isEmpty);
    expect(f.state.unread, 0);
    f.writeGate!.complete();
    await f.settle();
    expect(f.state.cache, isEmpty);
    expect(f.state.unread, 0);
  });

  test('a malformed page surfaces failure and retains previous verified data', () async {
    final f = InboxFixture();
    addTearDown(f.dispose);
    f.items.add(inboxItem());
    await f.start();
    f.backend.routes['GET /v1/notifications'] = (_) => json({
      'items': [
        inboxItem(payload: {'fee': 'broken'}),
      ],
      'next_cursor': null,
      'unread': 1,
    });
    await f.controller.refresh();
    expect(f.state.items.single.key, 'event:1');
    expect(f.state.error, isNotNull);
  });
}
