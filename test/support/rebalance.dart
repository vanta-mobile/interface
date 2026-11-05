import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:vanta/features/portfolio/data/aster_account_mapper.dart';
import 'package:vanta/features/portfolio/data/rebalance_journal.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/asset_rebalance.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import 'aster_account.dart';

RebalanceContext rebalanceContext({
  DateTime? now,
  String usdt = '-1.000000000000000001',
  bool missingUsdt = false,
  FuturesAssetMode mode = FuturesAssetMode.multi,
  String address = accountAddress,
}) {
  final time = now ?? DateTime.now().toUtc();
  final payload = accountPayload();
  payload['assets'] = [
    if (!missingUsdt)
      {'asset': 'USDT', 'walletBalance': usdt, 'availableBalance': '0', 'marginAvailable': true},
    {'asset': 'BNB', 'walletBalance': '2.500000000000000001', 'marginAvailable': true},
  ];
  return RebalanceContext(
    mode: mode,
    account: mapAsterAccount(payload, address: address, receivedAt: time),
    receivedAt: time,
  );
}

RebalanceRecord rebalanceRecord({DateTime? now, RebalanceReply? reply}) => RebalanceRecord(
  address: accountAddress,
  nonce: 1793740800000000,
  preparedAt: now ?? DateTime.now().toUtc(),
  previousUsdt: Decimal.parse('-1.000000000000000001'),
  reply: reply,
);
RebalanceReply rebalanceReply({DateTime? now}) => RebalanceReply(
  asset: 'USDT',
  balance: Decimal.parse('0.000000000000000001'),
  accountId: '9007199254740993',
  updateTime: now ?? DateTime.now().toUtc(),
);

class TestRebalanceRepository implements RebalanceRepository {
  DateTime Function() now = () => DateTime.now().toUtc();
  int reads = 0, submits = 0, posts = 0;
  Completer<void>? readGate, signGate, postGate;
  Object? readFailure, submitFailure;
  RebalanceContext? context;
  RebalanceReply? reply;
  bool Function()? current;
  Future<void> Function()? beforeDispatch;
  @override
  Future<RebalanceContext> read({
    required String address,
    required bool Function() isCurrent,
  }) async {
    reads++;
    current = isCurrent;
    await readGate?.future;
    if (readFailure case final e?) throw e;
    return context ?? rebalanceContext(now: now(), address: address);
  }

  @override
  Future<RebalanceReply> submit({
    required RebalanceContext context,
    required bool Function() canSubmit,
    required Future<void> Function(int nonce) beforeSend,
    required void Function() onDispatch,
  }) async {
    submits++;
    current = canSubmit;
    await signGate?.future;
    if (!canSubmit()) throw const AccountReadFailure('rebalanceChanged');
    await beforeSend(1793740800000000);
    await beforeDispatch?.call();
    if (!canSubmit()) throw const AccountReadFailure('rebalanceChanged');
    onDispatch();
    posts++;
    await postGate?.future;
    if (submitFailure case final e?) throw e;
    return reply ?? rebalanceReply(now: now());
  }
}

class GatedRebalanceJournal extends MemoryRebalanceJournal {
  Completer<void>? gate;
  Object? prepareFailure, completeFailure;
  @override
  Future<void> prepare(RebalanceRecord record) async {
    await gate?.future;
    if (prepareFailure case final e?) throw e;
    await super.prepare(record);
  }

  @override
  Future<void> complete(String key) async {
    if (completeFailure case final e?) throw e;
    await super.complete(key);
  }
}
