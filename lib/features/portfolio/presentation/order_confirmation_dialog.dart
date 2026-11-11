import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/account_snapshot.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';
import 'order_confirmation_terms.dart';

enum OrderSubmissionKind { success, failed, unknown, notSubmitted }

/// Observed outcome of one confirmation attempt. Display text never decides
/// financial success or retry safety.
class OrderSubmissionOutcome {
  const OrderSubmissionOutcome(this.kind, [this.failure]);
  final OrderSubmissionKind kind;
  final AccountReadFailure? failure;
}

/// Centered order confirmation from the mobile Futures design. The confirm
/// button stays busy until the submission settles; only a verified success
/// closes the dialog.
class OrderConfirmationDialog extends StatefulWidget {
  const OrderConfirmationDialog({
    super.key,
    required this.intent,
    required this.submit,
    this.sizing,
    this.ready = true,
    this.submitWhileUpdating = false,
    this.failure,
  });
  final LiveOrderIntent intent;
  final OrderSizeResolution? sizing;
  final bool ready;
  final bool submitWhileUpdating;
  final AccountReadFailure? failure;
  final Future<OrderSubmissionOutcome> Function() submit;

  @override
  State<OrderConfirmationDialog> createState() => _OrderConfirmationDialogState();
}

class _OrderConfirmationDialogState extends State<OrderConfirmationDialog> {
  bool _pending = false;
  late LiveOrderIntent _displayedIntent = widget.intent;
  OrderSizeResolution? _displayedSizing;

  Future<void> _confirm() async {
    if (_pending || !widget.ready && !widget.submitWhileUpdating) return;
    setState(() => _pending = true);
    OrderSubmissionOutcome outcome;
    try {
      outcome = await widget.submit();
    } on AccountReadFailure catch (failure) {
      outcome = OrderSubmissionOutcome(OrderSubmissionKind.failed, failure);
    } catch (_) {
      outcome = const OrderSubmissionOutcome(
        OrderSubmissionKind.failed,
        AccountReadFailure('accountReadFailed'),
      );
    }
    if (!mounted) return;
    setState(() => _pending = false);
    final l10n = AppLocalizations.of(context);
    switch (outcome.kind) {
      case OrderSubmissionKind.success:
        AppToast.showSuccess(context, l10n.orderConfirmSubmitted);
        Navigator.pop(context);
      case OrderSubmissionKind.unknown:
        AppToast.showFailure(
          context,
          outcome.failure == null
              ? l10n.liveOrderOutcomeUnknown
              : accountErrorText(context, outcome.failure!),
        );
      case OrderSubmissionKind.failed:
        AppToast.showFailure(
          context,
          accountErrorText(
            context,
            outcome.failure ?? const AccountReadFailure('accountReadFailed'),
          ),
        );
      case OrderSubmissionKind.notSubmitted:
        AppToast.showFailure(
          context,
          outcome.failure == null
              ? l10n.orderConfirmExpired
              : accountErrorText(context, outcome.failure!),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ready) {
      _displayedIntent = widget.intent;
      _displayedSizing = widget.sizing;
    }
    final l10n = AppLocalizations.of(context), draft = _displayedIntent.draft;
    final direction = draft.reducing
        ? (draft.buy ? l10n.liveCloseShort : l10n.liveCloseLong)
        : (draft.buy ? l10n.orderConfirmBuy : l10n.orderConfirmSell);
    return PopScope(
      canPop: !_pending,
      child: Dialog(
        backgroundColor: TradeColors.sheet,
        surfaceTintColor: TradeColors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TradeColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 361),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onClose: _pending ? null : () => Navigator.pop(context)),
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 1, color: TradeColors.line),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 8),
                    child: OrderConfirmationTerms(
                      intent: _displayedIntent,
                      sizing: _displayedSizing,
                      direction: direction,
                    ),
                  ),
                ),
                if (widget.failure case final failure? when !_pending)
                  Text(
                    accountErrorText(context, failure),
                    style: TradeTypography.small.copyWith(color: TradeColors.negative),
                  ),
                const SizedBox(height: 36),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        key: const Key('live-order-cancel'),
                        label: l10n.cancel,
                        color: TradeColors.card,
                        textColor: TradeColors.text,
                        onPressed: _pending ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        key: const Key('live-order-confirm'),
                        label: direction,
                        color: draft.buy ? TradeColors.positive : TradeColors.negative,
                        textColor: TradeColors.onDirection,
                        pending: _pending,
                        onPressed: _pending || !widget.ready && !widget.submitWhileUpdating
                            ? null
                            : _confirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(child: Text(l10n.orderConfirmTitle, style: TradeTypography.heading)),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('live-order-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            icon: SvgPicture.asset('assets/portfolio/close.svg', width: 24, height: 24),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
    this.pending = false,
  });
  final String label;
  final Color color, textColor;
  final VoidCallback? onPressed;
  final bool pending;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: color,
      foregroundColor: textColor,
      // Pending keeps the action color; the spinner carries the busy state.
      disabledBackgroundColor: pending ? color : color.withValues(alpha: 0.5),
      disabledForegroundColor: textColor,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: TradeTypography.action,
    ),
    child: pending
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
          )
        : Text(label, textAlign: TextAlign.center),
  );
}
