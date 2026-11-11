import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../../portfolio/domain/account_snapshot.dart';

enum TransferMarket { spot, perp }

enum TransferType { deposit, withdraw }

enum TransferStatus { processing, success, failed }

/// Exchange record time is not a completion time. Missing hashes stay unknown.
class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.market,
    required this.type,
    required this.status,
    required this.asset,
    required this.amount,
    required this.recordTime,
    required this.chainId,
    this.txHash,
  });
  final String id, asset;
  final TransferMarket market;
  final TransferType type;
  final TransferStatus status;
  final Decimal amount;
  final DateTime recordTime;
  final int chainId;
  final String? txHash;
  String get key => jsonEncode([market.name, type.name, id]);
}

class TransferHistory implements WalletAccountSnapshot {
  TransferHistory({
    required this.address,
    required this.receivedAt,
    required Iterable<TransferRecord> records,
  }) : records = List.unmodifiable(records);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final List<TransferRecord> records;
}

typedef TransferHistoryRepository = WalletAccountRepository<TransferHistory>;
