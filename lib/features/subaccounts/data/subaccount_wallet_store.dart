import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart' as evm;

import '../../../core/data/aster_signature_verifier.dart';
import '../../../core/domain/wallet_operation.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/wallet_connection.dart';
import '../../auth/domain/wallet_transaction.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../domain/generated_subaccount.dart';

typedef SecureWalletRead = Future<String?> Function(String key);
typedef SecureWalletWrite = Future<void> Function(String key, String value);

/// A single encrypted envelope keeps key and metadata durable before any POST.
/// iOS keys are device-only; Android uses the platform-backed secure store.
class DeviceSubaccountWalletStore implements SubaccountWalletStore {
  DeviceSubaccountWalletStore({SecureWalletRead? read, SecureWalletWrite? write})
    : _read = read ?? ((key) => _storage.read(key: key)),
      _write = write ?? ((key, value) => _storage.write(key: key, value: value));
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'vanta_subaccounts_v1', resetOnError: false),
    iOptions: IOSOptions(
      accountName: 'vanta_subaccounts_v1',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  static const storageKey = 'vanta-generated-subaccounts-v1';
  final SecureWalletRead _read;
  final SecureWalletWrite _write;
  Future<void> _queue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() work) {
    final task = _queue.then((_) => work());
    _queue = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  Future<List<Map<String, Object?>>> _entries() async {
    try {
      final raw = await _read(storageKey);
      if (raw == null) return [];
      if (raw.length > 262144) throw const FormatException();
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['version'] != 1 || data['wallets'] is! List) {
        throw const FormatException();
      }
      final entries = (data['wallets'] as List).map((e) {
        if (e is! Map<String, dynamic> ||
            e.length != 5 ||
            e['owner'] is! String ||
            !validOperationAddress(e['owner'] as String) ||
            e['address'] is! String ||
            !validOperationAddress(e['address'] as String) ||
            e['name'] is! String ||
            (e['name'] as String).isEmpty ||
            (e['name'] as String).length > 64 ||
            e['backedUp'] is! bool ||
            e['key'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(e['key'] as String)) {
          throw const FormatException();
        }
        final key = evm.EthPrivateKey.fromHex(e['key'] as String);
        if (key.address.eip55With0x.toLowerCase() != (e['address'] as String).toLowerCase()) {
          throw const FormatException();
        }
        key.privateKey.fillRange(0, key.privateKey.length, 0);
        return Map<String, Object?>.of(e);
      }).toList();
      if (entries.length > 100 ||
          entries.map((e) => e['address']).toSet().length != entries.length) {
        throw const FormatException();
      }
      return entries;
    } catch (_) {
      throw const AccountReadFailure('subaccountSecureStorageFailed');
    }
  }

  GeneratedSubaccount _metadata(Map<String, Object?> e) => GeneratedSubaccount(
    owner: e['owner']! as String,
    address: e['address']! as String,
    name: e['name']! as String,
    backedUp: e['backedUp']! as bool,
  );

  Future<void> _save(List<Map<String, Object?>> entries) async {
    try {
      await _write(storageKey, jsonEncode({'version': 1, 'wallets': entries}));
    } catch (_) {
      throw const AccountReadFailure('subaccountSecureStorageFailed');
    }
  }

  @override
  Future<List<GeneratedSubaccount>> list() async =>
      List.unmodifiable((await _entries()).map(_metadata));

  @override
  Future<GeneratedSubaccount> generate({required String owner, required String name}) =>
      _serialized(() async {
        if (!validOperationAddress(owner) ||
            name.trim() != name ||
            name.isEmpty ||
            name.length > 64 ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
          throw const AccountReadFailure('subaccountInputInvalid');
        }
        final entries = await _entries();
        if (entries.length >= 100) throw const AccountReadFailure('subaccountSecureStorageFull');
        final key = evm.EthPrivateKey.createRandom(Random.secure());
        try {
          final entry = <String, Object?>{
            'owner': owner,
            'address': key.address.eip55With0x,
            'name': name,
            'key': key.privateKeyInt.toRadixString(16).padLeft(64, '0'),
            'backedUp': false,
          };
          await _save([...entries, entry]);
          return _metadata(entry);
        } finally {
          key.privateKey.fillRange(0, key.privateKey.length, 0);
        }
      });

  Future<String> _key(String address) async {
    final entry = (await _entries())
        .where((e) => (e['address']! as String).toLowerCase() == address.toLowerCase())
        .singleOrNull;
    if (entry == null) throw const AccountReadFailure('subaccountLocalKeyMissing');
    return entry['key']! as String;
  }

  @override
  Future<String> reveal(String address) => _key(address);
  @override
  Future<String> sign(String address, Map<String, Object?> typedData) async {
    final key = evm.hexToBytes(await _key(address));
    try {
      final sig = evm.sign(asterTypedDataDigest(typedData), key);
      return '0x${sig.r.toRadixString(16).padLeft(64, '0')}'
          '${sig.s.toRadixString(16).padLeft(64, '0')}${sig.v.toRadixString(16).padLeft(2, '0')}';
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<String> _personal(String address, String message) async {
    final key = evm.EthPrivateKey.fromHex(await _key(address));
    try {
      return evm.bytesToHex(
        key.signPersonalMessageToUint8List(utf8.encode(message)),
        include0x: true,
      );
    } finally {
      key.privateKey.fillRange(0, key.privateKey.length, 0);
    }
  }

  @override
  Future<void> acknowledgeBackup(String address) => _serialized(() async {
    final entries = await _entries();
    final index = entries.indexWhere((e) => e['address'] == address);
    if (index < 0) throw const AccountReadFailure('subaccountLocalKeyMissing');
    entries[index] = {...entries[index], 'backedUp': true};
    await _save(entries);
  });

  @override
  WalletConnection connection(GeneratedSubaccount account) => _DeviceWalletConnection(
    account.address,
    (data) => sign(account.address, data),
    (message) => _personal(account.address, message),
  );
}

class _DeviceWalletConnection implements WalletConnection {
  _DeviceWalletConnection(this.address, this._typed, this._personal);
  @override
  final String address;
  final Future<String> Function(Map<String, Object?>) _typed;
  final Future<String> Function(String) _personal;
  bool _released = false;
  @override
  String get chainId => '56';
  @override
  String get walletName => 'Vanta';
  @override
  bool get isCurrent => !_released;
  @override
  Stream<void> get invalidations => const Stream.empty();
  void _current() {
    if (!isCurrent) throw const AuthFailure('authWalletChanged');
  }

  @override
  Future<String> signPersonalMessage(String message) async {
    _current();
    final signature = await _personal(message);
    _current();
    return signature;
  }

  @override
  Future<String> signTypedData(Map<String, Object?> data) async {
    _current();
    final signature = await _typed(data);
    _current();
    return signature;
  }

  @override
  Future<void> release() async {
    _released = true;
  }

  @override
  Future<void> disconnect() => release();
  @override
  Future<WalletTransactionResult> sendTransaction({
    required EvmWalletTransaction transaction,
    required bool Function() isCurrent,
  }) async => throw const WalletTransactionNotSent('subaccountNativeTransactionUnavailable');
}
