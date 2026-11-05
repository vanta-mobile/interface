import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../portfolio/domain/account_snapshot.dart';
import '../domain/deposit_submission.dart';
import 'deposit_submission_codec.dart';

class MemoryDepositSubmissionJournal implements DepositSubmissionJournal {
  MemoryDepositSubmissionJournal({Iterable<DepositSubmissionRecord> records = const []})
    : _snapshot = DepositSubmissionJournalSnapshot(records: records);
  DepositSubmissionJournalSnapshot _snapshot;
  final _events = StreamController<DepositSubmissionJournalSnapshot>.broadcast(sync: true);
  @override
  DepositSubmissionJournalSnapshot get snapshot => _snapshot;
  @override
  Stream<DepositSubmissionJournalSnapshot> get changes => _events.stream;
  void publish(DepositSubmissionJournalSnapshot value) {
    _snapshot = value;
    if (!_events.isClosed) _events.add(value);
  }

  void requireReady() {
    if (!snapshot.ready || snapshot.failure != null) {
      throw const AccountReadFailure('depositSubmissionStorage');
    }
  }

  void checkNew(List<DepositSubmissionRecord> records, DepositSubmissionRecord r) {
    if (records.any((v) => v.transaction.from.toLowerCase() == r.transaction.from.toLowerCase())) {
      throw const AccountReadFailure('depositSubmissionPending');
    }
  }

  void replace(Iterable<DepositSubmissionRecord> records) => publish(
    DepositSubmissionJournalSnapshot(
      records: decodeSubmissionJournal(encodeSubmissionJournal(records)),
    ),
  );
  @override
  Future<void> reload() async {}
  @override
  Future<void> prepare(DepositSubmissionRecord record) async {
    requireReady();
    checkNew(snapshot.records, record);
    replace([...snapshot.records, record]);
  }

  @override
  Future<void> attachHash(String key, String hash) async {
    requireReady();
    if (!snapshot.records.any((r) => r.key == key)) {
      throw const AccountReadFailure('depositSubmissionStorage');
    }
    replace(snapshot.records.map((r) => r.key == key ? r.withHash(hash) : r));
  }

  @override
  Future<void> complete(String key) async {
    requireReady();
    replace(snapshot.records.where((r) => r.key != key));
  }

  @override
  Future<void> close() => _events.close();
}

/// One app process; flushed temporary file and same-directory replacement.
class FileDepositSubmissionJournal extends MemoryDepositSubmissionJournal {
  FileDepositSubmissionJournal(this.directory) {
    publish(DepositSubmissionJournalSnapshot(ready: false));
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
        publish(
          DepositSubmissionJournalSnapshot(
            records: snapshot.records,
            failure: const AccountReadFailure('depositSubmissionStorage'),
          ),
        );
        throw const AccountReadFailure('depositSubmissionStorage');
      }
    });
    _queue = next;
    return next;
  }

  Future<File> _file() async {
    final root = await directory();
    await root.create(recursive: true);
    return File('${root.path}/pending-deposits-v1.json');
  }

  Future<List<DepositSubmissionRecord>> _read(File file) async {
    if (!await file.exists()) return [];
    if (await file.length() > 262144) throw const FormatException();
    return decodeSubmissionJournal(await file.readAsString());
  }

  Future<void> _write(File file, List<DepositSubmissionRecord> records) async {
    final source = encodeSubmissionJournal(records),
        validated = decodeSubmissionJournal(encodeSubmissionJournal(records));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(source, flush: true);
    await temp.rename(file.path);
    publish(DepositSubmissionJournalSnapshot(records: validated));
  }

  @override
  Future<void> reload() => _serial(() async {
    final file = await _file(), disk = await _read(file);
    var merged = disk;
    for (final old in snapshot.records) {
      final found = merged.where((r) => r.key == old.key).singleOrNull;
      if (found == null ||
          jsonEncode({...encodeSubmissionRecord(found), 'hash': null}) !=
              jsonEncode({...encodeSubmissionRecord(old), 'hash': null})) {
        throw const FormatException();
      }
      if (old.hash != null) {
        merged = merged.map((r) => r.key == old.key ? r.withHash(old.hash!) : r).toList();
      }
    }
    if (encodeSubmissionJournal(merged) != encodeSubmissionJournal(disk)) {
      await _write(file, merged);
    } else {
      publish(DepositSubmissionJournalSnapshot(records: merged));
    }
  });
  @override
  Future<void> prepare(DepositSubmissionRecord record) => _serial(() async {
    requireReady();
    final file = await _file(), records = await _read(file);
    checkNew(records, record);
    await _write(file, [...records, record]);
  });
  @override
  Future<void> attachHash(String key, String hash) => _serial(() async {
    // Retain a wallet-reported hash even if locating or reading storage fails.
    // A subsequent reload merges it into the unchanged durable unsigned terms.
    final original = snapshot.records.where((r) => r.key == key).singleOrNull;
    if (original == null) {
      throw const AccountReadFailure('depositSubmissionStorage');
    }
    final retained = snapshot.records.map((r) => r.key == key ? r.withHash(hash) : r).toList();
    try {
      requireReady();
      final file = await _file(), records = await _read(file);
      final disk = records.where((r) => r.key == key).singleOrNull;
      if (disk == null ||
          jsonEncode({...encodeSubmissionRecord(disk), 'hash': null}) !=
              jsonEncode({...encodeSubmissionRecord(original), 'hash': null})) {
        throw const FormatException();
      }
      final next = records.map((r) => r.key == key ? r.withHash(hash) : r).toList();
      await _write(file, next);
    } catch (_) {
      publish(
        DepositSubmissionJournalSnapshot(
          records: retained,
          failure: const AccountReadFailure('depositSubmissionStorage'),
        ),
      );
      rethrow;
    }
  });
  @override
  Future<void> complete(String key) => _serial(() async {
    requireReady();
    final file = await _file(), records = await _read(file);
    await _write(file, records.where((r) => r.key != key).toList());
  });
  @override
  Future<void> close() async {
    await _queue.catchError((Object _) {});
    await super.close();
  }
}
