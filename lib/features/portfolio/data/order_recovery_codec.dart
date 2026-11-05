import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../domain/futures_position_mode.dart';
import '../domain/attached_entry_peg.dart';
import '../domain/live_order_peg.dart';
import '../domain/live_order.dart';
import '../domain/live_order_attachment.dart';
import '../domain/live_order_time_in_force.dart';
import '../domain/live_order_trailing.dart';
import '../domain/live_order_trigger.dart';
import '../domain/order_query.dart';
import '../domain/order_recovery.dart';
import 'position_configuration_rows.dart';

Map<String, Object?> _trigger(LiveOrderTrigger value) => {
  'kind': value.kind.name,
  'basis': value.basis.name,
  'price': value.price,
  'protect': value.protect,
};

Map<String, Object?> _exit(AttachedExit value) => {
  ..._trigger(value),
  'execution': value.execution.name,
  'limitPrice': value.limitPrice,
};

Map<String, Object?> encodeRecoveryRecord(OrderRecoveryRecord record) {
  final q = record.query, d = q.draft;
  return {
    'exchange': 'aster-futures-v3',
    'address': q.address,
    'symbol': q.symbol,
    'clientId': q.clientOrderId,
    'createdAt': record.createdAt.millisecondsSinceEpoch,
    'mode': q.mode.name,
    'protectedQuantity': q.protectedQuantity,
    'draft': {
      'buy': d.buy,
      if (d.peg case final peg?) 'peg': peg.wire,
      'market': d.market,
      'quantity': d.quantity,
      'price': d.market ? '' : d.price,
      'reduceOnly': d.reduceOnly,
      'closingSide': d.closingSide,
      'entireClose': d.entireClose,
      'quickEntry': d.quickEntry,
      'timeInForce': d.market ? 'gtc' : d.timeInForce.name,
      'trigger': d.trigger == null ? null : _trigger(d.trigger!),
      'trailing': d.trailing == null
          ? null
          : {
              'basis': d.trailing!.basis.name,
              'callbackRate': d.trailing!.callbackRate,
              'activationPrice': d.trailing!.activationPrice,
            },
      'attachment': d.attachment == null
          ? null
          : {
              'drivenOn': d.attachment!.drivenOn.wire,
              if (d.attachment!.entryPeg case final peg?) 'entryPeg': peg.wire,
              'takeProfit': d.attachment!.takeProfit == null
                  ? null
                  : _exit(d.attachment!.takeProfit!),
              'stopLoss': d.attachment!.stopLoss == null ? null : _exit(d.attachment!.stopLoss!),
            },
    },
  };
}

Map<String, dynamic> _map(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty) {
    throw const FormatException();
  }
  return value;
}

String _text(Object? value) {
  if (value is! String || value.length > 80) throw const FormatException();
  return value;
}

bool _bool(Object? value) {
  if (value is! bool) throw const FormatException();
  return value;
}

T _enum<T extends Enum>(List<T> values, Object? value) =>
    values.where((e) => e.name == value).singleOrNull ?? (throw const FormatException());
void _positive(String value) {
  if ((parseOrderDecimal(value) ?? Decimal.zero) <= Decimal.zero) throw const FormatException();
}

LiveOrderTrigger? _readTrigger(Object? value) {
  if (value == null) return null;
  final map = _map(value, {'kind', 'basis', 'price', 'protect'});
  final price = _text(map['price']);
  _positive(price);
  return LiveOrderTrigger(
    kind: _enum(LiveOrderTriggerKind.values, map['kind']),
    price: price,
    basis: _enum(LiveOrderTriggerBasis.values, map['basis']),
    protect: _bool(map['protect']),
  );
}

AttachedExit? _readExit(Object? value, {required bool modern}) {
  if (value == null) return null;
  final map = _map(value, {
    'kind',
    'basis',
    'price',
    'protect',
    if (modern) ...{'execution', 'limitPrice'},
  });
  final price = _text(map['price']);
  _positive(price);
  final execution = modern
      ? _enum(AttachedExitExecution.values, map['execution'])
      : AttachedExitExecution.market;
  final limit = map['limitPrice'];
  if (execution == AttachedExitExecution.manualLimit) {
    _positive(_text(limit));
  } else if (limit != null) {
    throw const FormatException();
  }
  return AttachedExit(
    kind: _enum(LiveOrderTriggerKind.values, map['kind']),
    price: price,
    basis: _enum(LiveOrderTriggerBasis.values, map['basis']),
    protect: _bool(map['protect']),
    execution: execution,
    limitPrice: limit as String?,
  );
}

