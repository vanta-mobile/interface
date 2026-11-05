import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../../../core/exact_json.dart';
import '../domain/asset_rebalance.dart';

Map<String, dynamic> exactRebalanceMap(Object? v, Set<String> keys) {
  if (v is! Map<String, dynamic> || v.length != keys.length || !v.keys.every(keys.contains)) {
    throw const FormatException();
  }
  return v;
}

String _text(Object? v) => v is String ? v : throw const FormatException();
Decimal rebalanceMoney(Object? v) {
  final s = _text(v);
  if (s.length > 160 || !RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(s)) throw const FormatException();
  return Decimal.parse(s);
}

int _integer(Object? v) {
  final s = _text(v);
  if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(s)) throw const FormatException();
  return int.tryParse(s) ?? (throw const FormatException());
}

Map<String, Object?> encodeRebalanceReply(RebalanceReply r) => {
  'asset': r.asset,
  'balance': r.balance?.toString(),
  'accountId': r.accountId,
  'time': r.updateTime?.millisecondsSinceEpoch.toString(),
};
RebalanceReply decodeRebalanceReply(Object? v) {
  final m = exactRebalanceMap(v, {'asset', 'balance', 'accountId', 'time'});
  if (m.values.every((v) => v == null)) return const RebalanceReply.noExchange();
  return RebalanceReply(
    asset: _text(m['asset']),
    balance: rebalanceMoney(m['balance']),
    accountId: _text(m['accountId']),
    updateTime: DateTime.fromMillisecondsSinceEpoch(_integer(m['time']), isUtc: true),
  );
}

Map<String, Object?> encodeRebalanceRecord(RebalanceRecord r) => {
  'address': r.address,
  'nonce': '${r.nonce}',
  'preparedAt': '${r.preparedAt.millisecondsSinceEpoch}',
  'usdt': '${r.previousUsdt}',
  'reply': r.reply == null ? null : encodeRebalanceReply(r.reply!),
};
String encodeRebalanceJournal(Iterable<RebalanceRecord> records) =>
    jsonEncode({'version': '1', 'records': records.map(encodeRebalanceRecord).toList()});
List<RebalanceRecord> decodeRebalanceJournal(String source) {
  if (source.length > 131072) throw const FormatException();
  final m = exactRebalanceMap(decodeFundingJson(source), {'version', 'records'});
  if (m['version'] != '1' || m['records'] is! List || (m['records'] as List).length > 100) {
    throw const FormatException();
  }
  final addresses = <String>{}, records = <RebalanceRecord>[];
  for (final v in m['records'] as List) {
    final r = exactRebalanceMap(v, {'address', 'nonce', 'preparedAt', 'usdt', 'reply'});
    final record = RebalanceRecord(
      address: _text(r['address']),
      nonce: _integer(r['nonce']),
      preparedAt: DateTime.fromMillisecondsSinceEpoch(_integer(r['preparedAt']), isUtc: true),
      previousUsdt: rebalanceMoney(r['usdt']),
      reply: r['reply'] == null ? null : decodeRebalanceReply(r['reply']),
    );
    if (!addresses.add(record.address.toLowerCase())) throw const FormatException();
    records.add(record);
  }
  return List.unmodifiable(records);
}
