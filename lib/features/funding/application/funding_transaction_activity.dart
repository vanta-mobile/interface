import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared across routes, wallets and session changes. Only explicit native
/// transaction workflows acquire it; a wallet prompt may outlive its screen.
class FundingTransactionActivity {
  Object? _owner;
  bool acquire(Object owner) {
    if (_owner != null) return false;
    _owner = owner;
    return true;
  }

  void release(Object owner) {
    if (identical(_owner, owner)) _owner = null;
  }
}

final fundingTransactionActivityProvider = Provider<FundingTransactionActivity>(
  (_) => FundingTransactionActivity(),
);
