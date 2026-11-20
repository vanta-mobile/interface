import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../authorization/domain/trading_agent.dart';
import '../../authorization/presentation/enable_trading_screen.dart';
import '../domain/account_snapshot.dart';

/// Account read feedback stays within the form; public quotes remain visible.
class EmbeddedOrderFailure extends ConsumerWidget {
  const EmbeddedOrderFailure({
    super.key,
    required this.failure,
    required this.retry,
    required this.loading,
  });
  final AccountReadFailure failure;
  final Future<void> Function() retry;
  final bool loading;
  @override
  Widget build(BuildContext context, WidgetRef ref) => StatusFailureView(
    message: accountErrorText(context, failure),
    retryLabel: failure.requiresAuthorization
        ? AppLocalizations.of(context).enableTradingTitle
        : null,
    onRetry: !failure.requiresAuthorization
        ? retry
        : () async {
            final previous = ref.read(tradingAgentProvider).asData?.value;
            await Navigator.of(context)
                .push<void>(MaterialPageRoute(builder: (_) => const EnableTradingScreen()));
            if (!context.mounted) return;
            final current = ref.read(tradingAgentProvider).asData?.value;
            if (current?.status == TradingAgentStatus.active &&
                (previous?.status != TradingAgentStatus.active ||
                    previous?.address != current?.address)) {
              await retry();
            }
          },
    retrying: loading,
    retryKey: const Key('trade-order-retry'),
    padding: const EdgeInsets.symmetric(vertical: 24),
  );
}
