import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../authorization/presentation/enable_trading_screen.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/transfer_history_provider.dart';
import 'transfer_history_skeleton.dart';

class TransferHistoryFeedback extends ConsumerWidget {
  const TransferHistoryFeedback({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(transferHistoryProvider);
    final auth = ref.watch(authProvider);
    final agent = ref.watch(tradingAgentProvider);
    final needsGrant = !agent.isLoading && agent.asData?.value?.status != TradingAgentStatus.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.account == null && (state.busy || agent.isLoading))
          Semantics(
            label: l.accountReadLoading,
            child: const TransferHistorySkeleton(key: Key('transfer-history-loading')),
          ),
        if (state.failure case final failure? when !failure.requiresDeposit)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              accountErrorText(context, failure),
              key: const Key('transfer-history-error'),
              style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
            ),
          ),
        if (agent.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(l.authorizationSecureStorageFailed, style: PortfolioTypography.caption),
          ),
        if (auth.needsWalletConnection || needsGrant && !agent.hasError)
          TextButton(
            key: const Key('transfer-history-enable'),
            onPressed: auth.busy
                ? null
                : auth.needsWalletConnection
                ? () => showAccountSheet(context)
                : () => Navigator.of(context)
                      .push<void>(MaterialPageRoute(builder: (_) => const EnableTradingScreen())),
            child: Text(auth.needsWalletConnection ? l.portfolioLogIn : l.enableTradingTitle),
          ),
      ],
    );
  }
}
