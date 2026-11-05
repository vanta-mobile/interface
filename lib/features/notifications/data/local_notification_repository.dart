import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account_notification.dart';
import '../domain/transfer_observation.dart';
import 'notification_codec.dart';
import 'notification_store_codec.dart';
import '../../funding/domain/transfer_history.dart';
import '../../portfolio/domain/account_snapshot.dart';

abstract interface class NotificationStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class LocalNotificationStorage implements NotificationStorage {
  late final _preferences = SharedPreferencesAsync();
  static const _key = 'vanta.notificationInbox.v1';
  @override
  Future<String?> read() => _preferences.getString(_key);
  @override
  Future<void> write(String value) => _preferences.setString(_key, value);
}

/// Serial read/merge/write; a failed initial read never overwrites existing data.
/// New live events and read changes remain visible in memory until retry succeeds.
class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this.storage);
  final NotificationStorage storage;
  final _changes = StreamController<InboxSnapshot>.broadcast(sync: true);
  Future<void> _tail = Future.value();
  InboxSnapshot _snapshot = InboxSnapshot();
  bool _disposed = false;
  TransferBaselines _baselines = {};
  @override
  InboxSnapshot get snapshot => _snapshot;
  @override
  Stream<InboxSnapshot> get changes => _changes.stream;

  Future<void> _queue(Future<void> Function() action) {
    if (_disposed) return Future.value();
    // Already accepted operations finish even if their listeners are disposed.
    final work = _tail.then((_) => action());
    _tail = work.catchError((Object _) {});
    return work;
  }

  void _publish(Iterable<InboxEntry> entries, {required bool loaded, bool failed = false}) {
    _snapshot = InboxSnapshot(entries: entries, loaded: loaded, storageFailed: failed);
    if (!_disposed) _changes.add(_snapshot);
  }

  @override
  Future<void> reload() => _queue(() async {
    if (_snapshot.loaded) {
      await _save();
      return;
    }
    try {
      final saved = decodeNotificationStore(await storage.read());
      _baselines = saved.baselines;
      final merged = {for (final e in saved.entries) e.key: e};
      for (final entry in _snapshot.entries) {
        merged[entry.key] = merged[entry.key]?.read == true ? entry.markRead() : entry;
      }
      _publish(_trim(merged.values), loaded: true);
      if (_snapshot.entries.isNotEmpty) await _save();
    } catch (_) {
      _publish(_snapshot.entries, loaded: false, failed: true);
    }
  });

  @override
  Future<bool> observeTransfers(
    String address,
    List<TransferRecord> records,
    DateTime observedAt, {
    required bool Function() isCurrent,
  }) async {
    final incoming = List<TransferRecord>.unmodifiable(records);
    var initial = false;
    await _queue(() async {
      if (!isCurrent()) throw const AccountReadFailure('authWalletChanged');
      if (!_snapshot.loaded) throw const AccountReadFailure('transferStorageRequired');
      final wallet = notificationAddress(address);
      final prior = _baselines[wallet];
      initial = prior == null;
      final updated = <String, TransferObservation>{...?prior};
      final seen = <String>{};
      final events = <InboxEntry>[];
      for (final record in incoming) {
        if (!seen.add(record.key)) throw const AccountReadFailure('accountDataInvalid');
        final previous = updated[record.key];
        updated[record.key] = TransferObservation(record, {...?previous?.states, record.status});
        if (!initial && (previous == null || !previous.states.contains(record.status))) {
          events.add(
            InboxEntry(
              address: wallet,
              event: TransferNotification(eventTime: observedAt.toUtc(), record: record),
            ),
          );
        }
      }
      final baselines = {..._baselines, wallet: updated};
      try {
        validateTransferBaselines(baselines);
      } on FormatException {
        throw const AccountReadFailure('transferTrackingFull');
      }
      _baselines = baselines;
      final merged = {for (final entry in _snapshot.entries) entry.key: entry};
      for (final entry in events) {
        merged.putIfAbsent(entry.key, () => entry);
      }
      _publish(_trim(merged.values), loaded: true, failed: _snapshot.storageFailed);
      await _save();
    });
    return initial;
  }

  @override
  Future<void> add(String address, AccountNotification event) => _queue(() async {
    final entry = InboxEntry(address: notificationAddress(address), event: event);
    if (_snapshot.entries.any((e) => e.key == entry.key)) return;
    _publish(
      _trim([..._snapshot.entries, entry]),
      loaded: _snapshot.loaded,
      failed: _snapshot.storageFailed,
    );
    if (_snapshot.loaded) await _save();
  });

  @override
  Future<void> markRead(String address, {String? key}) => _queue(() async {
    final wallet = notificationAddress(address);
    final entries = _snapshot.entries.map(
      (e) => e.address == wallet && (key == null || e.key == key) ? e.markRead() : e,
    );
    _publish(entries, loaded: _snapshot.loaded, failed: _snapshot.storageFailed);
    if (_snapshot.loaded) await _save();
  });

  List<InboxEntry> _trim(Iterable<InboxEntry> entries) {
    final sorted = entries.toList()
      ..sort((a, b) {
        final time = b.event.eventTime.compareTo(a.event.eventTime);
        return time != 0 ? time : a.key.compareTo(b.key);
      });
    if (sorted.length > notificationLimit) sorted.removeRange(notificationLimit, sorted.length);
    // Detailed multi-position events can reach the byte cap before the count cap.
    while (sorted.isNotEmpty &&
        utf8.encode(encodeNotificationStore(sorted, _baselines)).length > notificationByteLimit) {
      sorted.removeLast();
    }
    return sorted;
  }

  Future<void> _save() async {
    try {
      await storage.write(encodeNotificationStore(_snapshot.entries, _baselines));
      _publish(_snapshot.entries, loaded: true);
    } catch (_) {
      _publish(_snapshot.entries, loaded: true, failed: true);
    }
  }

  @override
  Future<void> dispose() {
    _disposed = true;
    return _changes.close();
  }
}
