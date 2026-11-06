import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';
import 'futures_position_mode.dart';
import 'position_margin_mode.dart';
import 'live_order_funds.dart';
import 'live_order_draft.dart';
import 'live_order_rules.dart';
import 'live_order_trigger.dart';
import 'live_order_attachment.dart';
import 'attached_order.dart';

export 'live_order_draft.dart';
export 'live_order_rules.dart';

class LiveOrderPosition {
  const LiveOrderPosition({required this.side, required this.quantity, required this.entryPrice});
  final String side;
  final Decimal quantity, entryPrice;
  bool get long => quantity > Decimal.zero;
}

class LiveOrderContext {
  LiveOrderContext({
    required this.address,
    required this.rules,
    required this.mode,
    required this.marginMode,
    required this.leverage,
    required this.markPrice,
    required this.receivedAt,
    Map<String, LiveOrderPosition> positions = const {},
    this.bid,
    this.ask,
    this.funds,
    this.fundsFailure,
    this.lastPrice,
    this.markReceivedAt,
    this.bookReceivedAt,
    this.lastReceivedAt,
  }) : positions = Map.unmodifiable(positions);
  final String address;
  final LiveOrderRules rules;
  final FuturesPositionMode mode;
  final PositionMarginMode marginMode;
  final int leverage;
  final Decimal markPrice;
  final DateTime receivedAt;
  // Public quote receipts are separate from the signed account lease.
  final DateTime? markReceivedAt, bookReceivedAt, lastReceivedAt;
  final Map<String, LiveOrderPosition> positions;
  final Decimal? bid, ask;
  final Decimal? lastPrice;
  final LiveOrderFunds? funds;
  final AccountReadFailure? fundsFailure;
  String get symbol => rules.symbol;

  /// Public repricing may replace only prices; private/configuration facts and
  /// the signed deadline must remain attached to exactly the original anchor.
  bool sameAccountAnchor(LiveOrderContext other) =>
      address == other.address &&
      rules == other.rules &&
      mode == other.mode &&
      marginMode == other.marginMode &&
      leverage == other.leverage &&
      receivedAt == other.receivedAt &&
      funds == other.funds &&
      fundsFailure == other.fundsFailure &&
      positions.length == other.positions.length &&
      positions.entries.every((e) => other.positions[e.key] == e.value);

  Decimal closeFraction(
    String side,
    int percent, {
    required bool market,
    bool conditional = false,
  }) {
    final position = positions[side];
    if (position == null || percent < 0 || percent > 100) return Decimal.zero;
    final target = position.quantity.abs() * Decimal.fromInt(percent) * Decimal.parse('0.01');
    return (market && !conditional ? rules.marketQuantity : rules.limitQuantity).floor(target);
  }

  LiveOrderPosition? reductionPosition(LiveOrderDraft draft) =>
      positions[draft.closingSide ?? 'BOTH'];

