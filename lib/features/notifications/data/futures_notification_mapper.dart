import 'package:decimal/decimal.dart';

import '../domain/account_notification.dart';
import '../../portfolio/data/account_update_mapper.dart';

AccountNotification? mapFuturesNotification(Map<String, dynamic> payload) => switch (payload['e']) {
  'ORDER_TRADE_UPDATE' => _order(payload),
  'MARGIN_CALL' => _margin(payload),
  'ACCOUNT_UPDATE' => _balances(payload),
  _ => null,
};

BalanceNotification? _balances(Map<String, dynamic> payload) {
  final update = mapAccountUpdate(payload);
  if (update.balances.isEmpty) return null;
  return BalanceNotification(
    eventTime: update.eventTime,
    transactionTime: update.transactionTime,
    reason: update.reason!,
    balances: update.balances,
  );
}

OrderNotification _order(Map<String, dynamic> payload) {
  final raw = payload['o'];
  if (raw is! Map<String, dynamic>) throw const FormatException();
  final client = _identifier(raw['c']);
  final status = _choice(raw['X'], {
    'NEW',
    'PARTIALLY_FILLED',
    'FILLED',
    'CANCELED',
    'EXPIRED',
    'REJECTED',
    'NEW_INSURANCE',
    'NEW_ADL',
  });
  final execution = _choice(raw['x'], {
    'NEW',
    'CANCELED',
    'CALCULATED',
    'EXPIRED',
    'TRADE',
    'AMENDMENT',
    'REJECTED',
  });
  final type = _choice(raw['o'], _types);
  final adl = client == 'adl_autoclose' || status == 'NEW_ADL';
  final liquidation =
      client.startsWith('autoclose-') ||
      status == 'NEW_INSURANCE' ||
      execution == 'CALCULATED' ||
      type == 'LIQUIDATION';
  // Conflicting risk identities must never be mislabeled.
  if (adl && (client.startsWith('autoclose-') || status == 'NEW_INSURANCE')) {
    throw const FormatException();
  }
  final quantity = _decimal(raw['q']), filled = _decimal(raw['z']), last = _decimal(raw['l']);
  final close = _optionalBool(raw['cp']);
  if (last > filled ||
      quantity != Decimal.zero && filled > quantity ||
      quantity == Decimal.zero && close != true ||
      status == 'NEW' && filled != Decimal.zero ||
      status == 'PARTIALLY_FILLED' &&
          (filled == Decimal.zero || quantity != Decimal.zero && filled >= quantity) ||
      status == 'FILLED' &&
          (filled == Decimal.zero || quantity != Decimal.zero && filled != quantity)) {
    throw const FormatException();
  }
  final tradeId = _id(raw['t'], allowZero: true, allowNegativeOne: execution != 'TRADE');
  if (execution == 'TRADE' && last == Decimal.zero) throw const FormatException();
  final fee = raw['n'] == null ? null : _decimal(raw['n'], signed: true);
  final feeAsset = raw['N'] == null ? null : _symbol(raw['N']);
  if ((fee == null) != (feeAsset == null)) throw const FormatException();
  final result = OrderNotification(
    eventTime: _time(payload['E']),
    transactionTime: _time(payload['T']),
    tradeTime: _time(raw['T']),
    symbol: _symbol(raw['s']),
    orderId: _id(raw['i']),
    clientOrderId: client,
    side: _choice(raw['S'], {'BUY', 'SELL'}),
    positionSide: _choice(raw['ps'], {'BOTH', 'LONG', 'SHORT'}),
    orderType: type,
    originalType: _choice(raw['ot'], _types),
    executionType: execution,
    status: status,
    quantity: quantity,
    price: _decimal(raw['p']),
    averagePrice: _decimal(raw['ap']),
    lastQuantity: last,
    filledQuantity: filled,
    lastPrice: _decimal(raw['L']),
    tradeId: tradeId,
    realizedPnl: _decimal(raw['rp'], signed: true),
    fee: fee,
    feeAsset: feeAsset,
    triggerPrice: raw['sp'] == null || type == 'TRAILING_STOP_MARKET' ? null : _decimal(raw['sp']),
    workingType: raw['wt'] == null ? null : _choice(raw['wt'], {'MARK_PRICE', 'CONTRACT_PRICE'}),
    reduceOnly: _optionalBool(raw['R']) ?? (throw const FormatException()),
    closePosition: close,
    risk: adl
        ? OrderRisk.adl
        : liquidation
        ? OrderRisk.liquidation
        : null,
  );
  if (execution == 'TRADE' &&
      (result.lastPrice == Decimal.zero || result.averagePrice == Decimal.zero)) {
    throw const FormatException();
  }
  return result;
}

