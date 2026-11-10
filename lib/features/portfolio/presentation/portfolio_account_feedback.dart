import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../authorization/presentation/enable_trading_screen.dart';
import '../application/account_read_provider.dart';
import '../domain/account_snapshot.dart';

class PortfolioAccountFeedback extends ConsumerWidget {
  const PortfolioAccountFeedback({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountReadProvider);
    final agent = ref.watch(tradingAgentProvider);
    final l = AppLocalizations.of(context);
    final needsGrant = !agent.isLoading && agent.asData?.value?.status != TradingAgentStatus.active;
    final failure =
        account.failure ??
        (agent.hasError
            ? agent.error is AccountReadFailure
                  ? agent.error as AccountReadFailure
                  : const AccountReadFailure('authorizationSecureStorageFailed')
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account.account == null && (account.busy || agent.isLoading))
          Padding(
            key: const Key('portfolio-account-loading'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(label: l.accountReadLoading, child: const LinearProgressIndicator()),
          ),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              accountErrorText(context, failure),
              key: const Key('account-read-error'),
              style: const TextStyle(color: AppColors.negative),
            ),
          ),
        if (needsGrant && !agent.hasError) ...[
          if (failure == null)
            Text(
              tr(
                context,
                agent.asData?.value?.status == TradingAgentStatus.unknown
                    ? 'authorizationUnknown'
                    : 'authorizationRequired',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          TextButton(
            key: const Key('portfolio-enable-trading'),
            onPressed: () =>
                Navigator.of(context)
                    .push<void>(MaterialPageRoute(builder: (_) => const EnableTradingScreen())),
            child: Text(l.enableTradingTitle),
          ),
        ],
      ],
    );
  }
}
