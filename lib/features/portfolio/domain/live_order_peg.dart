/// Ordinary V3 orders document only the best opposing or same-side level.
/// Deeper compound-entry pegs have a separate endpoint and enum.
enum LiveOrderPeg {
  counterparty('COUNTERPARTY_1'),
  queue('QUEUE_1');

  const LiveOrderPeg(this.wire);
  final String wire;

  /// Buy counterparty/sell queue read ask; buy queue/sell counterparty read bid.
  /// This is a current preview, never the engine's future resolved limit.
  bool usesAsk(bool buy) => buy == (this == counterparty);
}
