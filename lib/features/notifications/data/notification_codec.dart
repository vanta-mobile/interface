import 'dart:convert';

import '../domain/account_notification.dart';
import 'futures_notification_mapper.dart';
import 'spot_notification_mapper.dart';
import '../../funding/data/transfer_history_mapper.dart';

const notificationLimit = 500;
const notificationByteLimit = 4 * 1024 * 1024;

String notificationAddress(String address) {
  if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address)) throw const FormatException();
  return address.toLowerCase();
}

List<InboxEntry> decodeNotifications(String? source) {
  if (source == null) return [];
  if (utf8.encode(source).length > notificationByteLimit) throw const FormatException();
  final raw = jsonDecode(source);
  if (raw is! Map<String, dynamic> ||
      raw.length != 2 ||
      raw['version'] is! int ||
      raw['version'] != 1 ||
      raw['entries'] is! List) {
    throw const FormatException();
  }
  final records = raw['entries'] as List;
  if (records.length > notificationLimit) throw const FormatException();
  final result = <String, InboxEntry>{};
  for (final record in records) {
    if (record is! Map<String, dynamic> ||
        record.length != 3 ||
        record['address'] is! String ||
        record['read'] is! bool ||
        record['event'] is! Map<String, dynamic>) {
      throw const FormatException();
    }
    final payload = record['event'] as Map<String, dynamic>;
    final event = switch (payload['e']) {
      'executionReport' => mapSpotNotification(payload),
      'FUND_TRANSFER' => _transferNotification(payload),
      _ => mapFuturesNotification(payload),
    };
    if (event == null) throw const FormatException();
    // Accept only our normalized schema, never arbitrary stored/raw payloads.
    final canonical = notificationPayload(event);
    if (!_sameFields(payload, canonical)) throw const FormatException();
    final entry = InboxEntry(
      address: notificationAddress(record['address'] as String),
      event: event,
      read: record['read'] as bool,
    );
    final previous = result[entry.key];
    if (previous == null) {
      result[entry.key] = entry;
    } else if (event is! TransferNotification) {
      throw const FormatException();
    } else if (event.eventTime.isAfter(previous.event.eventTime)) {
      // Earlier stores kept one entry per transfer status; keep the latest.
      result[entry.key] = entry;
    }
  }
  return result.values.toList();
}

bool _sameFields(Object? actual, Object? expected) {
  if (actual is Map && expected is Map) {
    return actual.length == expected.length &&
        expected.keys.every(
          (key) => actual.containsKey(key) && _sameFields(actual[key], expected[key]),
        );
  }
  if (actual is List && expected is List) {
    return actual.length == expected.length &&
        List.generate(actual.length, (i) => i).every((i) => _sameFields(actual[i], expected[i]));
  }
  return actual == expected;
}

String encodeNotifications(Iterable<InboxEntry> entries) => jsonEncode({
  'version': 1,
  'entries': [
    for (final entry in entries)
      {
        'address': notificationAddress(entry.address),
        'read': entry.read,
        'event': notificationPayload(entry.event),
      },
  ],
});

Map<String, dynamic> notificationPayload(AccountNotification event) => switch (event) {
  BalanceNotification e => {
    'e': 'ACCOUNT_UPDATE',
    'E': e.eventTime.millisecondsSinceEpoch,
    'T': e.transactionTime.millisecondsSinceEpoch,
    'a': <String, dynamic>{
      'm': e.reason,
      'B': [
        for (final b in e.balances)
          <String, dynamic>{
            'a': b.asset,
            'wb': b.walletBalance.toString(),
            'cw': b.crossWalletBalance.toString(),
            if (b.change != null) 'bc': b.change.toString(),
          },
      ],
    },
  },
  TransferNotification e => {
    'e': 'FUND_TRANSFER',
    'E': e.eventTime.millisecondsSinceEpoch,
    'record': transferRecordPayload(e.record),
  },
  OrderNotification e => {
    'e': 'ORDER_TRADE_UPDATE',
    'E': e.eventTime.millisecondsSinceEpoch,
    'T': e.transactionTime.millisecondsSinceEpoch,
    'o': <String, dynamic>{
      's': e.symbol,
      'i': e.orderId,
      'c': e.clientOrderId,
      'S': e.side,
      'ps': e.positionSide,
      'o': e.orderType,
      'ot': e.originalType,
      'x': e.executionType,
      'X': e.status,
      'q': e.quantity.toString(),
      'p': e.price.toString(),
      'ap': e.averagePrice.toString(),
      'l': e.lastQuantity.toString(),
      'z': e.filledQuantity.toString(),
      'L': e.lastPrice.toString(),
      't': e.tradeId,
      'T': e.tradeTime.millisecondsSinceEpoch,
      'rp': e.realizedPnl.toString(),
      'R': e.reduceOnly,
      if (e.closePosition != null) 'cp': e.closePosition,
      if (e.fee != null) 'n': e.fee.toString(),
      if (e.feeAsset != null) 'N': e.feeAsset,
      if (e.triggerPrice != null) 'sp': e.triggerPrice.toString(),
      if (e.workingType != null) 'wt': e.workingType,
    },
  },
  SpotOrderNotification e => {
    'e': 'executionReport',
    'E': e.eventTime.millisecondsSinceEpoch,
    'T': e.transactionTime.millisecondsSinceEpoch,
    's': e.symbol,
    'i': e.orderId,
    'c': e.clientOrderId,
    'S': e.side,
    'o': e.orderType,
    if (e.originalType != null) 'ot': e.originalType,
    'x': e.executionType,
    'X': e.status,
    'q': e.quantity.toString(),
    'p': e.price.toString(),
    'ap': e.averagePrice.toString(),
    'l': e.lastQuantity.toString(),
    'z': e.filledQuantity.toString(),
    'L': e.lastPrice.toString(),
    't': e.tradeId,
    'Y': e.lastQuoteAmount.toString(),
    'Z': e.cumulativeQuoteAmount.toString(),
    if (e.creationMilliseconds != null) 'O': e.creationMilliseconds,
    if (e.fee != null) 'n': e.fee.toString(),
    if (e.feeAsset != null) 'N': e.feeAsset,
    if (e.stopPrice != null) 'P': e.stopPrice.toString(),
    if (e.quoteOrderQuantity != null) 'Q': e.quoteOrderQuantity.toString(),
  },
  MarginNotification e => {
    'e': 'MARGIN_CALL',
    'E': e.eventTime.millisecondsSinceEpoch,
    if (e.crossWalletBalance != null) 'cw': e.crossWalletBalance.toString(),
    'p': [
      for (final p in e.positions)
        <String, dynamic>{
          's': p.symbol,
          'ps': p.side,
          'pa': p.quantity.toString(),
          'mt': p.marginType,
          if (p.isolatedWallet != null) 'iw': p.isolatedWallet.toString(),
          'mp': p.markPrice.toString(),
          'up': p.unrealizedPnl.toString(),
          'mm': p.maintenanceMargin.toString(),
        },
    ],
  },
};

TransferNotification _transferNotification(Map<String, dynamic> payload) {
  final time = payload['E'];
  if (time is! int || time <= 0 || time > 253402300799999) throw const FormatException();
  return TransferNotification(
    eventTime: DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
    record: mapTransferRecord(payload['record']),
  );
}