  String? validate(LiveOrderDraft draft) {
    if (!draft.validPegShape) {
      return draft.peg == null ? 'attachedEntryPegInvalid' : 'liveOrderPegInvalid';
    }
    if (!draft.validQuickShape) return 'quickOrderInvalid';
    if (!draft.validTrailingShape) return 'liveTrailingInvalid';
    if (!draft.validEntireShape) return 'liveEntireInvalid';
    if (!draft.reducing) {
      if (fundsFailure != null) return fundsFailure!.key;
      if (funds == null) return 'liveOrderReadFunds';
      if (funds!.account.address.toLowerCase() != address.toLowerCase()) return 'authWalletChanged';
      if (funds!.account.receivedAt.isBefore(receivedAt)) return 'liveOrderReadFunds';
      if (funds!.account.canTrade == false) return 'liveOrderTradingDisabled';
    }
    if (draft.reduceOnly && mode != FuturesPositionMode.oneWay) return 'liveOrderReduceHedge';
    if (draft.reducing) {
      final position = reductionPosition(draft);
      final side = draft.closingSide;
      if (side != null &&
          (mode == FuturesPositionMode.oneWay
              ? side != 'BOTH'
              : !{'LONG', 'SHORT'}.contains(side))) {
        return 'liveClosePositionChanged';
      }
      if (position == null || position.quantity == Decimal.zero || draft.buy == position.long) {
        return 'liveClosePositionChanged';
      }
      final quantity = parseOrderDecimal(draft.quantity);
      if (!draft.entireClose && quantity != null && quantity > position.quantity.abs()) {
        return 'liveCloseTooLarge';
      }
    }
    final invalid = rules.validate(
      draft,
      markPrice,
      exemptNotional: draft.reducing && mode == FuturesPositionMode.oneWay,
      pegReference: draft.peg == null ? null : referenceExecutionPrice(draft),
    );
    if (invalid != null) return invalid;
    if (draft.trigger case final trigger?) {
      final reference = triggerReference(trigger);
      if (reference == null || reference <= Decimal.zero) {
        return 'liveOrderTriggerReferenceUnavailable';
      }
      final stop = parseOrderDecimal(trigger.price)!;
      if (trigger.rises(draft.buy) ? stop <= reference : stop >= reference) {
        return 'liveOrderTriggerImmediate';
      }
    }
    if (draft.trailing case final trailing?) {
      final reference = trailing.basis == LiveOrderTriggerBasis.mark ? markPrice : lastPrice;
      if (reference == null || reference <= Decimal.zero) {
        return 'liveOrderTriggerReferenceUnavailable';
      }
      if (trailing.activationPrice case final text?) {
        final activation = parseOrderDecimal(text)!;
        if (draft.buy ? activation >= reference : activation <= reference) {
          return 'liveTrailingImmediate';
        }
      }
    }
    return validateAttachedOrder(this, draft);
  }

  Decimal? triggerReference(LiveOrderTrigger trigger) =>
      trigger.basis == LiveOrderTriggerBasis.mark ? markPrice : lastPrice;

  /// Ordinary BBO previews use the selected current side of the book, including
  /// conditional orders whose future engine price is still unknown. Deeper
  /// compound pegs retain their separate indicative Mark/trigger reference.
  Decimal? referenceExecutionPrice(LiveOrderDraft draft) {
    if (draft.peg case final peg?) {
      if (!draft.validPegShape ||
          bid == null ||
          ask == null ||
          bid! <= Decimal.zero ||
          ask! < bid!) {
        return null;
      }
      return peg.usesAsk(draft.buy) ? ask : bid;
    }
    if (!draft.market && !draft.pegged) return parseOrderDecimal(draft.price);
    return draft.trigger == null ? markPrice : parseOrderDecimal(draft.trigger!.price);
  }

  Decimal? estimatedClosePnl(LiveOrderDraft draft) {
    if (!draft.reducing || draft.trailing != null) return null;
    final position = reductionPosition(draft), amount = referenceCloseQuantity(draft);
    if (position == null || amount == null) return null;
    final exit = draft.market && draft.trigger == null
        ? (position.long ? bid : ask)
        : referenceExecutionPrice(draft);
    if (exit == null) return null;
    return amount * (exit - position.entryPrice) * Decimal.fromInt(position.long ? 1 : -1);
  }

  /// For entire-close previews this is a read-time estimate, not an order size.
  Decimal? referenceCloseQuantity(LiveOrderDraft draft) => draft.entireClose
      ? reductionPosition(draft)?.quantity.abs()
      : parseOrderDecimal(draft.quantity);

  /// Reference opening exposure after netting the signed one-way position.
  /// Existing orders, fees, released margin and exchange risk checks are excluded.
  Decimal? estimatedOpeningQuantity(LiveOrderDraft draft) {
    if (draft.entireClose) return validate(draft) == null ? Decimal.zero : null;
    final quantity = parseOrderDecimal(draft.quantity);
    if (quantity == null || quantity <= Decimal.zero) return null;
    if (draft.reducing) return validate(draft) == null ? Decimal.zero : null;
    if (mode == FuturesPositionMode.hedge) return quantity;
    final position = positions['BOTH'];
    if (position == null) return null;
    if (position.quantity == Decimal.zero || draft.buy == position.long) return quantity;
    final residual = quantity - position.quantity.abs();
    return residual > Decimal.zero ? residual : Decimal.zero;
  }

