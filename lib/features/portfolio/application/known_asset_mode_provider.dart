import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/futures_asset_mode.dart';
import 'futures_asset_mode_provider.dart';
import 'live_order_provider.dart';
import 'main_order_capacity_provider.dart';

/// The newest account asset mode (single / multi-asset) already read for a
/// wallet by the order form, its capacity read or the asset-mode settings.
/// Never reads by itself; null until one of those reads exists.
final knownAssetModeProvider = Provider<({String address, FuturesAssetMode mode})?>((ref) {
  final funds = ref.watch(liveOrderProvider.select((s) => s.context?.funds));
  final capacity = ref.watch(mainOrderCapacityProvider.select((s) => s.snapshot));
  final setting = ref.watch(futuresAssetModeProvider.select((s) => s.context));
  ({String address, FuturesAssetMode mode, DateTime at})? newest;
  for (final read in [
    if (funds != null)
      (address: funds.account.address, mode: funds.assetMode, at: funds.account.receivedAt),
    if (capacity != null)
      (address: capacity.context.address, mode: capacity.assetMode, at: capacity.receivedAt),
    if (setting != null) (address: setting.address, mode: setting.current, at: setting.receivedAt),
  ]) {
    if (newest == null || read.at.isAfter(newest.at)) newest = read;
  }
  return newest == null ? null : (address: newest.address, mode: newest.mode);
});
