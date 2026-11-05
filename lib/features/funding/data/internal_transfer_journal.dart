import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../../portfolio/domain/account_snapshot.dart';
import '../domain/internal_transfer.dart';
import 'internal_transfer_codec.dart';

class MemoryInternalTransferJournal implements InternalTransferJournal {
  MemoryInternalTransferJournal({Iterable<InternalTransferRecord> records = const []})
    : _snapshot = InternalTransferStorage(records: records);
  InternalTransferStorage _snapshot;
  final _events = StreamController<InternalTransferStorage>.broadcast(sync: true);
  @override
  InternalTransferStorage get snapshot => _snapshot;
  @override
  Stream<InternalTransferStorage> get changes => _events.stream;
  void publish(InternalTransferStorage s) {
    _snapshot = s;
    if (!_events.isClosed) _events.add(s);
  }

  void ready() {
    if (!snapshot.ready || snapshot.failure) {
      throw const AccountReadFailure('internalTransferStorage');
    }
  }

  @override
  Future<void> reload() async {}
  @override
  Future<void> prepare(InternalTransferRecord record) async {
    ready();
    if (snapshot.records.any((r) => r.address.toLowerCase() == record.address.toLowerCase())) {
      throw const AccountReadFailure('internalTransferPending');
    }
    publish(
      InternalTransferStorage(
        records: decodeInternalTransferJournal(
          encodeInternalTransferJournal([...snapshot.records, record]),
        ),
      ),
    );
  }

  @override
  Future<void> report(String key, InternalTransferReply reply) async {
    ready();
    if (!snapshot.records.any((r) => r.key == key)) {
      throw const AccountReadFailure('internalTransferStorage');
    }
    publish(
      InternalTransferStorage(
        records: snapshot.records.map((r) => r.key == key ? r.reported(reply) : r),
      ),
    );
  }

  @override
  Future<void> complete(String key) async {
    ready();
    publish(InternalTransferStorage(records: snapshot.records.where((r) => r.key != key)));
  }

  @override
  Future<void> close() => _events.close();
}

class FileInternalTransferJournal extends MemoryInternalTransferJournal {
  FileInternalTransferJournal(this.directory) {
    publish(InternalTransferStorage(ready: false));
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
        publish(InternalTransferStorage(records: snapshot.records, failure: true));
        throw const AccountReadFailure('internalTransferStorage');
      }
    });
    _queue = next;
    return next;
  }

  Future<File> _file() async {
    final root = await directory();
    await root.create(recursive: true);
    return File('${root.path}/pending-internal-transfers-v1.json');
  }

  Future<List<InternalTransferRecord>> _read(File f) async {
    if (!await f.exists()) return [];
    if (await f.length() > 131072) throw const FormatException();
    return decodeInternalTransferJournal(await f.readAsString());
  }

  Future<void> _write(File f, List<InternalTransferRecord> records) async {
    final source = encodeInternalTransferJournal(records),
        validated = decodeInternalTransferJournal(encodeInternalTransferJournal(records));
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(source, flush: true);
    await temp.rename(f.path);
    publish(InternalTransferStorage(records: validated));
  }

  bool _sameTerms(InternalTransferRecord a, InternalTransferRecord b) =>
      jsonEncode({...encodeInternalTransferRecord(a), 'reply': null}) ==
      jsonEncode({...encodeInternalTransferRecord(b), 'reply': null});
  void _checkRetained(List<InternalTransferRecord> disk) {
    for (final old in snapshot.records) {
      final found = disk.where((r) => r.key == old.key).singleOrNull;
      if (found == null ||
          !_sameTerms(old, found) ||
          old.reply != null && old.reply!.transactionId != found.reply?.transactionId) {
        throw const FormatException();
      }
    }
  }

  @override
  Future<void> reload() => _serial(() async {
    final f = await _file(), disk = await _read(f);
    var merged = disk;
    for (final old in snapshot.records) {
      final found = merged.where((r) => r.key == old.key).singleOrNull;
      if (found == null || !_sameTerms(old, found)) throw const FormatException();
      if (old.reply != null) {
        if (found.reply != null && found.reply!.transactionId != old.reply!.transactionId) {
          throw const FormatException();
        }
        merged = merged.map((r) => r.key == old.key ? old : r).toList();
      }
    }
    if (encodeInternalTransferJournal(merged) != encodeInternalTransferJournal(disk)) {
      await _write(f, merged);
    } else {
      publish(InternalTransferStorage(records: merged));
    }
  });
  @override
  Future<void> prepare(InternalTransferRecord record) => _serial(() async {
    ready();
    final f = await _file(), records = await _read(f);
    _checkRetained(records);
    if (records.any((r) => r.address.toLowerCase() == record.address.toLowerCase())) {
      throw const AccountReadFailure('internalTransferPending');
    }
    await _write(f, [...records, record]);
  });
  @override
  Future<void> report(String key, InternalTransferReply reply) => _serial(() async {
    final old = snapshot.records.where((r) => r.key == key).singleOrNull;
    if (old == null) throw const AccountReadFailure('internalTransferStorage');
    final retained = snapshot.records.map((r) => r.key == key ? r.reported(reply) : r).toList();
    try {
      ready();
      final f = await _file(), disk = await _read(f);
      final found = disk.where((r) => r.key == key).singleOrNull;
      if (found == null || !_sameTerms(old, found)) throw const FormatException();
      await _write(f, disk.map((r) => r.key == key ? r.reported(reply) : r).toList());
    } catch (_) {
      publish(InternalTransferStorage(records: retained, failure: true));
      rethrow;
    }
  });
  @override
  Future<void> complete(String key) => _serial(() async {
    ready();
    final f = await _file(), records = await _read(f);
    _checkRetained(records);
    if (!records.any((r) => r.key == key)) throw const FormatException();
    await _write(f, records.where((r) => r.key != key).toList());
  });
  @override
  Future<void> close() async {
    await _queue.catchError((Object _) {});
    await super.close();
  }
}
