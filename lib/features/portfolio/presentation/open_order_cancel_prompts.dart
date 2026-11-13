import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import 'portfolio_components.dart';

/// Centered confirmation from the Open Orders design: blurred scrim, title,
/// divider, message and a Cancel / Confirm pair. Resolves true on confirm.
Future<bool> showOpenOrderCancelDialog(
  BuildContext context, {
  required String title,
  required List<Widget> content,
  required Key confirmKey,
}) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: AppLocalizations.of(context).close,
    barrierColor: TradeColors.scrim,
    pageBuilder: (context, _, _) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: TradeColors.sheet,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: TradeColors.card),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(title, style: TradeTypography.heading),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, thickness: 1, color: TradeColors.line),
                      const SizedBox(height: 8),
                      ...content,
                      const SizedBox(height: 28),
                      _PromptActions(confirmKey: confirmKey, confirm: TradeColors.positive),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return confirmed == true;
}

/// Bottom confirmation sheet with the warning mark, used by "Cancel all"
/// orders and "Close all" positions.
Future<bool> showWarningConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required Key confirmKey,
  String? note,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: TradeColors.sheet,
    barrierColor: TradeColors.scrim,
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: TradeColors.card),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: TradeTypography.heading)),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.pop(context, false),
                      icon: const PortfolioIcon('close.svg', size: 24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TradeColors.warningLabel.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const PortfolioIcon('cancel-warning.svg', size: 28),
                ),
              ),
              const SizedBox(height: 12),
              Text(message, style: TradeTypography.option, textAlign: TextAlign.center),
              if (note != null) ...[
                const SizedBox(height: 8),
                Text(
                  note,
                  style: TradeTypography.body.copyWith(color: TradeColors.muted),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              _PromptActions(
                confirmKey: confirmKey,
                confirm: TradeColors.accent,
                onConfirm: TradeColors.onAccent,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    },
  );
  return confirmed == true;
}

class _PromptActions extends StatelessWidget {
  const _PromptActions({
    required this.confirmKey,
    required this.confirm,
    this.onConfirm = TradeColors.text,
  });
  final Key confirmKey;
  final Color confirm, onConfirm;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ButtonStyle style(Color background, Color foreground) => FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      backgroundColor: background,
      foregroundColor: foreground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: TradeTypography.action,
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.pop(context, false),
            style: style(TradeColors.card, TradeColors.text),
            child: Text(l10n.cancel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            key: confirmKey,
            onPressed: () => Navigator.pop(context, true),
            style: style(confirm, onConfirm),
            child: Text(l10n.openOrdersConfirm),
          ),
        ),
      ],
    );
  }
}
