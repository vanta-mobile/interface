import 'package:decimal/decimal.dart';

import '../domain/transfer_history.dart';

List<TransferRecord> mapTransferHistory(Object? payload) {
  if (payload is! List || payload.length > 5000) throw const FormatException();
  final records = <TransferRecord>[], seen = <String>{};
  for (final raw in payload) {
    final record = mapTransferRecord(raw);
    if (!seen.add(record.key)) throw const FormatException();
    records.add(record);
  }
  records.sort((a, b) {
    final time = b.recordTime.compareTo(a.recordTime);
    return time != 0 ? time : a.key.compareTo(b.key);
  });
  return List.unmodifiable(records);
}

TransferRecord mapTransferRecord(Object? value) {
  if (value is! Map<String, dynamic>) throw const FormatException();
  final id = value['id'];
  final asset = value['asset'], amount = value['amount'];
  final time = value['time'], chain = value['chainId'], hash = value['txHash'];
  if (id is! String ||
      !RegExp(r'^[a-zA-Z0-9_.:-]{1,128}$').hasMatch(id) ||
      asset is! String ||
      !RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(asset) ||
      amount is! String ||
      amount.length > 160 ||
      !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(amount) ||
      time is! int ||
      time <= 0 ||
      time > 253402300799999 ||
      chain is! int ||
      chain <= 0 ||
      chain > 9007199254740991 ||
      hash != null &&
          hash != '' &&
          (hash is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,256}$').hasMatch(hash))) {
    throw const FormatException();
  }
  final quantity = Decimal.parse(amount);
  if (quantity <= Decimal.zero) throw const FormatException();
  return TransferRecord(
    id: id,
    market: switch (value['accountType']) {
      'spot' => TransferMarket.spot,
      'perp' => TransferMarket.perp,
      _ => throw const FormatException(),
    },
    type: switch (value['type']) {
      'DEPOSIT' => TransferType.deposit,
      'WITHDRAW' => TransferType.withdraw,
      _ => throw const FormatException(),
    },
    status: switch (value['state']) {
      'PROCESSING' => TransferStatus.processing,
      'SUCCESS' => TransferStatus.success,
      'FAILED' => TransferStatus.failed,
      _ => throw const FormatException(),
    },
    asset: asset,
    amount: quantity,
    recordTime: DateTime.fromMillisecondsSinceEpoch(time, isUtc: true),
    chainId: chain,
    txHash: hash == null || hash == '' ? null : hash as String,
  );
}

Map<String, dynamic> transferRecordPayload(TransferRecord record) => {
  'id': record.id,
  'accountType': record.market.name,
  'type': record.type.name.toUpperCase(),
  'state': record.status.name.toUpperCase(),
  'asset': record.asset,
  'amount': record.amount.toString(),
  'time': record.recordTime.millisecondsSinceEpoch,
  'chainId': record.chainId,
  'txHash': record.txHash,
};
