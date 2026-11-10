import 'package:flutter/material.dart';

import '../../../core/formatters/decimal_text_input_formatter.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';

class AccountSelectField extends StatelessWidget {
  const AccountSelectField({
    super.key,
    required this.label,
    required this.value,
    this.onPressed,
    this.showChevron = false,
  });
  final String label, value;
  final VoidCallback? onPressed;
  final bool showChevron;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: PortfolioColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PortfolioColors.line),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AccountTypography.fieldLabel),
                    const SizedBox(height: 2),
                    Text(value, style: AccountTypography.body),
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                const PortfolioIcon('chevron-down.svg', size: 16, color: PortfolioColors.muted),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Keeps the amount label in place in both the form and confirmation layouts.
class AccountTransferAmountInput extends StatefulWidget {
  const AccountTransferAmountInput({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  State<AccountTransferAmountInput> createState() => _AccountTransferAmountInputState();
}

class _AccountTransferAmountInputState extends State<AccountTransferAmountInput> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Focus(
      onFocusChange: (value) => setState(() => focused = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: PortfolioColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: focused ? PortfolioColors.accent : PortfolioColors.line),
        ),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).accountsAmount,
                style: AccountTypography.fieldLabel,
              ),
              const SizedBox(height: 2),
              TextField(
                key: const Key('accounts-transfer-amount'),
                controller: widget.controller,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalTextInputFormatter(maxFractionDigits: 18)],
                style: AccountTypography.body,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: widget.onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
