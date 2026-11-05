import 'dart:async';

import 'package:vanta/features/funding/data/transfer_history_mapper.dart';
import 'package:vanta/features/funding/domain/transfer_history.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';

Map<String, dynamic> transferPayload({
  String id = '1234567',
  String market = 'perp',
  String type = 'DEPOSIT',
  String status = 'PROCESSING',
  String? hash,
}) => {
  'id': id,
  'accountType': market,
  'type': type,
  'state': status,
  'asset': 'USDT',
  'amount': '0.000000000000000001',
  'time': 1742198400000,
  'chainId': 56,
  'txHash': hash,
};
TransferRecord transferRecord({
  String id = '1234567',
  String market = 'perp',
  String type = 'DEPOSIT',
  String status = 'PROCESSING',
  String? hash,
}) => mapTransferRecord(
  transferPayload(id: id, market: market, type: type, status: status, hash: hash),
);

class TestTransferHistoryRepository implements TransferHistoryRepository {
  int calls = 0;
  List<TransferRecord> records = [transferRecord()];
  Completer<void>? gate;
  AccountReadFailure? failure;
  String? returnedAddress;
  DateTime now = DateTime.utc(2026, 11, 3);
  @override
  Future<TransferHistory> read({
    required String address,
    required bool Function() isCurrent,
    required void Function(AccountReadStep) onStep,
  }) async {
    calls++;
    onStep(AccountReadStep.signing);
    await gate?.future;
    if (failure case final failure?) throw failure;
    // Deliberately return late data: application must guard even weak repositories.
    onStep(AccountReadStep.loading);
    return TransferHistory(address: returnedAddress ?? address, receivedAt: now, records: records);
  }
}