  Decimal? estimatedOpeningMargin(LiveOrderDraft draft) {
    final quantity = estimatedOpeningQuantity(draft);
    final price = referenceExecutionPrice(draft);
    if (quantity == null || price == null || price <= Decimal.zero || leverage <= 0) return null;
    final notional = quantity * price;
    return (notional / Decimal.fromInt(leverage)).toDecimal(
      scaleOnInfinitePrecision: notional.scale + 24,
      toBigInt: (value) => value.round(),
    );
  }
}

class LiveOrderIntent {
  const LiveOrderIntent({
    required this.context,
    required this.draft,
    required this.clientOrderId,
    required this.revision,
    this.pricingContext,
  });
  final LiveOrderContext context;
  final LiveOrderContext? pricingContext;
  LiveOrderContext get executionContext {
    final priced = pricingContext;
    if (priced != null && !context.sameAccountAnchor(priced)) {
      throw const AccountReadFailure('liveCapacityChanged');
    }
    return priced ?? context;
  }

  final LiveOrderDraft draft;
  final String clientOrderId;
  final int revision;
  String get side => draft.buy ? 'BUY' : 'SELL';
  String get positionSide =>
      draft.closingSide ??
      (mode == FuturesPositionMode.oneWay
          ? 'BOTH'
          : draft.buy
          ? 'LONG'
          : 'SHORT');
  FuturesPositionMode get mode => context.mode;
  Map<String, String> get parameters => draft.attachment != null
      ? throw StateError('Attached orders require the strategy endpoint')
      : {
          'symbol': context.symbol,
          'side': side,
          'positionSide': positionSide,
          'type': draft.orderType,
          if (draft.entireClose) 'closePosition': 'true' else 'quantity': draft.quantity,
          if (draft.quickEntry && mode == FuturesPositionMode.oneWay) 'reduceOnly': 'false',
          if (!draft.entireClose && draft.reducing && mode == FuturesPositionMode.oneWay)
            'reduceOnly': 'true',
          if (!draft.market) ...{
            'timeInForce': draft.timeInForce.wire,
            'price': draft.peg == null ? draft.price : '0',
            if (draft.peg case final peg?) 'pegPriceType': peg.wire,
          },
          if (draft.trigger case final trigger?) ...{
            'stopPrice': trigger.price,
            'workingType': trigger.basis.wire,
            'priceProtect': trigger.protect ? 'TRUE' : 'FALSE',
          },
          if (draft.trailing case final trailing?) ...{
            'callbackRate': trailing.callbackRate,
            'workingType': trailing.basis.wire,
            'activationPrice': ?trailing.activationPrice,
          },
          'newClientOrderId': clientOrderId,
        };
}

enum LiveOrderStep {
  idle,
  preparing,
  signingContext,
  loadingContext,
  signingPosition,
  checkingPosition,
  signing,
  submitting,
  checkSigning,
  checking,
}

/// A POST acknowledgement is never evidence of a fill. Only the signed query
/// supplies this status; failed queries keep the client ID available to recheck.
class LiveOrderResult {
  const LiveOrderResult({
    this.orderId,
    this.status,
    this.executedQuantity,
    this.failure,
    this.checkedAt,
    this.strategy,
  });
  final String? orderId, status;
  final Decimal? executedQuantity;
  final AccountReadFailure? failure;
  final DateTime? checkedAt;
  final AttachedOrderSnapshot? strategy;
  bool get needsRecheck => orderId == null && strategy == null;
}

class LiveOrderState {
  const LiveOrderState({
    this.context,
    this.intent,
    this.result,
    this.failure,
    this.step = LiveOrderStep.idle,
    this.stale = false,
  });
  final LiveOrderContext? context;
  final LiveOrderIntent? intent;
  final LiveOrderResult? result;
  final AccountReadFailure? failure;
  final LiveOrderStep step;
  final bool stale;
  bool get busy => step != LiveOrderStep.idle;
  bool get needsRecheck => intent != null && result?.needsRecheck == true;
}

abstract interface class LiveOrderRepository {
  Future<LiveOrderContext> read({
    required String address,
    required String symbol,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
    bool includeFunds = true,
  });

  Future<LiveOrderResult> submit({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required bool Function() canSubmit,
    required void Function(LiveOrderStep) onStep,
  });

  Future<LiveOrderResult> recheck({
    required LiveOrderIntent intent,
    required bool Function() isCurrent,
    required void Function(LiveOrderStep) onStep,
  });
}
