import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../authorization/presentation/enable_trading_screen.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import 'mode_settings_sheet.dart';

/// What the account still needs before futures settings can be read and changed.
enum ModeAccess { checking, signIn, createWallet, reconnect, enableTrading, ready }

final modeAccessProvider = Provider.autoDispose<ModeAccess>((ref) {
  final auth = ref.watch(authProvider), identity = auth.identity;
  if (auth.busy) return ModeAccess.checking;
  if (identity == null) return ModeAccess.signIn;
  if (identity.walletAddress == null) return ModeAccess.createWallet;
  if (!identity.signingAvailable) return ModeAccess.reconnect;
  final agent = ref.watch(tradingAgentProvider);
  if (!agent.hasValue) return agent.hasError ? ModeAccess.enableTrading : ModeAccess.checking;
  return agent.value?.status == TradingAgentStatus.active
      ? ModeAccess.ready
      : ModeAccess.enableTrading;
});

/// The sheet's bottom action: [ready] once trading is enabled, otherwise the
/// step that enables it (sign in, wallet, or the trading authorization page).
class ModeAccessAction extends ConsumerWidget {
  const ModeAccessAction({super.key, required this.ready});
  final Widget ready;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final access = ref.watch(modeAccessProvider);
    if (access == ModeAccess.ready) return ready;
    return ModeAction(
      key: const Key('mode-access-action'),
      large: true,
      busy: access == ModeAccess.checking,
      label: switch (access) {
        ModeAccess.createWallet => l.createWallet,
        ModeAccess.enableTrading => l.enableTradingTitle,
        _ => l.connect,
      },
      onPressed: access == ModeAccess.enableTrading
          ? () =>
                Navigator.of(context)
                    .push<void>(MaterialPageRoute(builder: (_) => const EnableTradingScreen()))
          : () => showAccountSheet(context),
    );
  }
}
