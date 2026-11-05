import 'dart:convert';

import 'package:decimal/decimal.dart';

import 'aster_account.dart';
import 'futures_asset_mode.dart';

class RebalanceContext {
  const RebalanceContext({required this.mode, required this.account, required this.receivedAt});
  final FuturesAssetMode mode;
  final AsterAccount account;
  final DateTime receivedAt;
  String get address => account.address;
  Decimal? get usdt => account.assets.where((a) => a.asset == 'USDT').singleOrNull?.walletBalance;
  bool get needed => mode == FuturesAssetMode.multi && usdt != null && usdt! < Decimal.zero;
  // Freeze all reported financial terms. Even equal-timestamp account events
  // independently invalidate the review in the controller.
  String get terms => jsonEncode({
    'address': address.toLowerCase(),
    'mode': mode.name,
    'summary': [
      '${account.walletBalance}',
      '${account.marginBalance}',
      '${account.availableBalance}',
      '${account.unrealizedProfit}',
      '${account.initialMargin}',
      account.canTrade,
    ],
    'assets':
        (account.assets
            .map(
              (a) => [
                a.asset,
                '${a.walletBalance}',
                '${a.availableBalance}',
                '${a.crossWalletBalance}',
                '${a.unrealizedProfit}',
                a.marginAvailable,
              ],
            )
            .toList()
          ..sort((a, b) => (a.first as String).compareTo(b.first as String))),
    'positions':
        (account.positions
            .map(
              (p) => [
                p.symbol,
                p.side,
                '${p.quantity}',
                '${p.initialMargin}',
                '${p.entryPrice}',
                '${p.unrealizedProfit}',
                '${p.isolatedWallet}',
                p.isolated,
                p.leverage,
              ],
            )
            .toList()
          ..sort((a, b) => '${a[0]}:${a[1]}'.compareTo('${b[0]}:${b[1]}'))),
  });
}

/// A response reports a conversion or a no-op. It is not an order receipt,
/// a withdrawal permission or a statement that all account debts are cleared.
class RebalanceReply {
  const RebalanceReply.noExchange()
    : asset = null,
      balance = null,
      accountId = null,
      updateTime = null;
  RebalanceReply({
    required String this.asset,
    required Decimal this.balance,
    required String this.accountId,
    required DateTime this.updateTime,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_.-]{1,50}$').hasMatch(asset!) ||
        !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(accountId!) ||
        BigInt.parse(accountId!) > (BigInt.one << 63) - BigInt.one ||
        updateTime!.millisecondsSinceEpoch <= 0 ||
        updateTime!.year > 9999 ||
        balance!.toString().length > 160) {
      throw const FormatException();
    }
  }
  final String? asset, accountId;
  final Decimal? balance;
  final DateTime? updateTime;
  bool get noExchange => asset == null;
}

class RebalanceRecord {
  RebalanceRecord({
    required this.address,
    required this.nonce,
    required this.preparedAt,
    required this.previousUsdt,
    this.reply,
  }) {
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address) ||
        BigInt.parse(address.substring(2), radix: 16) == BigInt.zero ||
        nonce <= 0 ||
        nonce > 9223372036854775807 ||
        preparedAt.millisecondsSinceEpoch <= 0 ||
        preparedAt.year > 9999 ||
        previousUsdt >= Decimal.zero ||
        previousUsdt.toString().length > 160) {
      throw const FormatException();
    }
  }
  final String address;
  final int nonce;
  final DateTime preparedAt;
  final Decimal previousUsdt;
  final RebalanceReply? reply;
  String get key => '${address.toLowerCase()}:$nonce';
  RebalanceRecord reported(RebalanceReply value) {
    final old = reply;
    if (old != null &&
        (old.asset != value.asset ||
            old.balance != value.balance ||
            old.accountId != value.accountId ||
            old.updateTime != value.updateTime)) {
      throw const FormatException();
    }
    return RebalanceRecord(
      address: address,
      nonce: nonce,
      preparedAt: preparedAt,
      previousUsdt: previousUsdt,
      reply: value,
    );
  }
}

class RebalanceStorage {
  RebalanceStorage({
    Iterable<RebalanceRecord> records = const [],
    this.ready = true,
    this.failure = false,
  }) : records = List.unmodifiable(records);
  final List<RebalanceRecord> records;
  final bool ready, failure;
}

abstract interface class RebalanceJournal {
  RebalanceStorage get snapshot;
  Stream<RebalanceStorage> get changes;
  Future<void> reload();
  Future<void> prepare(RebalanceRecord record);
  Future<void> report(String key, RebalanceReply reply);
  Future<void> complete(String key);
  Future<void> close();
}

enum RebalanceStep { idle, reading, reviewing, signing, submitting, checking }

class RebalanceReview {
  const RebalanceReview(this.context);
  final RebalanceContext context;
}

class RebalanceState {
  const RebalanceState({
    this.context,
    this.review,
    this.reply,
    this.failure,
    this.step = RebalanceStep.idle,
    this.stale = true,
  });
  final RebalanceContext? context;
  final RebalanceReview? review;
  final RebalanceReply? reply;
  final String? failure;
  final RebalanceStep step;
  final bool stale;
  bool get busy => step != RebalanceStep.idle && step != RebalanceStep.reviewing;
}

abstract interface class RebalanceRepository {
  Future<RebalanceContext> read({required String address, required bool Function() isCurrent});
  Future<RebalanceReply> submit({
    required RebalanceContext context,
    required bool Function() canSubmit,
    required Future<void> Function(int nonce) beforeSend,
    required void Function() onDispatch,
  });
}
