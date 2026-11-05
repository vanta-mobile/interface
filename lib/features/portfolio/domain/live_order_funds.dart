import 'aster_account.dart';
import 'futures_asset_mode.dart';

/// Account amounts retain their original asset units. The documented account
/// availableBalance is USDT-only, not a total of multi-asset collateral.
class LiveOrderFunds {
  const LiveOrderFunds({required this.account, required this.assetMode});
  final AsterAccount account;
  final FuturesAssetMode assetMode;
}