OrderRecoveryRecord decodeRecoveryRecord(
  Object? value, {
  bool allowPeg = true,
  bool allowOrdinaryPeg = true,
  bool allowAdvancedAttachment = true,
}) {
  final map = _map(value, {
    'exchange',
    'address',
    'symbol',
    'clientId',
    'createdAt',
    'mode',
    'protectedQuantity',
    'draft',
  });
  final address = _text(map['address']), symbol = _text(map['symbol']), id = _text(map['clientId']);
  validatePositionSymbol(symbol);
  final created = map['createdAt'];
  if (map['exchange'] != 'aster-futures-v3' ||
      !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address) ||
      !RegExp(r'^[.A-Z:/a-z0-9_-]{1,36}$').hasMatch(id) ||
      created is! int ||
      created < 0 ||
      created > 10413792000000) {
    throw const FormatException();
  }
  final rawDraft = map['draft'];
  final hasOrdinaryPeg = rawDraft is Map<String, dynamic> && rawDraft.containsKey('peg');
  final d = _map(rawDraft, {
    if (allowOrdinaryPeg && hasOrdinaryPeg) 'peg',
    'buy',
    'market',
    'quantity',
    'price',
    'reduceOnly',
    'closingSide',
    'entireClose',
    'quickEntry',
    'timeInForce',
    'trigger',
    'trailing',
    'attachment',
  });
  final side = d['closingSide'];
  if (side != null && !{'BOTH', 'LONG', 'SHORT'}.contains(side)) throw const FormatException();
  LiveOrderTrailing? trailing;
  if (d['trailing'] != null) {
    final t = _map(d['trailing'], {'basis', 'callbackRate', 'activationPrice'});
    final rate = _text(t['callbackRate']), activation = t['activationPrice'];
    final amount = parseOrderDecimal(rate);
    if (amount == null || amount < Decimal.parse('0.1') || amount > Decimal.fromInt(5)) {
      throw const FormatException();
    }
    if (activation != null) _positive(_text(activation));
    trailing = LiveOrderTrailing(
      callbackRate: rate,
      activationPrice: activation as String?,
      basis: _enum(LiveOrderTriggerBasis.values, t['basis']),
    );
  }
  LiveOrderAttachment? attachment;
  if (d['attachment'] != null) {
    final raw = d['attachment'];
    final hasPeg = raw is Map<String, dynamic> && raw.containsKey('entryPeg');
    final modern = raw is Map<String, dynamic> && raw.containsKey('drivenOn');
    final a = _map(raw, {
      'takeProfit',
      'stopLoss',
      if (allowPeg && hasPeg) 'entryPeg',
      if (allowAdvancedAttachment && modern) 'drivenOn',
    });
    final peg = !hasPeg
        ? null
        : AttachedEntryPeg.values.where((p) => p.wire == a['entryPeg']).singleOrNull;
    if (hasPeg && peg == null) throw const FormatException();
    attachment = LiveOrderAttachment(
      entryPeg: peg,
      drivenOn: modern
          ? AttachedOrderDrivenOn.values.where((v) => v.wire == a['drivenOn']).singleOrNull ??
                (throw const FormatException())
          : AttachedOrderDrivenOn.filled,
      takeProfit: _readExit(a['takeProfit'], modern: modern),
      stopLoss: _readExit(a['stopLoss'], modern: modern),
    );
    if (attachment.exits.isEmpty ||
        attachment.takeProfit?.kind == LiveOrderTriggerKind.stop ||
        attachment.stopLoss?.kind == LiveOrderTriggerKind.takeProfit ||
        id.length > 28) {
      throw const FormatException();
    }
  }
  final draft = LiveOrderDraft(
    buy: _bool(d['buy']),
    market: _bool(d['market']),
    quantity: _text(d['quantity']),
    price: _text(d['price']),
    reduceOnly: _bool(d['reduceOnly']),
    closingSide: side as String?,
    entireClose: _bool(d['entireClose']),
    quickEntry: _bool(d['quickEntry']),
    timeInForce: _enum(LiveOrderTimeInForce.values, d['timeInForce']),
    trigger: _readTrigger(d['trigger']),
    trailing: trailing,
    attachment: attachment,
    peg: !hasOrdinaryPeg
        ? null
        : LiveOrderPeg.values.where((p) => p.wire == d['peg']).singleOrNull ??
              (throw const FormatException()),
  );
  final mode = _enum(FuturesPositionMode.values, map['mode']);
  if (!draft.validPegShape ||
      !draft.validQuickShape ||
      !draft.validEntireShape ||
      !draft.validTrailingShape ||
      draft.reduceOnly && mode != FuturesPositionMode.oneWay ||
      side != null && (mode == FuturesPositionMode.oneWay ? side != 'BOTH' : side == 'BOTH')) {
    throw const FormatException();
  }
  if (!draft.entireClose) _positive(draft.quantity);
  if (!draft.market && !draft.pegged) _positive(draft.price);
  final protected = map['protectedQuantity'];
  if (attachment == null ? protected != null : protected is! String) throw const FormatException();
  if (attachment != null) {
    _positive(protected as String);
    if (draft.reducing ||
        draft.entireClose ||
        draft.quickEntry ||
        trailing != null ||
        parseOrderDecimal(protected)! > parseOrderDecimal(draft.quantity)! ||
        attachment.drivenOn == AttachedOrderDrivenOn.partialOrFilled &&
            parseOrderDecimal(protected) != parseOrderDecimal(draft.quantity) ||
        !draft.market && draft.timeInForce == LiveOrderTimeInForce.ioc) {
      throw const FormatException();
    }
  }
  return OrderRecoveryRecord(
    query: OrderQuery(
      address: address,
      symbol: symbol,
      clientOrderId: id,
      mode: mode,
      draft: draft,
      protectedQuantity: protected as String?,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(created, isUtc: true),
  );
}

String encodeRecoveryJournal(Iterable<OrderRecoveryRecord> records) =>
    jsonEncode({'version': 4, 'records': records.map(encodeRecoveryRecord).toList()});

List<OrderRecoveryRecord> decodeRecoveryJournal(String text) {
  if (utf8.encode(text).length > 1024 * 1024) throw const FormatException();
  final map = _map(jsonDecode(text), {'version', 'records'}), raw = map['records'];
  if (map['version'] is! int ||
      !{1, 2, 3, 4}.contains(map['version']) ||
      raw is! List ||
      raw.length > 1000) {
    throw const FormatException();
  }
  final result = raw
      .map(
        (row) => decodeRecoveryRecord(
          row,
          allowPeg: (map['version'] as int) >= 2,
          allowOrdinaryPeg: (map['version'] as int) >= 3,
          allowAdvancedAttachment: map['version'] == 4,
        ),
      )
      .toList();
  if (result.map((r) => r.key).toSet().length != result.length) throw const FormatException();
  return List.unmodifiable(result);
}
