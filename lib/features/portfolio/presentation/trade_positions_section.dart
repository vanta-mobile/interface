import 'embedded_order_feedback.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/application/providers.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/batch_close_provider.dart';
import '../application/position_risk_provider.dart';
import '../application/positions_auto_read_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/position_risk.dart';
import 'batch_close_controls.dart';
import 'account_position_card.dart';
import 'trade_check_option.dart';
import '../../../core/theme.dart' show PressFeedback;

/// Positions tab beneath the Futures trade workspace.
class TradePositionsSection extends ConsumerStatefulWidget {
  const TradePositionsSection({super.key});
  @override
  ConsumerState<TradePositionsSection> createState() => _TradePositionsSectionState();
}

class _TradePositionsSectionState extends ConsumerState<TradePositionsSection> {
  bool currentSymbolOnly = false;

  /// Keeps the failure state (with its spinning Retry) in place while the
  /// retried read runs; the controller clears the failure when a read starts.
  AccountReadFailure? retrying;

  Future<void> retry() async {
    setState(() => retrying = ref.read(positionRiskProvider).failure);
    try {
      await ref.read(positionRiskProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => retrying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(positionsAutoReadProvider);
    final state = ref.watch(positionRiskProvider);
    // An account Aster has not opened yet (no deposit) has no positions.
    final depositRequired = state.failure?.requiresDeposit == true;
    final failure = depositRequired ? null : state.failure;
    final symbol = ref.watch<String>(symbolProvider);
    final all =
        state.account?.positions.where((p) => !p.balanceOnly).toList() ??
        (depositRequired ? const <PositionRisk>[] : null);
    final positions = all?.where((p) => !currentSymbolOnly || p.symbol == symbol).toList();
    final scope = currentSymbolOnly ? symbol : null;
    // Watch everything batch-close preparation reads so the action stays current.
    ref.watch(authProvider);
    ref.watch(batchCloseProvider);
    ref.watch(symbolSettingsActivityProvider);
    final canCloseAll =
        positions?.isNotEmpty == true &&
        ref.read(batchCloseProvider.notifier).prepare(symbol: scope) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TradeCheckOption(
                label: l10n.openOrdersCurrentSymbol,
                tapKey: const Key('positions-current-symbol'),
                value: currentSymbolOnly,
                onChanged: (value) => setState(() => currentSymbolOnly = value),
              ),
            ),
            TextButton(
              key: const Key('close-all-positions'),
              onPressed: canCloseAll ? () => confirmBatchClose(context, ref, symbol: scope) : null,
              style: TextButton.styleFrom(
                foregroundColor: TradeColors.negative,
                disabledForegroundColor: TradeColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(44, 44),
                textStyle: TradeTypography.body,
              ).copyWith(overlayColor: PressFeedback.overlay),
              // The confirmed close shows progress here; its outcome is a toast.
              child: ref.watch(batchCloseProvider).busy
                  ? const SizedBox.square(
                      key: Key('close-all-positions-loading'),
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.positionsCloseAll),
            ),
          ],
        ),
        // A missing or revoked device grant (e.g. "No agent found") leads to
        // Enable trading, as AGENTS.md requires, instead of a bare retry.
        if (failure case final failure? when failure.requiresAuthorization)
          EmbeddedOrderFailure(failure: failure, retry: retry, loading: state.busy)
        else if ((all == null ? failure ?? retrying : null) case final failure?)
          StatusFailureView(
            message: accountErrorText(context, failure),
            retrying: state.busy,
            onRetry: retry,
          )
        // A failed refresh keeps the shown data without an error line; the
        // next read replaces it.
        else if (all == null && state.busy)
          const Padding(
            key: Key('positions-skeleton'),
            padding: EdgeInsets.only(top: 16),
            child: SkeletonBox(height: 360, radius: 20),
          ),
        if (positions != null && positions.isEmpty)
          StatusEmptyView(
            key: const Key('positions-empty'),
            message: currentSymbolOnly && all!.isNotEmpty
                ? l10n.positionRiskNoCurrent
                : l10n.accountNoPositions,
          ),
        for (final position in positions ?? const <PositionRisk>[])
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AccountPositionCard(position: position),
          ),
      ],
    );
  }
}
