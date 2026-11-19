import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_details.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../../subaccounts/application/account_entries_provider.dart';
import '../../subaccounts/presentation/account_components.dart';
import '../application/deposit_approval_provider.dart';
import '../application/deposit_submission_provider.dart';
import '../application/withdrawal_provider.dart';
import '../domain/deposit_wallet.dart';
import 'funding_components.dart';
import 'funding_screen.dart';
import 'funding_selection.dart';
import 'funding_status_screens.dart';

/// "Confirm in wallet" step. Open wallet dispatches the prepared request;
/// Cancel stops waiting without claiming the wallet dialog was dismissed.
class FundingWalletPage extends ConsumerWidget {
  const FundingWalletPage({
    super.key,
    required this.title,
    required this.summary,
    required this.hint,
    required this.busy,
    required this.onOpen,
    required this.onCancel,
    this.detail,
  });
  final String title, summary, hint;

  /// Shown below the summary, such as an entered withdrawal destination.
  final Widget? detail;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return AccountsPage(
      title: l.fundingAccountTitle,
      showBack: false,
      onBack: onCancel,
      actions: [
        IconButton(
          key: const Key('accounts-close'),
          tooltip: tr(context, 'close'),
          onPressed: onCancel,
          icon: const PortfolioIcon('close.svg', size: 24),
        ),
      ],
      footer: [
        AccountAction(
          fadeDisabled: true,
          key: const Key('funding-open-wallet'),
          label: l.fundingOpenWallet,
          busy: busy,
          onPressed: onOpen,
        ),
        const SizedBox(height: 12),
        AccountAction(
          key: const Key('funding-wallet-cancel'),
          label: tr(context, 'cancel'),
          primary: false,
          outlined: true,
          onPressed: onCancel,
        ),
      ],
      children: [
        Text(title, style: PortfolioTypography.heading),
        const SizedBox(height: 6),
        Text(summary, style: AccountTypography.secondary),
        if (detail case final widget?) ...[const SizedBox(height: 12), widget],
        const SizedBox(height: 12),
        Text(
          fundingAccountText(l, ref.watch(activeAccountEntryProvider)),
          style: FundingTypography.note,
        ),
        const SizedBox(height: 12),
        FundingGuidance(hint, style: FundingTypography.note),
      ],
    );
  }
}

class DepositConfirmScreen extends ConsumerStatefulWidget {
  const DepositConfirmScreen({super.key, required this.review});
  final DepositSubmissionReview review;
  @override
  ConsumerState<DepositConfirmScreen> createState() => _DepositConfirmScreenState();
}

class _DepositConfirmScreenState extends ConsumerState<DepositConfirmScreen> {
  bool closing = false;
  void _cancel() {
    if (closing) return;
    closing = true;
    final controller = ref.read(depositSubmissionProvider.notifier);
    ref.read(depositSubmissionProvider).busy ? controller.stop() : controller.cancel(widget.review);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), review = widget.review;
    final state = ref.watch(depositSubmissionProvider);
    ref.listen(depositSubmissionProvider, (before, after) {
      if (closing || before?.busy != true || after.busy) return;
      closing = true;
      if (after.record case final record? when after.failure == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => DepositProcessingScreen(record: record)),
        );
      } else {
        Navigator.pop(context, _walletError(after.failure, after.errorDetails));
      }
    });
    final amount = fundingAmountText(review.amount, review.query.asset.asset);
    return FundingWalletPage(
      title: l.fundingConfirmDepositTitle,
      summary: l.fundingFuturesAmount(amount),
      hint: l.fundingConfirmDepositHint,
      busy: state.busy,
      onOpen: identical(state.review, review) && !state.busy
          ? () => unawaited(ref.read(depositSubmissionProvider.notifier).confirm(review))
          : null,
      onCancel: _cancel,
    );
  }
}

class ApprovalConfirmScreen extends ConsumerStatefulWidget {
  const ApprovalConfirmScreen({super.key, required this.review});
  final DepositApprovalReview review;
  @override
  ConsumerState<ApprovalConfirmScreen> createState() => _ApprovalConfirmScreenState();
}

class _ApprovalConfirmScreenState extends ConsumerState<ApprovalConfirmScreen> {
  bool closing = false;
  void _cancel() {
    if (closing) return;
    closing = true;
    final controller = ref.read(depositApprovalProvider.notifier);
    ref.read(depositApprovalProvider).busy ? controller.stop() : controller.cancel(widget.review);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), review = widget.review;
    final state = ref.watch(depositApprovalProvider), asset = review.query.asset.asset;
    ref.listen(depositApprovalProvider, (before, after) {
      if (closing || before?.busy != true || after.busy) return;
      closing = true;
      // A sent approval returns to the form, which waits for its receipt.
      Navigator.pop(
        context,
        after.record != null && after.failure == null
            ? null
            : _walletError(after.failure, after.errorDetails),
      );
    });
    return FundingWalletPage(
      title: l.fundingApproveTitle(asset),
      summary: l.fundingApproveSummary,
      hint: l.fundingApproveHint(asset),
      busy: state.busy,
      onOpen: identical(state.review, review) && !state.busy
          ? () => unawaited(ref.read(depositApprovalProvider.notifier).confirm(review))
          : null,
      onCancel: _cancel,
    );
  }
}

