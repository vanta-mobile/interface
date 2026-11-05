import '../../funding/domain/transfer_history.dart';

/// The source has no status-update timestamp or documented transition order.
/// Retain every observed state even after its notification is pruned.
class TransferObservation {
  TransferObservation(this.record, Iterable<TransferStatus> states)
    : states = Set.unmodifiable(states);
  final TransferRecord record;
  final Set<TransferStatus> states;
}
