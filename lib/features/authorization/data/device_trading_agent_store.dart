import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart' as evm;

import '../../../core/data/aster_signature_verifier.dart';
import '../../portfolio/domain/account_request_signing.dart';
import '../../portfolio/domain/account_snapshot.dart';
import '../../portfolio/domain/aster_signature.dart';
import '../domain/trading_agent.dart';

typedef AgentSecureRead = Future<String?> Function(String key);
typedef AgentSecureWrite = Future<void> Function(String key, String value);

/// Device-only encrypted records, partitioned by login identity and owner.
/// The dispatch marker and key are durable before sending an authorization.
class DeviceTradingAgentStore implements TradingAgentStore {
  DeviceTradingAgentStore({
    AgentSecureRead? read,
    AgentSecureWrite? write,
    DateTime Function()? now,
  }) : _read = read ?? ((key) => _storage.read(key: key)),
       _write = write ?? ((key, value) => _storage.write(key: key, value: value)),
       _now = now ?? DateTime.now;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'vanta_trading_agents_v1', resetOnError: false),
    iOptions: IOSOptions(
      accountName: 'vanta_trading_agents_v1',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
    ),
  );
  final AgentSecureRead _read;
  final AgentSecureWrite _write;
  final DateTime Function() _now;
  Future<void> _queue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() work) {
    final task = _queue.then((_) => work());
    _queue = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  String _storageKey(String identityId, String owner) {
    if (identityId.isEmpty || identityId.length > 1024 || !_address(owner)) {
      throw const AccountReadFailure('accountDataInvalid');
    }
    final digest = evm.keccak256(utf8.encode(jsonEncode([identityId, owner.toLowerCase()])));
    return 'agent-${evm.bytesToHex(digest)}';
  }

  bool _address(String value) => RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value);

  Future<Map<String, dynamic>?> _entry(String identityId, String owner) async {
    final storageKey = _storageKey(identityId, owner);
    try {
      final raw = await _read(storageKey);
      if (raw == null) return null;
      if (raw.length > 8192) throw const FormatException();
      final e = jsonDecode(raw);
      if (e is! Map<String, dynamic> ||
          e.length != 7 ||
          e['version'] != 1 ||
          e['identityId'] != identityId ||
          e['owner'] != owner.toLowerCase() ||
          e['address'] is! String ||
          !_address(e['address'] as String) ||
          e['key'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(e['key'] as String) ||
          e['expiresAt'] is! int ||
          (e['expiresAt'] as int) <= 0 ||
          !TradingAgentStatus.values.any((s) => s.name == e['status'])) {
        throw const FormatException();
      }
      final key = evm.EthPrivateKey.fromHex(e['key'] as String);
      try {
        if (key.address.eip55With0x.toLowerCase() != e['address'] || e['address'] == e['owner']) {
          throw const FormatException();
        }
      } finally {
        key.privateKey.fillRange(0, key.privateKey.length, 0);
      }
      DateTime.fromMillisecondsSinceEpoch(e['expiresAt'] as int, isUtc: true);
      return e;
    } catch (_) {
      throw const AccountReadFailure('authorizationSecureStorageFailed');
    }
  }

  TradingAgent _metadata(Map<String, dynamic> e) => TradingAgent(
    identityId: e['identityId'] as String,
    owner: e['owner'] as String,
    address: e['address'] as String,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(e['expiresAt'] as int, isUtc: true),
    status: TradingAgentStatus.values.byName(e['status'] as String),
  );

  Future<void> _save(Map<String, dynamic> entry) async {
    try {
      final key = _storageKey(entry['identityId'] as String, entry['owner'] as String);
      final value = jsonEncode(entry);
      await _write(key, value);
      if (await _read(key) != value) throw const FormatException();
    } catch (_) {
      throw const AccountReadFailure('authorizationSecureStorageFailed');
    }
  }

  @override
  Future<TradingAgent?> load(String identityId, String owner) => _serialized(() async {
    final entry = await _entry(identityId, owner);
    return entry == null ? null : _metadata(entry);
  });

  @override
  Future<TradingAgent> prepare(String identityId, String owner, DateTime expiresAt) =>
      _serialized(() async {
        _storageKey(identityId, owner);
        if (!expiresAt.isAfter(_now()) || expiresAt.difference(_now()) > const Duration(days: 30)) {
          throw const AccountReadFailure('accountSignatureExpired');
        }
        final previous = await _entry(identityId, owner);
        if (previous != null && _now().isBefore(_metadata(previous).expiresAt)) {
          final agent = _metadata(previous);
          if (agent.status == TradingAgentStatus.unknown) {
            throw const AccountReadFailure('authorizationUnknown');
          }
          if (agent.status == TradingAgentStatus.active) return agent;
        }
        final key = evm.EthPrivateKey.createRandom(Random.secure());
        try {
          final entry = <String, dynamic>{
            'version': 1,
            'identityId': identityId,
            'owner': owner.toLowerCase(),
            'address': key.address.eip55With0x.toLowerCase(),
            'key': key.privateKeyInt.toRadixString(16).padLeft(64, '0'),
            'expiresAt': expiresAt.millisecondsSinceEpoch,
            'status': TradingAgentStatus.prepared.name,
          };
          await _save(entry);
          return _metadata(entry);
        } finally {
          key.privateKey.fillRange(0, key.privateKey.length, 0);
        }
      });

  @override
  Future<void> setStatus(TradingAgent agent, TradingAgentStatus status) => _serialized(() async {
    final e = await _entry(agent.identityId, agent.owner);
    if (e == null ||
        e['address'] != agent.address ||
        e['expiresAt'] != agent.expiresAt.millisecondsSinceEpoch) {
      throw const AccountReadFailure('authWalletChanged');
    }
    final previous = _metadata(e).status;
    if (!(previous == TradingAgentStatus.prepared && status == TradingAgentStatus.unknown ||
        previous == TradingAgentStatus.unknown && status == TradingAgentStatus.active ||
        previous == TradingAgentStatus.active && status == TradingAgentStatus.rejected)) {
      throw const AccountReadFailure('authorizationUnknown');
    }
    await _save({...e, 'status': status.name});
  });

  @override
  Future<AccountRequestIdentity> resolve(
    String identityId,
    String owner, {
    bool allowUnknown = false,
  }) async {
    final agent = await load(identityId, owner);
    void valid(TradingAgent? candidate) {
      if (candidate == null ||
          !_now().isBefore(candidate.expiresAt) ||
          !(candidate.status == TradingAgentStatus.active ||
              allowUnknown && candidate.status == TradingAgentStatus.unknown)) {
        throw const AccountReadFailure('authorizationRequired');
      }
    }

    valid(agent);
    return AccountRequestIdentity(
      address: agent!.address,
      sign: ({required expectedAddress, required typedData}) => _serialized(() async {
        final entry = await _entry(identityId, owner);
        final current = entry == null ? null : _metadata(entry);
        valid(current);
        if (current!.address != agent.address || expectedAddress.toLowerCase() != agent.address) {
          throw const AccountReadFailure('authWalletChanged');
        }
        final message = typedData['message'];
        final query = message is Map ? message['msg'] : null;
        if (query is! String || jsonEncode(typedData) != jsonEncode(asterReadTypedData(query))) {
          throw const AccountReadFailure('authWalletSignature');
        }
        final parameters = Uri.splitQueryString(query);
        if (parameters['user']?.toLowerCase() != agent.owner ||
            parameters['signer']?.toLowerCase() != agent.address) {
          throw const AccountReadFailure('authWalletChanged');
        }
        final key = evm.hexToBytes(entry!['key'] as String);
        try {
          final sig = evm.sign(asterTypedDataDigest(typedData), key);
          return '0x${sig.r.toRadixString(16).padLeft(64, '0')}'
              '${sig.s.toRadixString(16).padLeft(64, '0')}${sig.v.toRadixString(16).padLeft(2, '0')}';
        } finally {
          key.fillRange(0, key.length, 0);
        }
      }),
    );
  }
}
