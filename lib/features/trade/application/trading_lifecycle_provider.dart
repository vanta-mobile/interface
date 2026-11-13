import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../market/application/market_providers.dart';
import '../../portfolio/application/account_read_provider.dart';
import '../../portfolio/application/live_order_provider.dart';
import '../../portfolio/application/open_orders_provider.dart';
import '../../portfolio/application/position_risk_provider.dart';
import '../../portfolio/application/spot_account_provider.dart';
import '../../portfolio/application/spot_history_provider.dart';
import '../../portfolio/application/symbol_settings_activity.dart';

final tradingLifecycleProvider = Provider.autoDispose<TradingLifecycle>((ref) {
  final lifecycle = TradingLifecycle(ref);
  ref.listen(symbolSettingsActivityProvider.select((s) => s.busy), (_, _) {
    lifecycle.scheduleSessionRefresh();
  });
  ref.listen(authProvider, (_, _) => lifecycle.scheduleSessionRefresh());
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});

/// Coordinates native lifecycle intents without interrupting a wallet prompt.
/// Identity events still arrive immediately through the auth repository.
class TradingLifecycle {
  TradingLifecycle(this.ref);
  final Ref ref;
  bool _foreground = true, _pending = false, _scheduled = false, _disposed = false;

  void onChanged(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(accountReadProvider.notifier).markStale();
      ref.read(positionRiskProvider.notifier).markStale();
      ref.read(spotAccountReadProvider.notifier).markStale();
      ref.read(spotHistoryProvider.notifier).markStale();
      ref.read(openOrdersReadProvider.notifier).markStale();
      ref.read(liveOrderProvider.notifier).onLifecycleChanged();
    }
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      ref.read(quoteUpdatesActiveProvider.notifier).setActive(true);
      _pending = true;
      scheduleSessionRefresh();
      ref.read(marketSyncProvider)?.reconnect();
      ref.invalidate(asterBookProvider);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      ref.read(quoteUpdatesActiveProvider.notifier).setActive(false);
    } else if (state == AppLifecycleState.inactive) {
      _foreground = false;
    }
  }

  void scheduleSessionRefresh() {
    if (_disposed || !_pending || _scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (_disposed || !_pending || !_foreground) return;
      final auth = ref.read(authProvider);
      if (auth.identity == null) {
        _pending = false;
        return;
      }
      if (auth.busy || ref.read(symbolSettingsActivityProvider).busy) return;
      _pending = false;
      unawaited(ref.read(authProvider.notifier).refreshSession());
    });
  }

  void dispose() => _disposed = true;
}
