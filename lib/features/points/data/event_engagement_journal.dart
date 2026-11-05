import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/event_engagement.dart';
import '../domain/points.dart';

class PendingEventEngagement {
  const PendingEventEngagement({
    required this.eventId,
    required this.address,
    required this.action,
    required this.day,
  });
  final int eventId;
  final String address, day;
  final EventEngagementAction action;
  String get key => '$eventId:${address.toLowerCase()}:${action.name}:$day';
}

abstract interface class EventEngagementJournal {
  Future<List<PendingEventEngagement>> read();
  Future<void> add(PendingEventEngagement entry);
  Future<void> remove(String key);
}

/// Public intent metadata only; never signatures, tokens or credentials.
class LocalEventEngagementJournal implements EventEngagementJournal {
  LocalEventEngagementJournal({this.readValue, this.writeValue});
  final Future<String?> Function()? readValue;
  final Future<void> Function(String)? writeValue;
  late final _preferences = SharedPreferencesAsync();
  static const _key = 'vanta.eventEngagement.pending.v1';
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<PendingEventEngagement>> _read() async {
    final raw = await (readValue?.call() ?? _preferences.getString(_key));
    if (raw == null) return [];
    if (raw.length > 65536) throw const FormatException();
    final rows = jsonDecode(raw);
    if (rows is! List || rows.length > 100) throw const FormatException();
    final keys = <String>{}, result = <PendingEventEngagement>[];
    for (final value in rows) {
      if (value is! Map<String, dynamic> ||
          value['id'] is! int ||
          (value['id'] as int) <= 0 ||
          (value['id'] as int) > 9223372036854775807 ||
          value['address'] is! String ||
          !isPointsEvmAddress(value['address'] as String) ||
          value['day'] is! String) {
        throw const FormatException();
      }
      final day = value['day'] as String, parsed = DateTime.tryParse('${day}T00:00:00Z');
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
          parsed == null ||
          eventUtcDay(parsed) != day) {
        throw const FormatException();
      }
      final action = EventEngagementAction.values
          .where((a) => a.name == value['action'])
          .firstOrNull;
      if (action == null) throw const FormatException();
      final entry = PendingEventEngagement(
        eventId: value['id'] as int,
        address: (value['address'] as String).toLowerCase(),
        action: action,
        day: day,
      );
      if (!keys.add(entry.key)) throw const FormatException();
      result.add(entry);
    }
    return result;
  }

  Future<void> _write(List<PendingEventEngagement> entries) {
    final value = jsonEncode(
      entries
          .map(
            (e) => {
              'id': e.eventId,
              'address': e.address.toLowerCase(),
              'action': e.action.name,
              'day': e.day,
            },
          )
          .toList(),
    );
    return writeValue?.call(value) ?? _preferences.setString(_key, value);
  }

  @override
  Future<List<PendingEventEngagement>> read() => _serial(_read);
  @override
  Future<void> add(PendingEventEngagement entry) => _serial(() async {
    final entries = await _read();
    if (entries.any(
          (e) =>
              e.eventId == entry.eventId && e.address.toLowerCase() == entry.address.toLowerCase(),
        ) ||
        entries.length >= 100) {
      throw const FormatException();
    }
    await _write([...entries, entry]);
  });
  @override
  Future<void> remove(String key) => _serial(() async {
    final entries = await _read();
    await _write(entries.where((e) => e.key != key).toList());
  });
}
