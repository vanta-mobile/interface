/// Ordinary V3 orders document only the best opposing or same-side level.
/// Deeper compound-entry pegs have a separate endpoint and enum.
enum LiveOrderPeg {
  counterparty('COUNTERPARTY_1'),
  queue('QUEUE_1');

  const LiveOrderPeg(this.wire);
  final String wire;
}
