import 'dart:convert';

import '../../funding/data/transfer_history_mapper.dart';
import '../../funding/domain/transfer_history.dart';
import '../domain/account_notification.dart';
import '../domain/transfer_observation.dart';
import 'notification_codec.dart';

const transferObservationLimit = 5000;
const transferWalletLimit = 100;
const transferObservationByteLimit = 1024 * 1024;
typedef TransferBaselines = Map<String, Map<String, TransferObservation>>;

class NotificationStore {
  NotificationStore(this.entries, this.baselines);
  final List<InboxEntry> entries;
  final TransferBaselines baselines;
}

/// Read v1 without a migration write; v2 keeps inbox and baselines in one value.
NotificationStore decodeNotificationStore(String? source) {
  if (source == null) return NotificationStore([], {});
  if (utf8.encode(source).length > notificationByteLimit) throw const FormatException();
  final raw = jsonDecode(source);
  if (raw is Map<String, dynamic> && raw['version'] == 1) {
    return NotificationStore(decodeNotifications(source), {});
  }
  if (raw is! Map<String, dynamic> ||
      raw.length != 3 ||
      raw['version'] is! int ||
      raw['version'] != 2 ||
      raw['inbox'] is! Map<String, dynamic> ||
      raw['transfers'] is! Map<String, dynamic>) {
    throw const FormatException();
  }
  final baselines = <String, Map<String, TransferObservation>>{};
  final wallets = raw['transfers'] as Map<String, dynamic>;
  if (wallets.isEmpty || wallets.length > transferWalletLimit) throw const FormatException();
  for (final entry in wallets.entries) {
    final address = notificationAddress(entry.key);
    if (address != entry.key || entry.value is! List) throw const FormatException();
    final saved = entry.value as List;
    if (saved.length > transferObservationLimit) throw const FormatException();
    final observations = <String, TransferObservation>{};
    for (final value in saved) {
      if (value is! Map<String, dynamic> ||
          value.length != 2 ||
          value['record'] is! Map<String, dynamic> ||
          value['states'] is! List) {
        throw const FormatException();
      }
      final record = value['record'] as Map<String, dynamic>;
      final mapped = mapTransferRecord(record);
      final states = value['states'] as List;
      final known = TransferStatus.values.map((s) => s.name).toSet();
      if (jsonEncode(_sorted(record)) != jsonEncode(_sorted(transferRecordPayload(mapped))) ||
          states.isEmpty ||
          states.length > 3 ||
          states.toSet().length != states.length ||
          !states.every(known.contains) ||
          !states.contains(mapped.status.name) ||
          observations.containsKey(mapped.key)) {
        throw const FormatException();
      }
      observations[mapped.key] = TransferObservation(
        mapped,
        states.map((s) => TransferStatus.values.byName(s as String)),
      );
    }
    baselines[address] = observations;
  }
  validateTransferBaselines(baselines);
  return NotificationStore(decodeNotifications(jsonEncode(raw['inbox'])), baselines);
}

Map<String, dynamic> _sorted(Map<String, dynamic> value) =>
    Map.fromEntries(value.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));

Map<String, dynamic> _baselinePayload(TransferBaselines baselines) => {
  for (final wallet in baselines.entries)
    wallet.key: [
      for (final observation in wallet.value.values)
        {
          'record': transferRecordPayload(observation.record),
          'states': observation.states.map((s) => s.name).toList()..sort(),
        },
    ],
};

void validateTransferBaselines(TransferBaselines baselines) {
  if (baselines.length > transferWalletLimit ||
      baselines.values.fold<int>(0, (count, records) => count + records.length) >
          transferObservationLimit ||
      utf8.encode(jsonEncode(_baselinePayload(baselines))).length > transferObservationByteLimit) {
    throw const FormatException();
  }
}

String encodeNotificationStore(Iterable<InboxEntry> entries, TransferBaselines baselines) =>
    baselines.isEmpty
    ? encodeNotifications(entries)
    : jsonEncode({
        'version': 2,
        'inbox': jsonDecode(encodeNotifications(entries)),
        'transfers': _baselinePayload(baselines),
      });
