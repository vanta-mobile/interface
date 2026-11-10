import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/domain/wallet_operation.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../application/deposit_submission_provider.dart';
import '../application/funding_flow_provider.dart';
import '../application/transfer_history_provider.dart';
import '../domain/deposit_approval.dart' show DepositReceiptStatus;
import '../domain/deposit_submission.dart';
import '../domain/deposit_wallet.dart';
import '../domain/transfer_history.dart';
import '../domain/withdrawal_recovery.dart';
import 'funding_components.dart';
import 'funding_screen.dart';
import 'transfer_history_screen.dart';

class FundingStep {
  const FundingStep(this.title, this.subtitle, {this.done = false, this.active = false});
  final String title, subtitle;
  final bool done, active;
}

class FundingStepsCard extends StatelessWidget {
  const FundingStepsCard({super.key, required this.steps});
  final List<FundingStep> steps;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: PortfolioColors.card, borderRadius: BorderRadius.circular(12)),
    child: Column(
      children: [
        for (final (index, step) in steps.indexed) ...[
          if (index > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: PortfolioColors.line),
            const SizedBox(height: 12),
          ],
          _StepRow(index: index + 1, step: step),
        ],
      ],
    ),
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.step});
  final int index;
  final FundingStep step;
  @override
  Widget build(BuildContext context) {
    final highlighted = step.done || step.active;
    return MergeSemantics(
      child: Row(
        children: [
          SizedBox.square(
            dimension: 26,
            child: Center(
              child: step.done
                  ? SvgPicture.asset('assets/auth/check-circle.svg', width: 16, height: 16)
                  : Text(
                      '$index',
                      style: PortfolioTypography.caption.copyWith(
                        color: step.active ? PortfolioColors.accent : PortfolioColors.secondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: highlighted ? AccountTypography.body : AccountTypography.secondary,
                ),
                const SizedBox(height: 2),
                Text(step.subtitle, style: PortfolioTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Post-submission page: submission is not completion, so it links to records.
class FundingStatusPage extends StatelessWidget {
  const FundingStatusPage({
    super.key,
    required this.title,
    required this.summary,
    required this.children,
    this.onRefresh,
  });
  final String title, summary;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AccountsPage(
      title: l.fundingTransactions,
      showBack: false,
      actions: fundingHeaderActions(context, history: false),
      onRefresh: onRefresh,
      footer: [
        AccountAction(
          key: const Key('funding-view-transactions'),
          label: l.fundingViewTransactions,
          onPressed: () => openTransferHistory(context),
        ),
        const SizedBox(height: 12),
        AccountAction(
          key: const Key('funding-back-portfolio'),
          label: l.accountsBackPortfolio,
          primary: false,
          outlined: true,
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ],
      children: [
        Text(title, style: PortfolioTypography.heading),
        const SizedBox(height: 6),
        Text(summary, style: AccountTypography.secondary),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class DepositProcessingScreen extends ConsumerStatefulWidget {
  const DepositProcessingScreen({super.key, required this.record});
  final DepositSubmissionRecord record;
  @override
  ConsumerState<DepositProcessingScreen> createState() => _DepositProcessingScreenState();
}

class _DepositProcessingScreenState extends ConsumerState<DepositProcessingScreen> {
  // A later failed credit check drops the receipt from controller state; the
  // observed chain success stays shown.
  bool chainSeen = false, creditSeen = false;

  /// Pull rechecks the chain; platform credit is read only via a device grant.
  Future<void> _refresh() async {
    final controller = ref.read(depositSubmissionProvider.notifier), key = widget.record.key;
    if (!chainSeen) return controller.check(key, '');
    if (ref.read(fundingSilentReadsProvider)) await controller.checkCredit(key);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), record = widget.record, asset = record.query.asset;
    ref.watch(depositReceiptWatchProvider);
    ref.watch(depositCreditWatchProvider(record.key));
    final state = ref.watch(depositSubmissionProvider);
    final current = state.record?.key == record.key;
    final credited = creditSeen = creditSeen || current && state.credited;
    final chainDone = chainSeen =
        chainSeen || credited || current && state.receipt?.status == DepositReceiptStatus.succeeded;
    final amount = fundingAmountText(
      depositQuantity(record.amountUnits, asset.decimals).toString(),
      asset.asset,
    );
    return FundingStatusPage(
      title: l.fundingDepositProcessing,
      summary: l.fundingFuturesAmount(amount),
      onRefresh: _refresh,
      children: [
        FundingStepsCard(
          steps: [
            FundingStep(
              chainDone ? l.fundingStepChainConfirmed : l.fundingStepChainPending,
              fundingNetworkName(l, asset.chainId),
              done: chainDone,
              active: !chainDone,
            ),
            FundingStep(
              l.fundingStepCrediting,
              l.fundingStepCreditingHint,
              done: credited,
              active: chainDone && !credited,
            ),
          ],
        ),
        const SizedBox(height: 12),
        FundingGuidance(l.fundingTrackHint),
      ],
    );
  }
}

class WithdrawalStatusScreen extends ConsumerStatefulWidget {
  const WithdrawalStatusScreen({super.key, required this.record});
  final WalletOperationRecord record;
  @override
  ConsumerState<WithdrawalStatusScreen> createState() => _WithdrawalStatusScreenState();
}

class _WithdrawalStatusScreenState extends ConsumerState<WithdrawalStatusScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), record = widget.record;
    ref.watch(withdrawalStatusWatchProvider(record));
    final history = ref.watch(transferHistoryProvider);
    final match = history.account == null ? null : reconcileWithdrawal(record, history.account!);
    final status = history.stale ? null : match?.status;
    final chain = int.tryParse(record.terms['chain'] ?? '') ?? 0;
    final amount = fundingAmountText(record.terms['amount']!, record.terms['asset']!);
    final failed = status == TransferStatus.failed, done = status == TransferStatus.success;
    return FundingStatusPage(
      title: failed
          ? l.fundingWithdrawFailedTitle
          : done
          ? l.fundingWithdrawCompleted
          : l.fundingWithdrawProcessing,
      summary: l.fundingFuturesAmount(amount),
      onRefresh: ref.read(transferHistoryProvider.notifier).refresh,
      children: failed
          ? [
              Container(
                key: const Key('funding-withdraw-failed'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PortfolioColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    AccountValueRow(l.fundingNetworkLabel, fundingNetworkName(l, chain)),
                    const SizedBox(height: 12),
                    AccountValueRow(l.fundingWithdrawalId, record.reference ?? '—', copyable: true),
                    const SizedBox(height: 12),
                    AccountValueRow(
                      l.fundingStatus,
                      l.fundingStatusFailed,
                      color: PortfolioColors.negative,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FundingGuidance(l.fundingWithdrawFailedHint, warning: true),
            ]
          : [
              FundingStepsCard(
                steps: [
                  FundingStep(
                    l.fundingStepNetwork,
                    l.fundingStepNetworkHint,
                    done: done,
                    active: !done,
                  ),
                  FundingStep(
                    l.fundingStepWithdrawCompletion,
                    l.fundingStepWithdrawCompletionHint,
                    done: done,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FundingGuidance(l.fundingTrackHint),
            ],
    );
  }
}
