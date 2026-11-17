import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/market_providers.dart' show quoteUpdatesActiveProvider;

enum SymbolSetting {
  leverage,
  marginMode,
  positionMargin,
  positionMode,
  assetMode,
  order,
  batchClose,
  scaled,
  recovery,
  rebalance,
  internalTransfer,
}

/// Account operations in progress. Independent operations run concurrently;
/// only the same action disables itself while it is pending. [epoch] counts
/// dispatched writes so reads taken before another write can be marked stale.
class SymbolSettingsActivity {
  SymbolSettingsActivity({Map<int, SymbolSetting> running = const {}, this.epoch = 0})
    : running = Map.unmodifiable(running);
  final Map<int, SymbolSetting> running;
  final int epoch;
  bool get busy => running.isNotEmpty;
  bool isRunning(SymbolSetting setting) => running.containsValue(setting);
  bool holds(int lease) => running.containsKey(lease);
}

final symbolSettingsActivityProvider =
    NotifierProvider<SymbolSettingsActivityController, SymbolSettingsActivity>(
      SymbolSettingsActivityController.new,
    );

/// A wallet prompt can background the app without ending its active order.
/// Keep existing public/private connections; their expiry and event guards
/// remain authoritative if the OS suspends delivery or the connection drops.
final orderSessionActiveProvider = Provider.autoDispose<bool>((ref) {
  final foreground = ref.watch(quoteUpdatesActiveProvider);
  final operation = ref.watch(symbolSettingsActivityProvider);
  return orderSessionActive(foreground, operation);
});

bool orderSessionActive(bool foreground, SymbolSettingsActivity operation) =>
    foreground || operation.isRunning(SymbolSetting.order);

class SymbolSettingsActivityController extends Notifier<SymbolSettingsActivity> {
  int _token = 0, _epoch = 0;
  Object? _identityKey;

  @override
  SymbolSettingsActivity build() {
    final identityKey = ref.watch(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
    );
    // Another account never inherits leases; its reads start a new epoch.
    if (_identityKey != null && _identityKey != identityKey) _epoch++;
    _identityKey = identityKey;
    return SymbolSettingsActivity(epoch: _epoch);
  }

  /// Registers an operation; never refused because another one is running.
  int acquire(SymbolSetting owner) {
    final lease = ++_token;
    state = SymbolSettingsActivity(running: {...state.running, lease: owner}, epoch: _epoch);
    return lease;
  }

  /// A write was dispatched: reads taken before it are no longer current.
  void submitted(int lease) {
    if (!ref.mounted || !state.holds(lease)) return;
    state = SymbolSettingsActivity(running: state.running, epoch: ++_epoch);
  }

  void finish(int lease) {
    if (!ref.mounted || !state.holds(lease)) return;
    state = SymbolSettingsActivity(running: {...state.running}..remove(lease), epoch: _epoch);
  }
}
