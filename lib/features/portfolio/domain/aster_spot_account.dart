import 'package:decimal/decimal.dart';

import 'account_snapshot.dart';

/// Asset quantities only. The account endpoint supplies no USD/BTC valuation.
class AsterSpotAccount implements WalletAccountSnapshot {
  AsterSpotAccount({
    required this.address,
    required this.receivedAt,
    required Iterable<AsterSpotBalance> balances,
  }) : balances = List.unmodifiable(balances);
  @override
  final String address;
  @override
  final DateTime receivedAt;
  final List<AsterSpotBalance> balances;
}

class AsterSpotBalance {
  const AsterSpotBalance({required this.asset, required this.free, required this.locked});
  final String asset;
  final Decimal free, locked;
  Decimal get total => free + locked;
}

typedef SpotAccountReadState = AccountSnapshotState<AsterSpotAccount>;
typedef AsterSpotAccountRepository = WalletAccountRepository<AsterSpotAccount>;
