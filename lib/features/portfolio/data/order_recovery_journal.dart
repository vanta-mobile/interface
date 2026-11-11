import 'dart:async';
import 'dart:io';

import '../domain/account_snapshot.dart';
import '../domain/order_recovery.dart';
import 'order_recovery_codec.dart';

/// In-memory embedding for previews/tests. Production main injects FileOrderRecoveryJournal.
class MemoryOrderRecoveryJournal implements OrderRecoveryJournal {
  MemoryOrderRecoveryJournal({Iterable<OrderRecoveryRecord> records = const []})
    : _snapshot = OrderRecoverySnapshot(records: records);
  OrderRecoverySnapshot _snapshot;
  final _events = StreamController<OrderRecoverySnapshot>.broadcast(sync: true);
  @override
  OrderRecoverySnapshot get snapshot => _snapshot;
  @override
  Stream<OrderRecoverySnapshot> get changes => _events.stream;
  void publish(OrderRecoverySnapshot value) {
    _snapshot = value;
    if (!_events.isClosed) _events.add(value);
  }

  @override
  Future<void> reload() async {}
  void checkNew(OrderRecoveryRecord record) {
    if (!snapshot.ready || snapshot.failure != null) {
      throw const AccountReadFailure('orderRecoveryStorage');
    }
  }

  @override
  Future<void> prepare(OrderRecoveryRecord record) async {
    checkNew(record);
    if (snapshot.records.any((r) => r.key == record.key)) return;
    final validated = decodeRecoveryRecord(encodeRecoveryRecord(record));
    publish(OrderRecoverySnapshot(records: [...snapshot.records, validated]));
  }

  @override
  Future<void> complete(String key) async =>
      publish(OrderRecoverySnapshot(records: snapshot.records.where((r) => r.key != key)));
  @override
  Future<void> close() => _events.close();
}

/// One app process owns this journal. Atomic replacement uses a flushed temp
/// file on the same filesystem; an interrupted temp file is never promoted.
class FileOrderRecoveryJournal extends MemoryOrderRecoveryJournal {
  FileOrderRecoveryJournal(this.directory) {
    publish(OrderRecoverySnapshot(ready: false));
  }
  final Future<Directory> Function() directory;
  Future<void> _queue = Future.value();
  Future<void> _serial(Future<void> Function() operation) {
    final next = _queue.catchError((Object _) {}).then((_) => operation());
    _queue = next;
    return next;
  }

  Future<File> _file() async {
    final root = await directory();
    await root.create(recursive: true);
    // Preserve the canonical location across schema upgrades so pending v1
    // records are found. The codec reads v1-v4 and new writes use schema v4.
    return File('${root.path}/pending-futures-orders-v1.json');
  }

  Future<List<OrderRecoveryRecord>> _read(File file) async {
    if (!await file.exists()) return [];
    if (await file.length() > 1024 * 1024) throw const FormatException();
    return decodeRecoveryJournal(await file.readAsString());
  }

  Future<void> _guard(Future<void> Function() operation) async {
    try {
      await operation();
    } on AccountReadFailure {
      rethrow;
    } catch (_) {
      publish(
        OrderRecoverySnapshot(
          records: snapshot.records,
          failure: const AccountReadFailure('orderRecoveryStorage'),
        ),
      );
      throw const AccountReadFailure('orderRecoveryStorage');
    }
  }

  @override
  Future<void> reload() => _serial(
    () => _guard(() async {
      final records = await _read(await _file());
      publish(OrderRecoverySnapshot(records: records));
    }),
  );
  Future<void> _write(File file, List<OrderRecoveryRecord> records) async {
    final text = encodeRecoveryJournal(records);
    // Validate the full replacement before touching the canonical file.
    decodeRecoveryJournal(text);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(text, flush: true);
    await temp.rename(file.path);
    publish(OrderRecoverySnapshot(records: records));
  }

  @override
  Future<void> prepare(OrderRecoveryRecord record) => _serial(
    () => _guard(() async {
      checkNew(record);
      final file = await _file(), records = await _read(file);
      if (records.any((r) => r.key == record.key)) return;
      await _write(file, [...records, decodeRecoveryRecord(encodeRecoveryRecord(record))]);
    }),
  );
  @override
  Future<void> complete(String key) => _serial(
    () => _guard(() async {
      final file = await _file(), records = await _read(file);
      if (!records.any((r) => r.key == key)) return;
      await _write(file, records.where((r) => r.key != key).toList());
    }),
  );
  @override
  Future<void> close() async {
    await _queue.catchError((Object _) {});
    await super.close();
  }
}
