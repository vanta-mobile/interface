import 'package:decimal/decimal.dart';

import 'live_order_time_in_force.dart';
import 'live_order_trigger.dart';
import 'live_order_trailing.dart';
import 'live_order_attachment.dart';
import 'live_order_peg.dart';
import 'attached_entry_peg.dart';

/// Signed request values must use the exact string accepted by the decimal validator.
Decimal? parseOrderDecimal(String text) {
  if (text.length > 80 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) return null;
  return Decimal.tryParse(text);
}

class LiveOrderDraft {
  const LiveOrderDraft({
    required this.buy,
    required this.market,
    required this.quantity,
    required this.price,
    this.reduceOnly = false,
    this.closingSide,
    this.timeInForce = LiveOrderTimeInForce.gtc,
    this.trigger,
    this.entireClose = false,
    this.trailing,
    this.quickEntry = false,
    this.attachment,
    this.peg,
  });
  LiveOrderDraft withQuantity(String value) => LiveOrderDraft(
    buy: buy,
    market: market,
    quantity: value,
    price: price,
    reduceOnly: reduceOnly,
    closingSide: closingSide,
    timeInForce: timeInForce,
    trigger: trigger,
    entireClose: entireClose,
    trailing: trailing,
    quickEntry: quickEntry,
    attachment: attachment,
    peg: peg,
  );
  LiveOrderDraft withDirection(bool value) => LiveOrderDraft(
    buy: value,
    market: market,
    quantity: quantity,
    price: price,
    reduceOnly: reduceOnly,
    closingSide: closingSide,
    timeInForce: timeInForce,
    trigger: trigger,
    entireClose: entireClose,
    trailing: trailing,
    quickEntry: quickEntry,
    attachment: attachment,
    peg: peg,
  );
  final bool buy, market;
  final String quantity, price;
  final bool reduceOnly;
  final String? closingSide;
  final LiveOrderTimeInForce timeInForce;
  final LiveOrderTrigger? trigger;
  final bool entireClose, quickEntry;
  final LiveOrderAttachment? attachment;
  final LiveOrderPeg? peg;
  bool get pegged => peg != null || attachment?.entryPeg != null;

  /// Zero is a transport sentinel, never a user-entered price. Ordinary pegs
  /// also support reducing orders; compound pegs retain their own constraints.
  bool get validPegShape =>
      (timeInForce != LiveOrderTimeInForce.postOnly ||
          (peg == null || peg == LiveOrderPeg.queue) &&
              (attachment?.entryPeg == null || attachment?.entryPeg == AttachedEntryPeg.queue1)) &&
      (peg == null ||
          !market &&
              price.isEmpty &&
              attachment == null &&
              !entireClose &&
              !quickEntry &&
              trailing == null) &&
      (attachment?.entryPeg == null ||
          !market &&
              price.isEmpty &&
              !reducing &&
              !entireClose &&
              !quickEntry &&
              trailing == null &&
              attachment!.exits.isNotEmpty);
  bool get validQuickShape =>
      !quickEntry ||
      market &&
          price.isEmpty &&
          trigger == null &&
          attachment == null &&
          trailing == null &&
          !reduceOnly &&
          closingSide == null &&
          !entireClose;
  final LiveOrderTrailing? trailing;
  bool get validTrailingShape =>
      trailing == null || market && trigger == null && !entireClose && price.isEmpty;
  bool get validEntireShape =>
      !entireClose ||
      trigger != null &&
          market &&
          closingSide != null &&
          !reduceOnly &&
          quantity.isEmpty &&
          price.isEmpty;
  bool get reducing => reduceOnly || closingSide != null;
  String get orderType => trailing != null
      ? 'TRAILING_STOP_MARKET'
      : trigger?.orderType(market: market) ?? (market ? 'MARKET' : 'LIMIT');
}
