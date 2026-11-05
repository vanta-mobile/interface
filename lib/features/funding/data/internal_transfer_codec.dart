import 'dart:convert';

import '../../../core/exact_json.dart';
import '../domain/internal_transfer.dart';

Map<String, dynamic> _map(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !value.keys.every(keys.contains)) {
    throw const FormatException();
  }
  return value;
}

String _text(Object? v) => v is String ? v : throw const FormatException();
int _integer(Object? v) {
  final s = _text(v);
  if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(s)) throw const FormatException();
  return int.tryParse(s) ?? (throw const FormatException());
}

Map<String, Object?> encodeInternalTransferRecord(InternalTransferRecord r) => {
  'address': r.address,
  'asset': r.asset,
  'amount': r.amount,
  'direction': r.direction.wire,
  'clientId': r.clientId,
  'nonce': '${r.nonce}',
  'preparedAt': '${r.preparedAt.millisecondsSinceEpoch}',
  'reply': r.reply?.transactionId,
};
String encodeInternalTransferJournal(Iterable<InternalTransferRecord> records) =>
    jsonEncode({'version': '1', 'records': records.map(encodeInternalTransferRecord).toList()});
List<InternalTransferRecord> decodeInternalTransferJournal(String source) {
  if (source.length > 131072) throw const FormatException();
  final m = _map(decodeFundingJson(source), {'version', 'records'}), rows = m['records'];
  if (m['version'] != '1' || rows is! List || rows.length > 100) throw const FormatException();
  final addresses = <String>{};
  return List.unmodifiable(
    rows.map((v) {
      final r = _map(v, {
        'address',
        'asset',
        'amount',
        'direction',
        'clientId',
        'nonce',
        'preparedAt',
        'reply',
      });
      final record = InternalTransferRecord(
        address: _text(r['address']),
        asset: _text(r['asset']),
        amount: _text(r['amount']),
        direction:
            InternalTransferDirection.values.where((d) => d.wire == r['direction']).singleOrNull ??
            (throw const FormatException()),
        clientId: _text(r['clientId']),
        nonce: _integer(r['nonce']),
        preparedAt: DateTime.fromMillisecondsSinceEpoch(_integer(r['preparedAt']), isUtc: true),
        reply: r['reply'] == null ? null : InternalTransferReply(_text(r['reply'])),
      );
      if (!addresses.add(record.address.toLowerCase())) throw const FormatException();
      return record;
    }),
  );
}
