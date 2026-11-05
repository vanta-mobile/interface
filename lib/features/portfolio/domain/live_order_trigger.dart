enum LiveOrderTriggerKind { stop, takeProfit }

enum LiveOrderTriggerBasis {
  last('CONTRACT_PRICE'),
  mark('MARK_PRICE');

  const LiveOrderTriggerBasis(this.wire);
  final String wire;
}

/// A single independent conditional order, not a bracket or OCO strategy.
class LiveOrderTrigger {
  const LiveOrderTrigger({
    required this.kind,
    required this.price,
    this.basis = LiveOrderTriggerBasis.last,
    this.protect = false,
  });

  final LiveOrderTriggerKind kind;
  final LiveOrderTriggerBasis basis;
  final String price;
  final bool protect;

  bool rises(bool buy) => (kind == LiveOrderTriggerKind.stop) == buy;
  String orderType({required bool market}) =>
      '${kind == LiveOrderTriggerKind.stop ? 'STOP' : 'TAKE_PROFIT'}${market ? '_MARKET' : ''}';
}
