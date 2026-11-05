import 'live_order_draft.dart';

/// Preferences describe the opening form mode, independent of direction,
/// trigger STOP/TAKE_PROFIT choice and optional entry pricing/protection.
enum OrderConfirmationKind { limit, market, stopLimit, stopMarket, trailing }

OrderConfirmationKind orderConfirmationKind(LiveOrderDraft draft) => draft.trailing != null
    ? OrderConfirmationKind.trailing
    : draft.trigger != null
    ? draft.market
          ? OrderConfirmationKind.stopMarket
          : OrderConfirmationKind.stopLimit
    : draft.market
    ? OrderConfirmationKind.market
    : OrderConfirmationKind.limit;
