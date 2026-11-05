import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/data/futures_notification_mapper.dart';
import 'package:vanta/features/notifications/data/notification_codec.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';

import '../../support/aster_account.dart';
import '../../support/notifications.dart';

void main() {
  test('keeps all quantities, IDs, times, commission, trigger and PnL precisely', () {
    final payload = notificationOrderPayload(
      filled: '0.123456789123456789',
      last: '0.000000000000000001',
    );
    final raw = payload['o'] as Map<String, dynamic>;
    raw.addAll({
      'n': '-0.00000000000001',
      'N': 'USDT',
      'rp': '-0.123456789123456789',
      'sp': '76543.123456789',
      'wt': 'MARK_PRICE',
      'R': true,
    });
    final event = mapFuturesNotification(payload)! as OrderNotification;
    expect(event.lastQuantity.toString(), '0.000000000000000001');
    expect(event.filledQuantity.toString(), '0.123456789123456789');
    expect(event.fee.toString(), '-0.00000000000001');
    expect(event.realizedPnl.toString(), '-0.123456789123456789');
    expect(event.triggerPrice.toString(), '76543.123456789');
    expect(event.workingType, 'MARK_PRICE');
    expect(event.clientOrderId, 'vanta-test-order');
    expect(event.transactionTime.millisecondsSinceEpoch, payload['T']);
    expect(event.tradeTime.millisecondsSinceEpoch, raw['T']);
    expect(event.reduceOnly, true);
    expect(event.closePosition, false);
    expect(event.critical, false);
  });
  test('trade dedup keeps later fills but ignores replay timestamps', () {
    final a = notificationOrder();
    final b = notificationOrder(tradeId: 43, filled: '0.2');
    final replay = notificationOrder(time: a.eventTime.millisecondsSinceEpoch + 500);
    expect(a.dedupeKey, isNot(b.dedupeKey));
    expect(a.dedupeKey, replay.dedupeKey);
    final payload = notificationOrderPayload();
    (payload['o'] as Map)['i'] = '77';
    expect(a.dedupeKey, isNot(mapFuturesNotification(payload)!.dedupeKey));
    (payload['o'] as Map)
      ..['i'] = a.orderId
      ..['s'] = 'ETHUSDT';
    expect(a.dedupeKey, isNot(mapFuturesNotification(payload)!.dedupeKey));
  });
  test('non-trade changes use execution, status and event/trade times', () {
    final payload = notificationOrderPayload(filled: '0', last: '0', status: 'NEW');
    (payload['o'] as Map)['t'] = -1;
    final first = mapFuturesNotification(payload)!;
    expect(first.dedupeKey, mapFuturesNotification(payload)!.dedupeKey);
    payload['E'] = (payload['E'] as int) + 1;
    expect(first.dedupeKey, isNot(mapFuturesNotification(payload)!.dedupeKey));
  });
  for (final marker in [
    'autoclose-1',
    'adl_autoclose',
    'NEW_INSURANCE',
    'NEW_ADL',
    'CALCULATED',
    'LIQUIDATION',
  ]) {
    test('classifies risk once for $marker', () {
      final payload = notificationOrderPayload();
      final raw = payload['o'] as Map;
      if (marker.startsWith('NEW_')) {
        raw['X'] = marker;
      } else if (marker == 'CALCULATED') {
        raw['x'] = marker;
      } else if (marker == 'LIQUIDATION') {
        raw['o'] = marker;
      } else {
        raw['c'] = marker;
      }
      final event = mapFuturesNotification(payload)! as OrderNotification;
      expect(event.critical, true);
      expect(
        event.risk,
        marker == 'adl_autoclose' || marker == 'NEW_ADL' ? OrderRisk.adl : OrderRisk.liquidation,
      );
      expect(event.status, raw['X']);
      expect(event.filledQuantity.toString(), '0.1');
    });
  }
  test('ADL identity remains ADL when execution is CALCULATED', () {
    final payload = notificationOrderPayload();
    (payload['o'] as Map)
      ..['c'] = 'adl_autoclose'
      ..['x'] = 'CALCULATED';
    expect((mapFuturesNotification(payload) as OrderNotification).risk, OrderRisk.adl);
  });
  test('margin event preserves every position and canonicalizes order/decimal variants', () {
    final payload = marginNotificationPayload();
    final event = mapFuturesNotification(payload)! as MarginNotification;
    expect(event.positions.length, 2);
    expect(event.positions.last.isolatedWallet.toString(), '-0.2');
    expect(event.positions.last.markPrice.toString(), '80000.00000001');
    expect(event.critical, true);
    payload['p'] = (payload['p'] as List).reversed.toList();
    ((payload['p'] as List).first as Map)['pa'] = '-0.00100';
    expect(event.dedupeKey, mapFuturesNotification(payload)!.dedupeKey);
    payload['cw'] = '2';
    expect(event.dedupeKey, isNot(mapFuturesNotification(payload)!.dedupeKey));
    expect(() => event.positions.clear(), throwsUnsupportedError);
  });
  test('cross wallet balance and cross isolated wallet can be absent', () {
    final payload = marginNotificationPayload()..remove('cw');
    ((payload['p'] as List).first as Map).remove('iw');
    final event = mapFuturesNotification(payload)! as MarginNotification;
    expect(event.crossWalletBalance, null);
    expect(event.positions.first.isolatedWallet, null);
  });
  for (final change in <String, Object?>{
    'q': 0.4,
    'z': 'NaN',
    'l': '-1',
    'L': '0',
    'ap': '0',
    't': -1,
    'i': '0',
    'c': 'secret\nunsafe',
    'rp': 0.1,
    'ps': 'UNKNOWN',
    'R': 'false',
    'X': 'FAKE',
    'ot': 'UNKNOWN',
    'n': '0.01',
  }.entries) {
    test('rejects invalid order field ${change.key}', () {
      final payload = notificationOrderPayload();
      (payload['o'] as Map)[change.key] = change.value;
      expect(() => mapFuturesNotification(payload), throwsFormatException);
    });
  }
  for (final mutation in [
    'empty',
    'duplicate',
    'float',
    'side',
    'missing_isolated',
    'zero_mark',
    'zero_quantity',
    'time',
  ]) {
    test('rejects invalid margin $mutation', () {
      final payload = marginNotificationPayload();
      final positions = payload['p'] as List;
      switch (mutation) {
        case 'empty':
          positions.clear();
        case 'duplicate':
          positions.add(positions.first);
        case 'float':
          (positions.first as Map)['mm'] = 1.2;
        case 'side':
          (positions.first as Map)['pa'] = '-1';
        case 'missing_isolated':
          (positions.last as Map).remove('iw');
        case 'zero_mark':
          (positions.first as Map)['mp'] = '0';
        case 'zero_quantity':
          (positions.first as Map)['pa'] = '0';
        case 'time':
          payload['E'] = 253402300800000;
      }
      expect(() => mapFuturesNotification(payload), throwsFormatException);
    });
  }
  test(
    'codec round trips exact details and read state, rejects extra fields/version/duplicates',
    () {
      final entries = [
        InboxEntry(address: accountAddress, event: notificationOrder(), read: true),
        InboxEntry(address: accountAddress, event: marginNotification()),
      ];
      final encoded = encodeNotifications(entries);
      final decoded = decodeNotifications(encoded);
      expect(encodeNotifications(decoded), encoded);
      expect(decoded.first.read, true);
      expect(decoded.last.read, false);
      for (final mutation in [
        'version',
        'extra',
        'duplicate',
        'address',
        'decimal',
        'unknown_event',
      ]) {
        final raw = jsonDecode(encoded) as Map;
        final records = raw['entries'] as List;
        switch (mutation) {
          case 'version':
            raw['version'] = 2;
          case 'extra':
            ((records.first as Map)['event'] as Map)['secret'] = 'must not persist';
          case 'duplicate':
            records.add(records.first);
          case 'address':
            (records.first as Map)['address'] = '0xinvalid';
          case 'decimal':
            (((records.first as Map)['event'] as Map)['o'] as Map)['q'] = 0.4;
          case 'unknown_event':
            ((records.first as Map)['event'] as Map)['e'] = 'ACCOUNT_UPDATE';
        }
        expect(() => decodeNotifications(jsonEncode(raw)), throwsFormatException, reason: mutation);
      }
    },
  );
  test('oversized notification storage and excessive record count are rejected', () {
    expect(() => decodeNotifications(' ' * (notificationByteLimit + 1)), throwsFormatException);
    final entry = InboxEntry(address: accountAddress, event: notificationOrder());
    final excessive = encodeNotifications(List.filled(notificationLimit + 1, entry));
    expect(() => decodeNotifications(excessive), throwsFormatException);
  });
  test('close-all keeps zero original quantity and actual reported fills distinct', () {
    final payload = notificationOrderPayload(status: 'FILLED', filled: '1.2', last: '0.1');
    (payload['o'] as Map)
      ..['q'] = '0'
      ..['cp'] = true;
    final event = mapFuturesNotification(payload)! as OrderNotification;
    expect(event.quantity.toString(), '0');
    expect(event.filledQuantity.toString(), '1.2');
    expect(event.lastQuantity.toString(), '0.1');
    expect(event.closePosition, true);
    expect(event.dedupeKey, contains('PERP'));
  });
}
