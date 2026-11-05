import 'dart:async';

import 'package:vanta/features/funding/data/internal_transfer_journal.dart';
import 'package:vanta/features/funding/data/internal_transfer_mapper.dart';
import 'package:vanta/features/funding/domain/internal_transfer.dart';
import 'package:vanta/features/portfolio/domain/account_snapshot.dart';
import 'package:vanta/features/portfolio/domain/futures_asset_mode.dart';

import 'aster_account.dart';
import 'aster_spot_account.dart';

Object publicRows(List<Object?> rows) => {'code': '000000', 'success': true, 'data': rows};
Map<String, Object?> transferSpotPayload() => {
  ...spotPayload(),
  'canWithdraw': true,
  'canDeposit': true,
};
Map<String, Object?> transferFuturesPayload() {
  final p = accountPayload();
  p['canWithdraw'] = true;
  p['canDeposit'] = true;
  (p['assets'] as List).first['maxWithdrawAmount'] = '19.999999999999999999';
  return p;
}

InternalTransferContext transferContext({
  DateTime? now,
  String address = accountAddress,
  String asset = 'USDT',
  InternalTransferDirection direction = InternalTransferDirection.spotToFutures,
  Object? spot,
  Object? futures,
  FuturesAssetMode mode = FuturesAssetMode.multi,
}) {
  final time = now ?? DateTime.now().toUtc();
  return mapInternalTransferContext(
    spotPayload: spot ?? transferSpotPayload(),
    futuresPayload: futures ?? transferFuturesPayload(),
    catalog: mapInternalTransferCatalog(
      publicRows(['USDT', 'BTC', 'BNB']),
      publicRows([
        {'assetCode': 'USDT', 'assetDecimal': 2},
        {'assetCode': 'BTC', 'assetDecimal': 7},
        {'assetCode': 'BNB', 'assetDecimal': 5},
      ]),
      time,
    ),
    address: address,
    asset: asset,
    direction: direction,
    mode: mode,
    receivedAt: time,
    completedAt: time,
  );
}

InternalTransferRecord transferRecord({DateTime? now, InternalTransferReply? reply}) =>
    InternalTransferRecord(
      address: accountAddress,
      asset: 'USDT',
      amount: '1.01',
      direction: InternalTransferDirection.spotToFutures,
      clientId: 'vanta-transfer-original',
      nonce: 1793779200000000,
      preparedAt: now ?? DateTime.now().toUtc(),
      reply: reply,
    );
InternalTransferReply transferReply() => InternalTransferReply('9007199254740993');

class TestInternalTransferRepository implements InternalTransferRepository {
  DateTime Function() now = () => DateTime.now().toUtc();
  int reads = 0, submits = 0, posts = 0;
  Completer<void>? readGate, signGate, postGate;
  Object? readFailure, submitFailure;
  InternalTransferContext? context;
  InternalTransferReply? reply;
  bool Function()? current;
  Future<void> Function()? beforeDispatch;
  @override
  Future<InternalTransferContext> read({
    required String address,
    required String asset,
    required InternalTransferDirection direction,
    required bool Function() isCurrent,
  }) async {
    reads++;
    current = isCurrent;
    await readGate?.future;
    if (readFailure case final e?) throw e;
    return context ??
        transferContext(now: now(), address: address, asset: asset, direction: direction);
  }

  @override
  Future<InternalTransferReply> submit({
    required InternalTransferReview review,
    required bool Function() canSubmit,
    required Future<void> Function(int nonce) beforeSend,
    required void Function() onDispatch,
  }) async {
    submits++;
    current = canSubmit;
    await signGate?.future;
    if (!canSubmit()) throw const AccountReadFailure('internalTransferChanged');
    await beforeSend(1793779200000000);
    await beforeDispatch?.call();
    if (!canSubmit()) throw const AccountReadFailure('internalTransferChanged');
    onDispatch();
    posts++;
    await postGate?.future;
    if (submitFailure case final e?) throw e;
    return reply ?? transferReply();
  }
}

class GatedInternalTransferJournal extends MemoryInternalTransferJournal {
  Completer<void>? gate;
  Object? prepareFailure, completeFailure;
  @override
  Future<void> prepare(InternalTransferRecord record) async {
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
