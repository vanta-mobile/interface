import 'dart:async';
import 'dart:io';

import '../domain/wallet_operation.dart';

class WalletOperationStorageFailure implements Exception {
  const WalletOperationStorageFailure();
}

class WalletOperationPending implements Exception {
  const WalletOperationPending();
}

class MemoryWalletOperationJournal implements WalletOperationJournal {
  MemoryWalletOperationJournal({Iterable<WalletOperationRecord> records = const []})
    : _snapshot = WalletOperationStorage(records: records);
  WalletOperationStorage _snapshot;
  final _changes = StreamController<WalletOperationStorage>.broadcast(sync: true);
  @override
  WalletOperationStorage get snapshot => _snapshot;
  @override
  Stream<WalletOperationStorage> get changes => _changes.stream;
  void publish(WalletOperationStorage next) {
    _snapshot = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  void requireReady() {
    if (!snapshot.ready || snapshot.failed) throw const WalletOperationStorageFailure();
  }

  List<WalletOperationRecord> add(List<WalletOperationRecord> records, WalletOperationRecord r) {
    if (records.length >= 100) throw const WalletOperationStorageFailure();
    if (records.any((v) => !v.acknowledged && v.address.toLowerCase() == r.address.toLowerCase())) {
      throw const WalletOperationPending();
    }
    return decodeWalletOperations(encodeWalletOperations([...records, r]));
  }

  @override
  Future<void> reload() async {}
  @override
  Future<void> prepare(WalletOperationRecord record) async {
    requireReady();
    publish(WalletOperationStorage(records: add(snapshot.records, record)));
  }

  @override
  Future<void> report(String key, [String? reference]) async {
    requireReady();
    if (!snapshot.records.any((r) => r.key == key)) throw const WalletOperationStorageFailure();
    publish(
      WalletOperationStorage(
        records: snapshot.records.map((r) => r.key == key ? r.reported(reference) : r),
      ),
    );
  }

  @override
  Future<void> removeNotSent(String key) async {
    requireReady();
    publish(WalletOperationStorage(records: snapshot.records.where((r) => r.key != key)));
  }

  @override
  Future<void> close() => _changes.close();
}

/// Records are flushed before dispatch. Failed writes block future dispatches.
class FileWalletOperationJournal extends MemoryWalletOperationJournal {
  FileWalletOperationJournal(this.directory, {this.filename = 'wallet-operations-v1.json'}) {
    publish(WalletOperationStorage(ready: false));
  }
  final Future<Directory> Function() directory;
  final String filename;
  Future<void> _queue = Future.value();
  Future<void> _serial(Future<void> Function() operation) {
    final next = _queue.catchError((Object _) {}).then((_) async {
      try {
        await operation();
      } on WalletOperationPending {
        rethrow;
      } catch (_) {
        publish(WalletOperationStorage(records: snapshot.records, failed: true));
        throw const WalletOperationStorageFailure();
      }
    });
    _queue = next;
    return next;
  }

  Future<File> _file() async {
    final d = await directory();
    await d.create(recursive: true);
    return File('${d.path}/$filename');
  }

  Future<List<WalletOperationRecord>> _read(File file) async {
    if (!await file.exists()) return [];
    if (await file.length() > 262144) throw const FormatException();
    return decodeWalletOperations(await file.readAsString());
  }

  Future<void> _write(File file, List<WalletOperationRecord> records) async {
    final encoded = encodeWalletOperations(records),
        validated = decodeWalletOperations(encodeWalletOperations(records));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(encoded, flush: true);
    await temp.rename(file.path);
    publish(WalletOperationStorage(records: validated));
  }

  @override
  Future<void> reload() => _serial(() async {
    final file = await _file();
    var disk = await _read(file);
    for (final old in snapshot.records) {
      final found = disk.where((r) => r.key == old.key).singleOrNull;
      if (found == null ||
          encodeWalletOperations([
                WalletOperationRecord(
                  kind: found.kind,
                  address: found.address,
                  nonce: found.nonce,
                  preparedAt: found.preparedAt,
                  terms: found.terms,
                ),
              ]) !=
              encodeWalletOperations([
                WalletOperationRecord(
                  kind: old.kind,
                  address: old.address,
                  nonce: old.nonce,
                  preparedAt: old.preparedAt,
                  terms: old.terms,
                ),
              ])) {
        throw const FormatException();
      }
      if (old.acknowledged) disk = disk.map((r) => r.key == old.key ? old : r).toList();
    }
    if (encodeWalletOperations(disk) !=
        await file.readAsString().catchError((Object _) => encodeWalletOperations([]))) {
      await _write(file, disk);
    } else {
      publish(WalletOperationStorage(records: disk));
    }
  });
  @override
  Future<void> prepare(WalletOperationRecord record) => _serial(() async {
    requireReady();
    final file = await _file(), records = await _read(file);
    await _write(file, add(records, record));
  });
  @override
  Future<void> report(String key, [String? reference]) => _serial(() async {
    final old = snapshot.records.where((r) => r.key == key).singleOrNull;
    if (old == null) throw const WalletOperationStorageFailure();
    final retained = snapshot.records.map((r) => r.key == key ? r.reported(reference) : r).toList();
    try {
      requireReady();
      final file = await _file(), records = await _read(file);
      final found = records.where((r) => r.key == key).singleOrNull;
      if (found == null || encodeWalletOperations([found]) != encodeWalletOperations([old])) {
        throw const FormatException();
      }
      await _write(file, records.map((r) => r.key == key ? r.reported(reference) : r).toList());
    } catch (_) {
      publish(WalletOperationStorage(records: retained, failed: true));
      rethrow;
    }
  });
  @override
  Future<void> removeNotSent(String key) => _serial(() async {
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
