part of 'account_notification.dart';

/// Spot buys/sells have no futures position side, realized PnL or risk flags.
class SpotOrderNotification extends AccountNotification {
  const SpotOrderNotification({
    required DateTime eventTime,
    required this.transactionTime,
    required this.symbol,
    required this.orderId,
    required this.clientOrderId,
    required this.side,
    required this.orderType,
    required this.executionType,
    required this.status,
    required this.quantity,
    required this.price,
    required this.averagePrice,
    required this.lastQuantity,
    required this.filledQuantity,
    required this.lastPrice,
    required this.tradeId,
    required this.lastQuoteAmount,
    required this.cumulativeQuoteAmount,
    this.originalType,
    this.creationMilliseconds,
    this.fee,
    this.feeAsset,
    this.stopPrice,
    this.quoteOrderQuantity,
  }) : super(eventTime);
  final DateTime transactionTime;
  final String symbol, orderId, clientOrderId, side, orderType, executionType, status, tradeId;
  final String? originalType, feeAsset;
  final Decimal quantity, price, averagePrice, lastQuantity, filledQuantity, lastPrice;
  final Decimal lastQuoteAmount, cumulativeQuoteAmount;
  final Decimal? fee, stopPrice, quoteOrderQuantity;

  /// Zero means creation time was not supplied as an actual timestamp.
  final int? creationMilliseconds;
  @override
  bool get critical => false;
  @override
  String get dedupeKey => jsonEncode([
    'SPOT',
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
      transactionTime.millisecondsSinceEpoch,
    ],
  ]);
}