MarginNotification _margin(Map<String, dynamic> payload) {
  final positions = payload['p'];
  if (positions is! List || positions.isEmpty || positions.length > 1000) {
    throw const FormatException();
  }
  final result = <MarginRiskPosition>[];
  final seen = <String>{};
  for (final raw in positions) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final symbol = _symbol(raw['s']), side = _choice(raw['ps'], {'BOTH', 'LONG', 'SHORT'});
    if (!seen.add('$symbol:$side')) throw const FormatException();
    final mode = _choice(raw['mt'], {'CROSSED', 'ISOLATED'});
    final quantity = _decimal(raw['pa'], signed: true), mark = _decimal(raw['mp']);
    if (quantity == Decimal.zero ||
        mark == Decimal.zero ||
        side == 'LONG' && quantity < Decimal.zero ||
        side == 'SHORT' && quantity > Decimal.zero) {
      throw const FormatException();
    }
    final isolated = raw['iw'] == null ? null : _decimal(raw['iw'], signed: true);
    if (mode == 'ISOLATED' && isolated == null) throw const FormatException();
    result.add(
      MarginRiskPosition(
        symbol: symbol,
        side: side,
        quantity: quantity,
        marginType: mode,
        isolatedWallet: isolated,
        markPrice: mark,
        unrealizedPnl: _decimal(raw['up'], signed: true),
        maintenanceMargin: _decimal(raw['mm']),
      ),
    );
  }
  return MarginNotification(
    eventTime: _time(payload['E']),
    positions: result,
    crossWalletBalance: payload['cw'] == null ? null : _decimal(payload['cw'], signed: true),
  );
}

const _types = {
  'LIMIT',
  'MARKET',
  'STOP',
  'STOP_MARKET',
  'TAKE_PROFIT',
  'TAKE_PROFIT_MARKET',
  'TRAILING_STOP_MARKET',
  'LIQUIDATION',
};
String _choice(Object? value, Set<String> choices) =>
    value is String && choices.contains(value) ? value : throw const FormatException();
String _symbol(Object? value) =>
    value is String && RegExp(r'^[\p{L}\p{N}_.-]{1,50}$', unicode: true).hasMatch(value)
    ? value
    : throw const FormatException();
String _identifier(Object? value) =>
    value is String && RegExp(r'^[a-zA-Z0-9_.:/-]{1,128}$').hasMatch(value)
    ? value
    : throw const FormatException();
String _id(Object? value, {bool allowZero = false, bool allowNegativeOne = false}) {
  if (value is! int && value is! String) throw const FormatException();
  final id = '$value';
  if (allowNegativeOne && id == '-1' ||
      allowZero && id == '0' ||
      RegExp(r'^[1-9]\d{0,30}$').hasMatch(id)) {
    return id;
  }
  throw const FormatException();
}

Decimal _decimal(Object? value, {bool signed = false}) {
  if (value is! String ||
      value.length > 160 ||
      !(signed ? RegExp(r'^-?\d+(?:\.\d+)?$') : RegExp(r'^\d+(?:\.\d+)?$')).hasMatch(value)) {
    throw const FormatException();
  }
  return Decimal.parse(value);
}

bool? _optionalBool(Object? value) =>
    value == null || value is bool ? value as bool? : throw const FormatException();
DateTime _time(Object? value) {
  if (value is! int || value <= 0 || value > 253402300799999) throw const FormatException();
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}
