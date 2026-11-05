import 'package:decimal/decimal.dart';

import '../domain/account_snapshot.dart';
import '../domain/futures_asset_mode.dart';
import '../domain/live_order.dart';
import '../domain/live_order_funds.dart';
import '../domain/position_margin_mode.dart';
import 'aster_account_mapper.dart';

LiveOrderFunds mapLiveOrderFunds(
  Object? payload, {
  required String address,
  required String symbol,
  required DateTime receivedAt,
  required FuturesAssetMode assetMode,
  required PositionMarginMode marginMode,
  required int leverage,
  required Map<String, LiveOrderPosition> positions,
}) {
  final account = mapAsterAccount(payload, address: address, receivedAt: receivedAt);
  final selected = account.positions.where((p) => p.symbol == symbol).toList();
  if (assetMode == FuturesAssetMode.multi && marginMode == PositionMarginMode.isolated ||
      selected.any((p) => !positions.containsKey(p.side))) {
    throw const AccountReadFailure('liveOrderFundsChanged');
  }
  for (final position in positions.values) {
    final observed = selected.where((p) => p.side == position.side).firstOrNull;
    if ((observed?.quantity ?? Decimal.zero) != position.quantity ||
        position.quantity != Decimal.zero && observed?.entryPrice != position.entryPrice ||
        observed?.leverage != null && observed!.leverage != leverage ||
        observed?.isolated != null &&
            observed!.isolated != (marginMode == PositionMarginMode.isolated)) {
      throw const AccountReadFailure('liveOrderFundsChanged');
    }
  }
  return LiveOrderFunds(account: account, assetMode: assetMode);
}
