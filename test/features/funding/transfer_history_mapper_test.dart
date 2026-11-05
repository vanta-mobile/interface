import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/features/funding/data/transfer_history_mapper.dart';
import 'package:vanta/features/notifications/data/notification_codec.dart';
import 'package:vanta/features/notifications/domain/account_notification.dart';

import '../../support/aster_account.dart';
import '../../support/transfers.dart';

void main() {
  test('exact amount, record time, absent hash and market survive inbox roundtrip', () {
    for (final market in ['spot', 'perp']) {
      for (final type in ['DEPOSIT', 'WITHDRAW']) {
        for (final state in ['PROCESSING', 'SUCCESS', 'FAILED']) {
          final record = transferRecord(market: market, type: type, status: state);
          final event = TransferNotification(eventTime: DateTime.utc(2026, 11, 3), record: record);
          final decoded =
              decodeNotifications(
                    encodeNotifications([InboxEntry(address: accountAddress, event: event)]),
                  ).single.event
                  as TransferNotification;
          expect(decoded.record.amount.toString(), '0.000000000000000001');
          expect(decoded.record.recordTime.millisecondsSinceEpoch, 1742198400000);
          expect(decoded.record.txHash, null);
          expect(decoded.eventTime, event.eventTime);
          expect(decoded.dedupeKey, event.dedupeKey);
          expect(decoded.category, 'FUND_TRANSFER');
          expect(decoded.eventType, '${type}_$state');
        }
      }
    }
  });
  final invalid = <String, Object?>{
    'id': 123,
    'type': 'TRANSFER',
    'state': 'COMPLETED',
    'accountType': 'futures',
    'asset': 'unsafe\nUSDT',
    'amount': 1.2,
    'time': '1742198400000',
    'chainId': '56',
    'txHash': 'https://unsafe.invalid/token',
  };
  for (final item in invalid.entries) {
    test('rejects malformed ${item.key} without partial history', () {
      final bad = transferPayload()..[item.key] = item.value;
      expect(() => mapTransferHistory([transferPayload(id: 'good'), bad]), throwsFormatException);
    });
  }
  test('rejects zero, negative, exponent and unbounded financial values', () {
    for (final value in ['0', '-1', '1e-18', ' 1', '1.0.0', '1' * 161]) {
      expect(() => mapTransferRecord(transferPayload()..['amount'] = value), throwsFormatException);
    }
  });
  test('rejects invalid timestamp, chain, ID and oversized response', () {
    for (final change in [
      {'time': 0},
      {'time': 253402300800000},
      {'chainId': 0},
      {'chainId': 9007199254740992},
      {'id': ''},
      {'txHash': 'x' * 257},
    ]) {
      expect(() => mapTransferRecord(transferPayload()..addAll(change)), throwsFormatException);
    }
    expect(() => mapTransferHistory(List.filled(5001, transferPayload())), throwsFormatException);
    expect(() => mapTransferHistory({'data': <Object?>[]}), throwsFormatException);
  });
  test('market and direction are part of record and state identity; duplicates rejected', () {
    final records = mapTransferHistory([
      transferPayload(),
      transferPayload(market: 'spot'),
      transferPayload(type: 'WITHDRAW'),
    ]);
    expect(records.map((e) => e.key).toSet().length, 3);
    expect(() => records.clear(), throwsUnsupportedError);
    expect(
      () => mapTransferHistory([transferPayload(), transferPayload(status: 'SUCCESS')]),
      throwsFormatException,
    );
  });
  test('empty hash stays unknown and opaque non-EVM hash is preserved', () {
    expect(mapTransferRecord(transferPayload()..['txHash'] = '').txHash, null);
    expect(mapTransferRecord(transferPayload(hash: 'Abc123_-')).txHash, 'Abc123_-');
  });
  test('stored transfer payload must be canonical, bounded and contain no invented fields', () {
    final encoded = encodeNotifications([
      InboxEntry(
        address: accountAddress,
        event: TransferNotification(eventTime: DateTime.utc(2026), record: transferRecord()),
      ),
    ]);
    for (final key in ['failureReason', 'completionTime', 'privateKey']) {
      final raw = jsonDecode(encoded) as Map<String, dynamic>;
      final event = ((raw['entries'] as List).single as Map)['event'] as Map;
      (event['record'] as Map)[key] = 'untrusted';
      expect(() => decodeNotifications(jsonEncode(raw)), throwsFormatException);
    }
    final raw = jsonDecode(encoded) as Map<String, dynamic>;
    (((raw['entries'] as List).single as Map)['event'] as Map)['E'] = 0;
    expect(() => decodeNotifications(jsonEncode(raw)), throwsFormatException);
  });
}
