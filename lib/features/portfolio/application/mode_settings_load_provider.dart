import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import 'futures_asset_mode_provider.dart';
import 'futures_position_mode_provider.dart';

/// Page entry may query with an existing device grant, never open a wallet.
/// Without a grant the sheet offers an explicit read action.
enum AccountModeSetting { asset, position }

final modeSettingsLoadProvider = Provider.autoDispose.family<void, AccountModeSetting>((
  ref,
  setting,
) {
  final auth = ref.watch(authProvider);
  final agent = ref.watch(tradingAgentProvider).asData?.value;
  if (auth.busy || auth.needsWalletConnection || agent?.status != TradingAgentStatus.active) return;
  final identity = auth.identity;
  scheduleMicrotask(() {
    if (!ref.mounted || ref.read(authProvider).identity != identity) return;
    switch (setting) {
      case AccountModeSetting.asset:
        final state = ref.read(futuresAssetModeProvider);
        if (!state.busy && !state.needsRecheck && (state.context == null || state.stale)) {
          unawaited(ref.read(futuresAssetModeProvider.notifier).load());
        }
      case AccountModeSetting.position:
        final state = ref.read(futuresPositionModeProvider);
        if (!state.busy && !state.needsRecheck && (state.context == null || state.stale)) {
          unawaited(ref.read(futuresPositionModeProvider.notifier).load());
        }
    }
  });
});
