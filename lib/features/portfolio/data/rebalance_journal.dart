import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../domain/account_snapshot.dart';
import '../domain/asset_rebalance.dart';
import 'rebalance_codec.dart';

class MemoryRebalanceJournal implements RebalanceJournal {
  MemoryRebalanceJournal({Iterable<RebalanceRecord> records = const []})
    : _snapshot = RebalanceStorage(records: records);
  RebalanceStorage _snapshot;
  final _events = StreamController<RebalanceStorage>.broadcast(sync: true);
  @override
  RebalanceStorage get snapshot => _snapshot;
  @override
  Stream<RebalanceStorage> get changes => _events.stream;
  void publish(RebalanceStorage s) {
    _snapshot = s;
    if (!_events.isClosed) _events.add(s);
  }

  void ready() {
    if (!snapshot.ready || snapshot.failure) throw const AccountReadFailure('rebalanceStorage');
  }

  @override
  Future<void> reload() async {}
  @override
  Future<void> prepare(RebalanceRecord record) async {
    ready();
    if (snapshot.records.any((r) => r.address.toLowerCase() == record.address.toLowerCase())) {
      throw const AccountReadFailure('rebalancePending');
    }
    publish(
      RebalanceStorage(
        records: decodeRebalanceJournal(encodeRebalanceJournal([...snapshot.records, record])),
      ),
    );
  }

  @override
  Future<void> report(String key, RebalanceReply reply) async {
    ready();
    if (!snapshot.records.any((r) => r.key == key)) {
      throw const AccountReadFailure('rebalanceStorage');
    }
    publish(
      RebalanceStorage(records: snapshot.records.map((r) => r.key == key ? r.reported(reply) : r)),
    );
  }

  @override
  Future<void> complete(String key) async {
    ready();
    publish(RebalanceStorage(records: snapshot.records.where((r) => r.key != key)));
  }

  @override
  Future<void> close() => _events.close();
}

class FileRebalanceJournal extends MemoryRebalanceJournal {
  FileRebalanceJournal(this.directory) {
    publish(RebalanceStorage(ready: false));
  }
  final Future<Directory> Function() directory;
  Future<void> _queue = Future.value();
  Future<void> _serial(Future<void> Function() operation) {
    final next = _queue.catchError((Object _) {}).then((_) async {
      try {
        await operation();
      } on AccountReadFailure {
        rethrow;
      } catch (_) {
        publish(RebalanceStorage(records: snapshot.records, failure: true));
        throw const AccountReadFailure('rebalanceStorage');
      }
    });
    _queue = next;
    return next;
  }

  Future<File> _file() async {
    final root = await directory();
    await root.create(recursive: true);
    return File('${root.path}/pending-asset-rebalances-v1.json');
  }

  Future<List<RebalanceRecord>> _read(File f) async {
    if (!await f.exists()) return [];
    if (await f.length() > 131072) throw const FormatException();
    return decodeRebalanceJournal(await f.readAsString());
  }

  Future<void> _write(File f, List<RebalanceRecord> records) async {
    final source = encodeRebalanceJournal(records),
        validated = decodeRebalanceJournal(encodeRebalanceJournal(records));
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(source, flush: true);
    await temp.rename(f.path);
    publish(RebalanceStorage(records: validated));
  }

  bool _sameTerms(RebalanceRecord a, RebalanceRecord b) =>
      jsonEncode({...encodeRebalanceRecord(a), 'reply': null}) ==
      jsonEncode({...encodeRebalanceRecord(b), 'reply': null});
  @override
  Future<void> reload() => _serial(() async {
    final f = await _file(), disk = await _read(f);
    var merged = disk;
    for (final old in snapshot.records) {
      final found = merged.where((r) => r.key == old.key).singleOrNull;
      if (found == null || !_sameTerms(old, found)) throw const FormatException();
      if (old.reply != null) {
        if (found.reply != null &&
            jsonEncode(encodeRebalanceReply(found.reply!)) !=
                jsonEncode(encodeRebalanceReply(old.reply!))) {
          throw const FormatException();
        }
        merged = merged.map((r) => r.key == old.key ? old : r).toList();
      }
    }
    if (encodeRebalanceJournal(merged) != encodeRebalanceJournal(disk)) {
      await _write(f, merged);
    } else {
      publish(RebalanceStorage(records: merged));
    }
  });
  @override
  Future<void> prepare(RebalanceRecord record) => _serial(() async {
    ready();
    final f = await _file(), records = await _read(f);
    if (records.any((r) => r.address.toLowerCase() == record.address.toLowerCase())) {
      throw const AccountReadFailure('rebalancePending');
    }
    await _write(f, [...records, record]);
  });
  @override
  Future<void> report(String key, RebalanceReply reply) => _serial(() async {
    final old = snapshot.records.where((r) => r.key == key).singleOrNull;
    if (old == null) throw const AccountReadFailure('rebalanceStorage');
    final retained = snapshot.records.map((r) => r.key == key ? r.reported(reply) : r).toList();
    try {
      ready();
      final f = await _file(), disk = await _read(f);
      final found = disk.where((r) => r.key == key).singleOrNull;
      if (found == null || !_sameTerms(old, found)) throw const FormatException();
      await _write(f, disk.map((r) => r.key == key ? r.reported(reply) : r).toList());
    } catch (_) {
      publish(RebalanceStorage(records: retained, failure: true));
      rethrow;
    }
  });
  @override
  Future<void> complete(String key) => _serial(() async {
    ready();
    final f = await _file(), records = await _read(f);
    await _write(f, records.where((r) => r.key != key).toList());
  });
  @override
  Future<void> close() async {
    await _queue.catchError((Object _) {});
    await super.close();
  }
}