class WithdrawConfirmScreen extends ConsumerStatefulWidget {
  const WithdrawConfirmScreen({
    super.key,
    required this.query,
    required this.amount,
    required this.shownFee,
    this.receiver,
  });
  final DepositWalletQuery query;
  final String amount;
  final Decimal shownFee;

  /// Entered destination; null withdraws to the signing wallet itself.
  final String? receiver;
  @override
  ConsumerState<WithdrawConfirmScreen> createState() => _WithdrawConfirmScreenState();
}

class _WithdrawConfirmScreenState extends ConsumerState<WithdrawConfirmScreen> {
  bool closing = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(withdrawalProvider.notifier).cancel();
    });
  }

  void _cancel() {
    if (closing) return;
    closing = true;
    if (ref.read(withdrawalProvider).busy) ref.read(withdrawalProvider.notifier).stop();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), state = ref.watch(withdrawalProvider);
    // The fee check fails between prepare and confirm without a busy phase.
    ref.listen(withdrawalProvider, (before, after) {
      if (closing || after.busy) return;
      if (after.result case final record?) {
        closing = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => WithdrawalStatusScreen(record: record)),
        );
      } else if (after.failure != null) {
        closing = true;
        Navigator.pop(context, _walletError(after.failure, after.errorDetails));
      }
    });
    final amount = fundingAmountText(widget.amount, widget.query.asset.asset);
    return FundingWalletPage(
      title: l.fundingConfirmWithdrawTitle,
      summary: l.fundingFuturesAmount(amount),
      hint: l.fundingConfirmWithdrawHint,
      detail: widget.receiver == null
          ? null
          : AccountValueRow(
              l.withdrawalReceiver,
              widget.receiver!,
              key: const Key('funding-confirm-receiver'),
              copyable: true,
            ),
      busy: state.busy || state.review != null,
      onOpen: state.busy || state.review != null
          ? null
          : () => unawaited(
              ref
                  .read(withdrawalProvider.notifier)
                  .submit(
                    widget.query,
                    widget.amount,
                    shownFee: widget.shownFee,
                    receiver: widget.receiver,
                  ),
            ),
      onCancel: _cancel,
    );
  }
}

FundingActionError? _walletError(String? key, ApiErrorDetails? details) =>
    key == null ? null : FundingActionError(key, details);

/// A step that ended with neither a sent request nor a failure still explains
/// why nothing happened: another wallet request held it.
FundingActionError _outcome(String? key, ApiErrorDetails? details, String fallback) =>
    _walletError(key, details) ?? FundingActionError(fallback);

/// Privy embedded wallets sign inside the app without a wallet prompt, so the
/// "Confirm in wallet" page is skipped and the form's button sends directly.
bool fundingSignsInApp(WidgetRef ref) =>
    ref.read(authProvider).identity?.walletKind == WalletKind.embedded;

/// [ApprovalConfirmScreen]'s step without the page. Null once the approval is
/// sent; the form then waits for its receipt.
Future<FundingActionError?> confirmApprovalInApp(
  BuildContext context,
  WidgetRef ref,
  DepositApprovalReview review,
) async {
  await ref.read(depositApprovalProvider.notifier).confirm(review);
  if (!context.mounted) return null;
  final after = ref.read(depositApprovalProvider);
  if (after.record != null && after.failure == null) return null;
  return _outcome(after.failure, after.errorDetails, 'depositTransactionBusy');
}

/// [DepositConfirmScreen]'s step without the page; a sent deposit opens its
/// processing page.
Future<FundingActionError?> confirmDepositInApp(
  BuildContext context,
  WidgetRef ref,
  DepositSubmissionReview review,
) async {
  await ref.read(depositSubmissionProvider.notifier).confirm(review);
  if (!context.mounted) return null;
  final after = ref.read(depositSubmissionProvider);
  if (after.record case final record? when after.failure == null) {
    unawaited(
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => DepositProcessingScreen(record: record))),
    );
    return null;
  }
  return _outcome(after.failure, after.errorDetails, 'depositTransactionBusy');
}

/// [WithdrawConfirmScreen]'s step without the page; a sent withdrawal opens
/// its status page.
Future<FundingActionError?> submitWithdrawalInApp(
  BuildContext context,
  WidgetRef ref, {
  required DepositWalletQuery query,
  required String amount,
  required Decimal shownFee,
  String? receiver,
}) async {
  final controller = ref.read(withdrawalProvider.notifier)..cancel();
  await controller.submit(query, amount, shownFee: shownFee, receiver: receiver);
  if (!context.mounted) return null;
  final after = ref.read(withdrawalProvider);
  if (after.result case final record?) {
    unawaited(
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => WithdrawalStatusScreen(record: record))),
    );
    return null;
  }
  return _outcome(after.failure, after.errorDetails, 'authWalletBusy');
}
