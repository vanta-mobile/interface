import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/application/api_notification_provider.dart';
import 'package:vanta/features/notifications/data/api_notification_mapper.dart';
import 'package:vanta/features/notifications/domain/api_notification.dart';

import '../../support/api_notifications.dart';
import '../../support/vanta_api.dart';

void main() {
  test('declared event payloads preserve IDs, execution quantities and transfer references', () {
    final p = mapApiNotification(
      inboxItem(
        payload: {
          'trade_id': 1234567890123456789,
          'order_id': '1234567890123456790',
          'client_order_id': 'client-order-1',
          'executed_qty': '0.123456789012345678',
          'position_side': 'SHORT',
          'kind': 'internal_transfer',
          'reference': 'ledger:123',
          'source': 'report',
        },
      ),
    ).payload;
    expect(p.tradeId, '1234567890123456789');
    expect(p.orderId, '1234567890123456790');
    expect(p.clientOrderId, 'client-order-1');
    expect(p.numbers[NotificationNumber.executedQuantity], Decimal.parse('0.123456789012345678'));
    expect(p.positionSide, 'SHORT');
    expect(p.transferKind, 'internal_transfer');
    expect(p.reference, 'ledger:123');
    expect(p.source, 'report');
    final entry = mapApiNotification(inboxItem(symbol: null, payload: {'symbol': 'BTCUSDT'}));
    expect(entry.symbol, 'BTCUSDT');
  });
  test('capped unread flag remains typed and incompatible fields reject the page', () {
    Map<String, Object?> page(Object? capped, int count) => {
      'items': <Object?>[],
      'next_cursor': null,
      'unread': count,
      'unread_count_capped': capped,
    };
    expect(mapNotificationPage(page(true, 100)).unreadCountCapped, isTrue);
    expect(mapNotificationPage(page(false, 99)).unreadCountCapped, isFalse);
    expect(() => mapNotificationPage(page('true', 100)), throwsFormatException);
    expect(() => mapNotificationPage(page(true, 99)), throwsFormatException);
    expect(
      () => mapApiNotification(inboxItem(payload: {'executed_qty': 'NaN'})),
      throwsFormatException,
    );
  });
  test(
    'capped badge survives filters/failed refresh and clears after successful reconciliation',
    () async {
      final f = InboxFixture();
      addTearDown(f.dispose);
      f.backend.routes['GET /v1/notifications'] = (_) => json({
        'items': <Object?>[],
        'next_cursor': null,
        'unread': 100,
        'unread_count_capped': true,
      });
      await f.start();
      expect(f.state.unreadCountCapped, isTrue);
      expect(f.container.read(serverUnreadLabelProvider), '99+');
      await f.controller.setUnreadOnly(true);
      expect(f.state.unreadCountCapped, isTrue);
      f.backend.routes['GET /v1/notifications'] = (_) =>
          json({'code': 'internal_error', 'message': 'Inbox offline'}, 503);
      await f.controller.refresh();
      expect(f.state.unreadLabel, '99+');
      f.backend.routes['GET /v1/notifications'] = (_) => json({
        'items': <Object?>[],
        'next_cursor': null,
        'unread': 0,
        'unread_count_capped': false,
      });
      await f.controller.markRead();
      expect(f.state.unreadCountCapped, isFalse);
      expect(f.state.unreadLabel, '0');
    },
  );
  for (final locale in ['en', 'zh']) {
    testWidgets('distance is a percentage and declared references are copyable: $locale', (
      t,
    ) async {
      final f = InboxFixture();
      addTearDown(f.dispose);
      f.items.add(
        inboxItem(
          type: 'MARGIN_CALL',
          payload: {
            'distance': '0.08',
            'position_side': 'LONG',
            'order_id': '11',
            'trade_id': '22',
            'client_order_id': 'client-33',
            'reference': 'ref-44',
            'executed_qty': '0.123456789123456789',
            'kind': 'internal_transfer',
          },
        ),
      );
      await f.mount(t, language: locale, size: const Size(320, 844), scale: 1.5);
      await t.tap(find.byKey(const ValueKey('notification-event:1')));
      await t.pumpAndSettle();
      expect(find.text('8%'), findsOneWidget);
      for (final value in ['11', '22', 'client-33', 'ref-44']) {
        expect(find.widgetWithText(SelectableText, value), findsOneWidget);
      }
      expect(find.textContaining('0.123456789123456789'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
    testWidgets('inbox and shared trade-header label show 99+ for capped unread: $locale', (
      t,
    ) async {
      final f = InboxFixture();
      addTearDown(f.dispose);
      f.backend.routes['GET /v1/notifications'] = (_) => json({
        'items': <Object?>[],
        'next_cursor': null,
        'unread': 100,
        'unread_count_capped': true,
      });
      await f.mount(t, language: locale);
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('100'), findsNothing);
      expect(f.container.read(serverUnreadLabelProvider), '99+');
    });
  }
}
