import 'dart:convert';

import '../exact_json.dart';

enum WalletOperationKind {
  createSubaccount,
  freezeSubaccount,
  unfreezeSubaccount,
  subaccountTransfer,
  withdrawal,
  isolatedMargin,
}

/// Durable public unsigned terms. A record is never an executable retry queue.
class WalletOperationRecord {
  WalletOperationRecord({
    required this.kind,
    required this.address,
    required this.nonce,
    required this.preparedAt,
    required Map<String, String> terms,
    this.acknowledged = false,
    this.reference,
  }) : terms = Map.unmodifiable(terms) {
    final keys = switch (kind) {
      WalletOperationKind.createSubaccount => {'child', 'name'},
      WalletOperationKind.freezeSubaccount || WalletOperationKind.unfreezeSubaccount => {'child'},
      WalletOperationKind.subaccountTransfer => {'from', 'to', 'asset', 'amount', 'direction'},
      WalletOperationKind.withdrawal => {'chain', 'market', 'asset', 'amount', 'fee', 'receiver'},
      WalletOperationKind.isolatedMargin => {
        'symbol',
        'side',
        'asset',
        'amount',
        'type',
        'clientTranId',
      },
    };
    if (!validOperationAddress(address) ||
        nonce <= 0 ||
        preparedAt.millisecondsSinceEpoch <= 0 ||
        preparedAt.millisecondsSinceEpoch > 10413792000000 ||
        terms.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(terms.keys.toSet()).isNotEmpty ||
        terms.values.any((v) => v.isEmpty || v.length > 160) ||
        reference != null &&
            (!acknowledged || !RegExp(r'^[a-zA-Z0-9_.:-]{1,128}$').hasMatch(reference!))) {
      throw const FormatException();
    }
    for (final key in ['child', 'from', 'to', 'receiver']) {
      if (terms[key] != null && !validOperationAddress(terms[key]!)) throw const FormatException();
    }
    for (final key in ['amount', 'fee']) {
      final value = terms[key];
      if (value != null && !RegExp(r'^(0|[1-9]\d*)(?:\.\d+)?$').hasMatch(value)) {
        throw const FormatException();
      }
    }
    if (terms['amount'] != null &&
        BigInt.parse(terms['amount']!.replaceAll('.', '')) <= BigInt.zero) {
      throw const FormatException();
    }
    if (terms['asset'] != null && !RegExp(r'^[A-Za-z0-9_.-]{1,40}$').hasMatch(terms['asset']!)) {
      throw const FormatException();
    }
    if (terms['direction'] != null &&
        !{
          'FUTURE_FUTURE',
          'FUTURE_SPOT',
          'SPOT_FUTURE',
          'SPOT_SPOT',
        }.contains(terms['direction'])) {
      throw const FormatException();
    }
    if (kind == WalletOperationKind.isolatedMargin &&
        (!RegExp(r'^[A-Za-z0-9_.-]{1,50}$').hasMatch(terms['symbol']!) ||
            !{'BOTH', 'LONG', 'SHORT'}.contains(terms['side']) ||
            !{'1', '2'}.contains(terms['type']) ||
            !RegExp(r'^vm_[a-f0-9]{32}$').hasMatch(terms['clientTranId']!) ||
            !RegExp(r'^(0|[1-9]\d*)(?:\.\d{1,8})?$').hasMatch(terms['amount']!))) {
      throw const FormatException();
    }
    if (kind == WalletOperationKind.withdrawal &&
        (!{'1', '56', '42161'}.contains(terms['chain']) ||
            !{'spot', 'perp'}.contains(terms['market']) ||
            terms['receiver']!.toLowerCase() != address.toLowerCase())) {
      throw const FormatException();
    }
  }
  final WalletOperationKind kind;
  final String address;
  final int nonce;
  final DateTime preparedAt;
  final Map<String, String> terms;
  final bool acknowledged;
  final String? reference;
  String get key => '${address.toLowerCase()}:$nonce:${kind.name}';
  WalletOperationRecord reported([String? id]) => WalletOperationRecord(
    kind: kind,
    address: address,
    nonce: nonce,
    preparedAt: preparedAt,
    terms: terms,
    acknowledged: true,
    reference: id,
  );
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'address': address,
    'nonce': '$nonce',
    'time': '${preparedAt.millisecondsSinceEpoch}',
    'terms': terms,
    'acknowledged': acknowledged,
    'reference': reference,
  };
  static WalletOperationRecord fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference({
          'kind',
          'address',
          'nonce',
          'time',
          'terms',
          'acknowledged',
          'reference',
        }).isNotEmpty ||
        value.length != 7) {
      throw const FormatException();
    }
    final kind = WalletOperationKind.values.where((k) => k.name == value['kind']).singleOrNull;
    final n = value['nonce'], time = value['time'], terms = value['terms'];
    if (kind == null ||
        n is! String ||
        time is! String ||
        !RegExp(r'^[1-9]\d{0,18}$').hasMatch(n) ||
        !RegExp(r'^[1-9]\d{0,13}$').hasMatch(time) ||
        value['address'] is! String ||
        value['acknowledged'] is! bool ||
        terms is! Map<String, dynamic> ||
        terms.values.any((v) => v is! String) ||
        value['reference'] != null && value['reference'] is! String) {
      throw const FormatException();
    }
    return WalletOperationRecord(
      kind: kind,
      address: value['address'] as String,
      nonce: int.parse(n),
      preparedAt: DateTime.fromMillisecondsSinceEpoch(int.parse(time), isUtc: true),
      terms: terms.cast<String, String>(),
      acknowledged: value['acknowledged'] as bool,
      reference: value['reference'] as String?,
    );
  }
}

bool validOperationAddress(String value) =>
    RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value) &&
    BigInt.parse(value.substring(2), radix: 16) != BigInt.zero;
String encodeWalletOperations(Iterable<WalletOperationRecord> records) =>
    jsonEncode({'version': '1', 'records': records.map((r) => r.toJson()).toList()});
List<WalletOperationRecord> decodeWalletOperations(String source) {
  if (source.length > 262144) throw const FormatException();
  final value = decodeFundingJson(source);
  if (value is! Map<String, dynamic> ||
      value.length != 2 ||
      value['version'] != '1' ||
      value['records'] is! List ||
      (value['records'] as List).length > 100) {
    throw const FormatException();
  }
  final records = (value['records'] as List).map(WalletOperationRecord.fromJson).toList();
  if (records.map((r) => r.key).toSet().length != records.length) throw const FormatException();
  final pending = records
      .where((r) => !r.acknowledged)
      .map((r) => r.address.toLowerCase())
      .toList();
  if (pending.toSet().length != pending.length) throw const FormatException();
  return List.unmodifiable(records);
}

class WalletOperationStorage {
  WalletOperationStorage({
    Iterable<WalletOperationRecord> records = const [],
    this.ready = true,
    this.failed = false,
  }) : records = List.unmodifiable(records);
  final List<WalletOperationRecord> records;
  final bool ready, failed;
}

abstract interface class WalletOperationJournal {
  WalletOperationStorage get snapshot;
  Stream<WalletOperationStorage> get changes;
  Future<void> reload();
  Future<void> prepare(WalletOperationRecord record);
  Future<void> report(String key, [String? reference]);
  Future<void> removeNotSent(String key);
  Future<void> close();
}
