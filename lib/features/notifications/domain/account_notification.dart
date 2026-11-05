import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../../funding/domain/transfer_history.dart';

part 'spot_order_notification.dart';
part 'transfer_notification.dart';

/// Financial event details validated at the transport/storage boundary.
sealed class AccountNotification {
  const AccountNotification(this.eventTime);
  final DateTime eventTime;
  String get dedupeKey;
  bool get critical;
}

enum OrderRisk { liquidation, adl }

class OrderNotification extends AccountNotification {
  const OrderNotification({
    required DateTime eventTime,
    required this.transactionTime,
    required this.tradeTime,
    required this.symbol,
    required this.orderId,
    required this.clientOrderId,
    required this.side,
    required this.positionSide,
    required this.orderType,
    required this.originalType,
    required this.executionType,
    required this.status,
    required this.quantity,
    required this.price,
    required this.averagePrice,
    required this.lastQuantity,
    required this.filledQuantity,
    required this.lastPrice,
    required this.tradeId,
    required this.realizedPnl,
    required this.reduceOnly,
    this.closePosition,
    this.fee,
    this.feeAsset,
    this.triggerPrice,
    this.workingType,
    this.risk,
  }) : super(eventTime);
  final DateTime transactionTime, tradeTime;
  final String symbol, orderId, clientOrderId, side, positionSide;
  final String orderType, originalType, executionType, status, tradeId;
  final Decimal quantity, price, averagePrice, lastQuantity, filledQuantity, lastPrice, realizedPnl;
  final Decimal? fee, triggerPrice;
  final String? feeAsset, workingType;
  final bool reduceOnly;
  final bool? closePosition;
  final OrderRisk? risk;
  @override
  bool get critical => risk != null;
  @override
  String get dedupeKey => jsonEncode([
    'PERP',
    'ORDER',
    symbol,
    orderId,
    if (executionType == 'TRADE') ...[
      'TRADE',
      tradeId,
    ] else ...[
      executionType,
      status,
      eventTime.millisecondsSinceEpoch,
      tradeTime.millisecondsSinceEpoch,
    ],
  ]);
}

class MarginRiskPosition {
  const MarginRiskPosition({
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.marginType,
    required this.isolatedWallet,
    required this.markPrice,
    required this.unrealizedPnl,
    required this.maintenanceMargin,
  });
  final String symbol, side, marginType;
  final Decimal quantity, markPrice, unrealizedPnl, maintenanceMargin;
  final Decimal? isolatedWallet;
  List<String?> get canonical => [
    symbol,
    side,
    quantity.toString(),
    marginType,
    isolatedWallet?.toString(),
    markPrice.toString(),
    unrealizedPnl.toString(),
    maintenanceMargin.toString(),
  ];
}

class MarginNotification extends AccountNotification {
  MarginNotification({
    required DateTime eventTime,
    required Iterable<MarginRiskPosition> positions,
    this.crossWalletBalance,
  }) : positions = List.unmodifiable(positions),
       super(eventTime);
  final List<MarginRiskPosition> positions;
  final Decimal? crossWalletBalance;
  @override
  bool get critical => true;
  @override
  String get dedupeKey {
    final content = positions.map((p) => jsonEncode(p.canonical)).toList()..sort();
    return jsonEncode([
      'PERP',
      'MARGIN_CALL',
      eventTime.millisecondsSinceEpoch,
      crossWalletBalance?.toString(),
      content,
    ]);
  }
}

class InboxEntry {
  const InboxEntry({required this.address, required this.event, this.read = false});
  final String address;
  final AccountNotification event;
  final bool read;
  String get key => jsonEncode([address.toLowerCase(), event.dedupeKey]);
  InboxEntry markRead() => InboxEntry(address: address, event: event, read: true);
}

class InboxSnapshot {
  InboxSnapshot({
    Iterable<InboxEntry> entries = const [],
    this.loaded = false,
    this.storageFailed = false,
  }) : entries = List.unmodifiable(entries);
  final List<InboxEntry> entries;
  final bool loaded, storageFailed;
}

abstract interface class NotificationRepository {
  InboxSnapshot get snapshot;
  Stream<InboxSnapshot> get changes;
  Future<void> reload();
  Future<void> add(String address, AccountNotification event);
  Future<void> markRead(String address, {String? key});

  /// Establish an initial baseline silently, then atomically save observations
  /// and their new notifications. Returns true only for the initial baseline.
  Future<bool> observeTransfers(
    String address,
    List<TransferRecord> records,
    DateTime observedAt, {
    required bool Function() isCurrent,
  });
  Future<void> dispose();
}
