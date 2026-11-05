import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/notifications/data/spot_notification_mapper.dart';
import 'package:vanta/features/notifications/data/notification_codec.dart';
import 'package:vanta/features/notifications/data/local_notification_repository.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';

import '../../support/aster_account.dart';
import '../../support/notifications.dart';

void main() {
  test('preserves precise quote amounts, base fills, fees, types and optional creation time', () {
    final raw = spotNotificationPayload()
      ..addAll({
        'Y': '0.000000000000000001',
        'Z': '0.200000000000000001',
        'l': '0.000000000000000001',
        'z': '0.100000000000000001',
        'O': 1793620800000,
        'n': '-0.000000000000000001',
      });
    final event = mapSpotNotification(raw);
    expect(event.lastQuoteAmount.toString(), '0.000000000000000001');
    expect(event.cumulativeQuoteAmount.toString(), '0.200000000000000001');
    expect(event.lastQuantity.toString(), '0.000000000000000001');
    expect(event.filledQuantity.toString(), '0.100000000000000001');
    expect(event.fee.toString(), '-0.000000000000000001');
    expect(event.feeAsset, 'BNB');
    expect(event.originalType, 'LIMIT');
    expect(event.creationMilliseconds, 1793620800000);
    expect(event.critical, false);
    expect(event.orderId, '1917641');
    expect(event.transactionTime.millisecondsSinceEpoch, raw['T']);
  });
  test(
    'official sample retains zero creation time without inventing epoch time or futures flags',
    () {
      final event = mapSpotNotification(spotNotificationPayload());
      expect(event.creationMilliseconds, 0);
      final normalized = notificationPayload(event);
      expect(normalized['O'], 0);
      expect(normalized.containsKey('ps'), false);
      expect(normalized.containsKey('rp'), false);
      expect(normalized.containsKey('R'), false);
      expect(normalized.containsKey('cp'), false);
      expect(normalized.containsKey('o'), true);
    },
  );
  test('optional fields can be absent and remain absent after storage', () {
    final raw = spotNotificationPayload();
    for (final key in ['ot', 'O', 'n', 'N', 'Q', 'P']) {
      raw.remove(key);
    }
    final event = mapSpotNotification(raw);
    expect(event.originalType, null);
    expect(event.creationMilliseconds, null);
    expect(event.fee, null);
    final encoded = encodeNotifications([InboxEntry(address: accountAddress, event: event)]);
    final decoded = decodeNotifications(encoded).single.event as SpotOrderNotification;
    expect(decoded.originalType, null);
    expect(decoded.creationMilliseconds, null);
    expect(decoded.fee, null);
  });
  test('same IDs in different markets never collide; trade replays do but later fills do not', () {
    final a = spotNotification();
    expect(a.dedupeKey, isNot(notificationOrder().dedupeKey));
    expect(a.dedupeKey, spotNotification(time: a.eventTime.millisecondsSinceEpoch + 3).dedupeKey);
    expect(a.dedupeKey, isNot(spotNotification(tradeId: 43).dedupeKey));
    final raw = spotNotificationPayload()..['s'] = 'ETHUSDT';
    expect(a.dedupeKey, isNot(mapSpotNotification(raw).dedupeKey));
    raw['s'] = 'BTCUSDT';
    raw['i'] = '444';
    expect(a.dedupeKey, isNot(mapSpotNotification(raw).dedupeKey));
  });
  test('nontrade dedup retains status/execution/time transitions', () {
    final raw = spotNotificationPayload(status: 'NEW', filled: '0', last: '0', tradeId: -1);
    final a = mapSpotNotification(raw);
    expect(a.dedupeKey, mapSpotNotification(raw).dedupeKey);
    raw['x'] = 'CANCELED';
    raw['X'] = 'CANCELED';
    final b = mapSpotNotification(raw);
    expect(a.dedupeKey, isNot(b.dedupeKey));
    raw['E'] = (raw['E'] as int) + 1;
    expect(b.dedupeKey, isNot(mapSpotNotification(raw).dedupeKey));
  });
  test('market quote-budget order can have zero original base quantity; others cannot', () {
    final raw = spotNotificationPayload()
      ..addAll({'o': 'MARKET', 'ot': 'MARKET', 'q': '0', 'Q': '10000'});
    final event = mapSpotNotification(raw);
    expect(event.quantity.toString(), '0');
    expect(event.quoteOrderQuantity.toString(), '10000');
    expect(event.filledQuantity.toString(), '0.1');
    raw['Q'] = '0';
    expect(() => mapSpotNotification(raw), throwsFormatException);
  });
  for (final change in <String, Object?>{
    'q': 0.4,
    'z': '0.5',
    'l': '0.2',
    'ap': '0',
    'L': '0',
    'Y': '-1',
    'Z': 1.23,
    't': -1,
    'x': 'CALCULATED',
    'X': 'NEW_ADL',
    'o': 'LIQUIDATION',
    'ot': 'TRAILING_STOP_MARKET',
    'O': -1,
    'T': 0,
    'E': 253402300800000,
    'S': 'LONG',
    'c': 'unsafe\nsecret',
    'i': 'bad',
    'n': null,
    'N': null,
  }.entries) {
    test('invalid spot field ${change.key} is rejected safely', () {
      final raw = spotNotificationPayload()..[change.key] = change.value;
      expect(() => mapSpotNotification(raw), throwsFormatException);
    });
  }
  test(
    'codec keeps existing version-one futures records/read flags while adding spot records',
    () async {
      final storage = MemoryNotificationStorage()
        ..value = encodeNotifications([
          InboxEntry(address: accountAddress, event: notificationOrder(), read: true),
          InboxEntry(address: accountAddress, event: marginNotification()),
        ]);
      final repository = LocalNotificationRepository(storage);
      addTearDown(repository.dispose);
      await repository.reload();
      await repository.add(accountAddress, spotNotification());
      await repository.add(accountAddress, spotNotification(tradeId: 43));
      final records = decodeNotifications(storage.value);
      expect(records.length, 4);
      expect(records.where((e) => e.event is SpotOrderNotification).length, 2);
      expect(records.singleWhere((e) => e.event is OrderNotification).read, true);
      final version = (jsonDecode(storage.value!) as Map)['version'];
      expect(version, 1);
      final restarted = LocalNotificationRepository(storage);
      addTearDown(restarted.dispose);
      await restarted.reload();
      expect(restarted.snapshot.entries.length, 4);
      final raw = jsonDecode(storage.value!) as Map;
      final spot = (raw['entries'] as List).cast<Map<String, dynamic>>().firstWhere(
        (e) => (e['event'] as Map)['e'] == 'executionReport',
      );
      (spot['event'] as Map)['ps'] = 'LONG';
      expect(() => decodeNotifications(jsonEncode(raw)), throwsFormatException);
    },
  );
}
