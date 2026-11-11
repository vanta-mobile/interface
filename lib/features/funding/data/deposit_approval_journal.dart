import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../portfolio/domain/account_snapshot.dart';
import '../domain/deposit_approval.dart';
import 'deposit_approval_codec.dart';

class MemoryDepositApprovalJournal implements DepositApprovalJournal {
  MemoryDepositApprovalJournal({Iterable<DepositApprovalRecord> records = const []})
    : _snapshot = DepositApprovalJournalSnapshot(records: records);
  DepositApprovalJournalSnapshot _snapshot;
  final _events = StreamController<DepositApprovalJournalSnapshot>.broadcast(sync: true);
  @override
  DepositApprovalJournalSnapshot get snapshot => _snapshot;
  @override
  Stream<DepositApprovalJournalSnapshot> get changes => _events.stream;
  void publish(DepositApprovalJournalSnapshot value) {
    _snapshot = value;
    if (!_events.isClosed) _events.add(value);
  }

  void requireReady() {
    if (!snapshot.ready || snapshot.failure != null) {
      throw const AccountReadFailure('depositApprovalStorage');
    }
  }

  void checkNew(List<DepositApprovalRecord> records, DepositApprovalRecord r) {
    if (records.length >= 100) throw const AccountReadFailure('depositApprovalStorage');
    if (records.any((v) => v.key == r.key)) {
      throw const AccountReadFailure('depositApprovalPending');
    }
  }

  void replace(Iterable<DepositApprovalRecord> records) => publish(
    DepositApprovalJournalSnapshot(records: decodeApprovalJournal(encodeApprovalJournal(records))),
  );
  @override
  Future<void> reload() async {}
  @override
  Future<void> prepare(DepositApprovalRecord record) async {
    requireReady();
    checkNew(snapshot.records, record);
    replace([...snapshot.records, record]);
  }

  @override
  Future<void> attachHash(String key, String hash) async {
    requireReady();
    if (!snapshot.records.any((r) => r.key == key)) {
      throw const AccountReadFailure('depositApprovalStorage');
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
class FileDepositApprovalJournal extends MemoryDepositApprovalJournal {
  FileDepositApprovalJournal(this.directory) {
    publish(DepositApprovalJournalSnapshot(ready: false));
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
          DepositApprovalJournalSnapshot(
            records: snapshot.records,
            failure: const AccountReadFailure('depositApprovalStorage'),
          ),
        );
        throw const AccountReadFailure('depositApprovalStorage');
      }
    });
    _queue = next;
    return next;
  }

  Future<File> _file() async {
    final root = await directory();
    await root.create(recursive: true);
    return File('${root.path}/pending-deposit-approvals-v1.json');
  }

  Future<List<DepositApprovalRecord>> _read(File file) async {
    if (!await file.exists()) return [];
    if (await file.length() > 262144) throw const FormatException();
    return decodeApprovalJournal(await file.readAsString());
  }

  Future<void> _write(File file, List<DepositApprovalRecord> records) async {
    final source = encodeApprovalJournal(records),
        validated = decodeApprovalJournal(encodeApprovalJournal(records));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(source, flush: true);
    await temp.rename(file.path);
    publish(DepositApprovalJournalSnapshot(records: validated));
  }

  @override
  Future<void> reload() => _serial(() async {
    final file = await _file(), disk = await _read(file);
    var merged = disk;
    for (final old in snapshot.records) {
      final found = merged.where((r) => r.key == old.key).singleOrNull;
      if (found == null ||
          jsonEncode({...encodeApprovalRecord(found), 'hash': null}) !=
              jsonEncode({...encodeApprovalRecord(old), 'hash': null})) {
        throw const FormatException();
      }
      if (old.hash != null) {
        merged = merged.map((r) => r.key == old.key ? r.withHash(old.hash!) : r).toList();
      }
    }
    if (encodeApprovalJournal(merged) != encodeApprovalJournal(disk)) {
      await _write(file, merged);
    } else {
      publish(DepositApprovalJournalSnapshot(records: merged));
    }
  });
  @override
  Future<void> prepare(DepositApprovalRecord record) => _serial(() async {
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
      throw const AccountReadFailure('depositApprovalStorage');
    }
    final retained = snapshot.records.map((r) => r.key == key ? r.withHash(hash) : r).toList();
    try {
      requireReady();
      final file = await _file(), records = await _read(file);
      final disk = records.where((r) => r.key == key).singleOrNull;
      if (disk == null ||
          jsonEncode({...encodeApprovalRecord(disk), 'hash': null}) !=
              jsonEncode({...encodeApprovalRecord(original), 'hash': null})) {
        throw const FormatException();
      }
      final next = records.map((r) => r.key == key ? r.withHash(hash) : r).toList();
      await _write(file, next);
    } catch (_) {
      publish(
        DepositApprovalJournalSnapshot(
          records: retained,
          failure: const AccountReadFailure('depositApprovalStorage'),
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
