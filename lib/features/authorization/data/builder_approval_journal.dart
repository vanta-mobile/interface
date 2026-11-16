import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../portfolio/domain/account_snapshot.dart';
import '../domain/builder_authorization.dart';

/// Durable public dispatch metadata, kept separately from device agent keys.
/// A pending approval survives process death and must be queried, never replayed.
class DeviceBuilderApprovalJournal implements BuilderApprovalJournal {
  DeviceBuilderApprovalJournal({
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  }) : _read = read ?? ((key) => _storage.read(key: key)),
       _write = write ?? ((key, value) => _storage.write(key: key, value: value));

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'vanta_builder_approvals_v1', resetOnError: false),
    iOptions: IOSOptions(
      accountName: 'vanta_builder_approvals_v1',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;

  String _key(String owner) {
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(owner)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    return '${owner.toLowerCase()}-${VantaBuilder.address.toLowerCase()}';
  }

  @override
  Future<BuilderApprovalRecord?> load(String owner) async {
    try {
      final raw = await _read(_key(owner));
      if (raw == null) return null;
      if (raw.length > 1024) throw const FormatException();
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> ||
          value['version'] != 1 ||
          value['owner'] != owner.toLowerCase() ||
          value['builder'] != VantaBuilder.address.toLowerCase() ||
          value['maxFeeRate'] is! String ||
          !BuilderApprovalStatus.values.any((s) => s.name == value['status'])) {
        throw const FormatException();
      }
      final cap = Decimal.parse(value['maxFeeRate'] as String);
      if (cap < Decimal.zero || cap > Decimal.parse('0.001')) throw const FormatException();
      return BuilderApprovalRecord(
        status: BuilderApprovalStatus.values.byName(value['status'] as String),
        maxFeeRate: cap,
      );
    } catch (_) {
      throw const AccountReadFailure('authorizationSecureStorageFailed');
    }
  }

  @override
  Future<void> save(String owner, BuilderApprovalRecord record) async {
    try {
      final key = _key(owner);
      final cap = record.maxFeeRate;
      if (cap < Decimal.zero || cap > Decimal.parse('0.001')) throw const FormatException();
      final value = jsonEncode({
        'version': 1,
        'owner': owner.toLowerCase(),
        'builder': VantaBuilder.address.toLowerCase(),
        'maxFeeRate': cap.toString(),
        'status': record.status.name,
      });
      await _write(key, value);
      if (await _read(key) != value) throw const FormatException();
    } catch (_) {
      throw const AccountReadFailure('authorizationSecureStorageFailed');
    }
  }
}
