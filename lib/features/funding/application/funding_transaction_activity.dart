import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serializes active wallet flows. Abandoned prompts keep their own result
/// handlers, but cannot hold the next explicit operation's lease.
class FundingTransactionActivity {
  Object? _owner;
  bool Function()? _isCurrent;
  bool acquire(Object owner, {required bool Function() isCurrent}) {
    if (_owner != null && (_isCurrent?.call() ?? false)) return false;
    _owner = owner;
    _isCurrent = isCurrent;
    return true;
  }

  void release(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _isCurrent = null;
    }
  }
}

final fundingTransactionActivityProvider = Provider<FundingTransactionActivity>(
  (_) => FundingTransactionActivity(),
);
