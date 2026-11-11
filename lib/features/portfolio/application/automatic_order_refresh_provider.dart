import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../market/application/market_providers.dart';
import '../../market/application/selection_providers.dart';
import 'live_order_provider.dart';
import 'main_order_refresh_provider.dart';
import 'symbol_settings_activity.dart';

/// Read once per wallet/symbol after a usable trading grant is available.
/// Failures require manual refresh; lifecycle and quote events never retry them.
final automaticOrderRefreshProvider = Provider<void>((ref) {
  final attempted = <(String, String, String, String)>{};
  var scheduled = false;
  void inspect() {
    if (scheduled) return;
    scheduled = true;
    scheduleMicrotask(() {
      scheduled = false;
      if (!ref.mounted) return;
      final auth = ref.read(authProvider), identity = auth.identity;
      final agent = ref.read(tradingAgentProvider).asData?.value;
      if (identity == null) {
        attempted.clear();
        return;
      }
      final activity = ref.read(symbolSettingsActivityProvider);
      final live = ref.read(liveOrderProvider);
      if (auth.busy ||
          auth.failure != null ||
          !identity.signingAvailable ||
          identity.walletAddress == null ||
          agent?.status != TradingAgentStatus.active ||
          agent!.identityId != identity.id ||
          agent.owner.toLowerCase() != identity.walletAddress!.toLowerCase() ||
          !agent.expiresAt.isAfter(ref.read(tradingAgentClockProvider)()) ||
          !ref.read(quoteUpdatesActiveProvider) ||
          activity.owner != null ||
          activity.recoveryBlocked ||
          activity.unresolved ||
          live.busy ||
          live.needsRecheck ||
          ref.read(mainOrderRefreshProvider).loading) {
        return;
      }
      final symbol = ref.read(symbolProvider);
      final key = (identity.id, identity.walletAddress!.toLowerCase(), agent.address, symbol);
      if (!attempted.add(key)) return;
      unawaited(ref.read(mainOrderRefreshProvider.notifier).refresh(symbol));
    });
  }

  ref.listen(authProvider, (_, _) => inspect());
  ref.listen(tradingAgentProvider, (_, _) => inspect());
  ref.listen(symbolProvider, (_, _) => inspect());
  ref.listen(symbolSettingsActivityProvider, (_, _) => inspect());
  ref.listen(quoteUpdatesActiveProvider, (_, _) => inspect());
  ref.listen(mainOrderRefreshProvider, (_, _) => inspect());
  inspect();
});
