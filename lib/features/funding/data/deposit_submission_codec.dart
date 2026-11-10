import 'package:decimal/decimal.dart';

import 'dart:convert';

import '../../auth/domain/wallet_transaction.dart';
import '../domain/deposit_submission.dart';
import '../domain/deposit_transaction.dart';
import '../domain/deposit_wallet.dart';
import '../domain/funding_catalog.dart';
import '../domain/transfer_history.dart';
import 'funding_json.dart';

Map<String, Object?> encodeSubmissionRecord(DepositSubmissionRecord r) => {
  'native': r.query.asset.isNative,
  'verifiedMinimum': r.query.verifiedMinimumDeposit?.toString(),
  'market': r.query.market.name,
  'asset': r.query.asset.asset,
  'chain': r.query.asset.chainId,
  'token': r.query.asset.tokenAddress,
  'decimals': r.query.asset.decimals,
  'kind': r.kind.name,
  'amount': '${r.amountUnits}',
  'from': r.transaction.from,
  'to': r.transaction.to,
  'data': r.transaction.data,
  'value': '${r.transaction.value}',
  'gas': '${r.transaction.gasLimit}',
  'gasPrice': '${r.transaction.gasPrice}',
  'nonce': '${r.transaction.nonce}',
  'preparedAt': '${r.preparedAt.millisecondsSinceEpoch}',
  'baseBlock': '${r.baseBlock}',
  'baseHash': r.baseBlockHash,
  'hash': r.hash,
};

Map<String, dynamic> _map(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      value.keys.any((key) => !keys.contains(key))) {
    throw const FormatException();
  }
  return value;
}

String _text(Object? v, {int limit = 160}) {
  if (v is! String || v.length > limit) throw const FormatException();
  return v;
}

Decimal? _minimum(Object? value) {
  if (value == null) return null;
  final text = _text(value);
  if (!RegExp(r'^(0|[1-9]\d*)(?:\.\d+)?$').hasMatch(text)) throw const FormatException();
  return Decimal.parse(text);
}

BigInt _uint(Object? v) {
  final text = _text(v);
  if (!RegExp(r'^(0|[1-9]\d{0,77})$').hasMatch(text)) throw const FormatException();
  final n = BigInt.parse(text);
  if (n >= BigInt.one << 256) throw const FormatException();
  return n;
}

int _int(Object? v) =>
    v is FundingJsonNumber && v.integer != null ? v.integer! : (throw const FormatException());

DepositSubmissionRecord decodeSubmissionRecord(Object? value) {
  final m = _map(value, {
    'native',
    'verifiedMinimum',
    'market',
    'asset',
    'chain',
    'token',
    'decimals',
    'kind',
    'amount',
    'from',
    'to',
    'data',
    'value',
    'gas',
    'gasPrice',
    'nonce',
    'preparedAt',
    'baseBlock',
    'baseHash',
    'hash',
  });
  final market = TransferMarket.values.where((v) => v.name == m['market']).singleOrNull;
  final kind = DepositTransactionKind.values.where((v) => v.name == m['kind']).singleOrNull;
  final time = _uint(m['preparedAt']);
  if (market == null || kind == null || time > BigInt.from(10413792000000)) {
    throw const FormatException();
  }
  return DepositSubmissionRecord(
    query: DepositWalletQuery(
      market: market,
      verifiedMinimumDeposit: _minimum(m['verifiedMinimum']),
      asset: FundingAsset(
        asset: _text(m['asset']),
        displayName: _text(m['asset']),
        chainId: _int(m['chain']),
        tokenAddress: _text(m['token']),
        decimals: _int(m['decimals']),
        isNative: m['native'] is bool ? m['native'] as bool : (throw const FormatException()),
        routeType: 'normal',
      ),
    ),
    kind: kind,
    amountUnits: _uint(m['amount']),
    transaction: EvmWalletTransaction(
      chainId: _int(m['chain']),
      from: _text(m['from']),
      to: _text(m['to']),
      data: _text(m['data'], limit: 512),
      value: _uint(m['value']),
      gasLimit: _uint(m['gas']),
      gasPrice: _uint(m['gasPrice']),
      nonce: _uint(m['nonce']),
    ),
    preparedAt: DateTime.fromMillisecondsSinceEpoch(time.toInt(), isUtc: true),
    baseBlock: _uint(m['baseBlock']),
    baseBlockHash: _text(m['baseHash']),
    hash: m['hash'] == null ? null : _text(m['hash']),
  );
}

String encodeSubmissionJournal(Iterable<DepositSubmissionRecord> records) =>
    jsonEncode({'version': 1, 'records': records.map(encodeSubmissionRecord).toList()});

List<DepositSubmissionRecord> decodeSubmissionJournal(String source) {
  final map = _map(decodeFundingJson(source), {'version', 'records'}), raw = map['records'];
  if (_int(map['version']) != 1 || raw is! List || raw.length > 100) throw const FormatException();
  final records = raw.map(decodeSubmissionRecord).toList();
  // Several deposits of one wallet may await credit; each nonce is recorded once.
  if (records.map((r) => r.key).toSet().length != records.length) {
    throw const FormatException();
  }
  return List.unmodifiable(records);
}
