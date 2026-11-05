/// Compound entries document these ten peg values. Ordinary orders use
/// LiveOrderPeg and support only level one, under their own contract.
enum AttachedEntryPeg {
  counterparty1('COUNTERPARTY_1', 1, true),
  counterparty3('COUNTERPARTY_3', 3, true),
  counterparty5('COUNTERPARTY_5', 5, true),
  counterparty10('COUNTERPARTY_10', 10, true),
  counterparty20('COUNTERPARTY_20', 20, true),
  queue1('QUEUE_1', 1, false),
  queue3('QUEUE_3', 3, false),
  queue5('QUEUE_5', 5, false),
  queue10('QUEUE_10', 10, false),
  queue20('QUEUE_20', 20, false);

  const AttachedEntryPeg(this.wire, this.depth, this.counterparty);
  final String wire;
  final int depth;
  final bool counterparty;
}
