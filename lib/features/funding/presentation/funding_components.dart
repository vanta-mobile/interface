import 'package:flutter/material.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/decimal_text_input_formatter.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/motion/animated_number_text.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/portfolio_components.dart';
import '../domain/funding_catalog.dart';
import 'funding_icons.dart';

export 'funding_icons.dart';

String fundingNetworkName(AppLocalizations l, int chainId) => switch (chainId) {
  1 => l.fundingNetworkEthereum,
  56 => l.fundingNetworkBnb,
  42161 => l.fundingNetworkArbitrum,
  _ => '$chainId',
};

String fundingNativeSymbol(int chainId) => chainId == 56 ? 'BNB' : 'ETH';

String fundingAmountText(String amount, String asset) => TokenAmountFormatter.format(
  DecimalValue(amount),
  symbol: asset,
  display: TokenAmountDisplay.exact,
);

/// Deposit / Withdraw switch from the funding frames.
class FundingTabs extends StatelessWidget {
  const FundingTabs({super.key, required this.operation, required this.onChanged});
  final FundingOperation operation;
  final ValueChanged<FundingOperation> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget tab(FundingOperation value, String label) {
      final selected = value == operation;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            key: Key('funding-tab-${value.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: selected ? null : () => onChanged(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? PortfolioColors.card : PortfolioColors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: FundingTypography.tab.copyWith(
                    color: selected ? PortfolioColors.text : PortfolioColors.secondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PortfolioColors.inset,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            tab(FundingOperation.deposit, l.fundingDeposit),
            const SizedBox(width: 6),
            tab(FundingOperation.withdraw, l.fundingWithdraw),
          ],
        ),
      ),
    );
  }
}

class FundingChevron extends StatelessWidget {
  const FundingChevron({super.key, this.open = false});
  final bool open;
  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: open ? 2 : 0,
    child: const PortfolioIcon('chevron-down.svg', size: 16, color: PortfolioColors.muted),
  );
}

/// Bordered label/value card used for account and network.
class FundingField extends StatelessWidget {
  const FundingField({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.open = false,
  });
  final String label, value;
  final Widget? icon;
  final VoidCallback? onTap;
  final bool open;
  @override
  Widget build(BuildContext context) => Material(
    color: PortfolioColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: PortfolioColors.line),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (icon case final image?) ...[image, const SizedBox(width: 8)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: FundingTypography.fieldLabel),
                    const SizedBox(height: 2),
                    Text(value, style: AccountTypography.body),
                  ],
                ),
              ),
              if (onTap != null) ...[const SizedBox(width: 8), FundingChevron(open: open)],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Amount card with the editable value and the asset selector on the right.
class FundingAmountField extends StatelessWidget {
  const FundingAmountField({
    super.key,
    required this.controller,
    required this.decimals,
    required this.asset,
    required this.onChanged,
    this.enabled = true,
    this.error = false,
    this.assetSelector,
  });
  final TextEditingController controller;
  final int decimals;
  final String asset;
  final bool enabled, error;
  final ValueChanged<String> onChanged;
  final Widget? assetSelector;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: PortfolioColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error ? PortfolioColors.negative : PortfolioColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.fundingAmountLabel, style: FundingTypography.fieldLabel),
                const SizedBox(height: 2),
                TextField(
                  key: const Key('funding-amount'),
                  controller: controller,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalTextInputFormatter(maxFractionDigits: decimals)],
                  style: FundingTypography.amount,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: FundingTypography.amount.copyWith(color: PortfolioColors.secondary),
                    isCollapsed: true,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          assetSelector ??
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FundingAssetIcon(asset),
                  const SizedBox(width: 8),
                  Text(asset, style: AccountTypography.body),
                ],
              ),
        ],
      ),
    );
  }
}

/// Tappable asset label inside [FundingAmountField].
class FundingAssetSelector extends StatelessWidget {
  const FundingAssetSelector({super.key, required this.asset, this.onTap, this.open = false});
  final String asset;
  final VoidCallback? onTap;
  final bool open;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: AppLocalizations.of(context).fundingSelectAsset,
    child: InkWell(
      key: const Key('funding-asset-selector'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FundingAssetIcon(asset),
            const SizedBox(width: 8),
            Text(asset, style: AccountTypography.body),
            const SizedBox(width: 8),
            FundingChevron(open: open),
          ],
        ),
      ),
    ),
  );
}

/// Balance or withdrawable amount with the Max shortcut.
class FundingBalanceRow extends StatelessWidget {
  const FundingBalanceRow({
    super.key,
    required this.label,
    required this.value,
    this.loading = false,
    this.onMax,
  });
  final String label;
  final String? value;
  final bool loading;
  final VoidCallback? onMax;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 28),
    child: Row(
      children: [
        Expanded(child: Text(label, style: PortfolioTypography.caption)),
        const SizedBox(width: 6),
        Expanded(
          child: value == null && loading
              ? const Align(alignment: Alignment.centerRight, child: FundingSkeleton(width: 96))
              : Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedNumberText(
                    value ?? '—',
                    key: const Key('funding-balance-value'),
                    textAlign: TextAlign.right,
                    softWrap: true,
                    style: FundingTypography.value,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          enabled: onMax != null,
          child: InkWell(
            key: const Key('funding-max'),
            onTap: onMax,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 32, minHeight: 44),
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child: Text(
                  AppLocalizations.of(context).fundingMax,
                  style: FundingTypography.value.copyWith(color: PortfolioColors.accent),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Section-scoped loading placeholder for a value that has not loaded yet.
class FundingSkeleton extends StatelessWidget {
  const FundingSkeleton({super.key, required this.width});
  final double width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 14,
    decoration: BoxDecoration(color: PortfolioColors.card, borderRadius: BorderRadius.circular(4)),
  );
}

/// Inline guidance with the info or warning icon.
class FundingGuidance extends StatelessWidget {
  const FundingGuidance(
    this.text, {
    super.key,
    this.warning = false,
    this.style = PortfolioTypography.caption,
  });
  final String text;
  final bool warning;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (warning)
          const PortfolioIcon('funding-warning.svg', size: 20)
        else
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: PortfolioIcon('info.svg', size: 16),
          ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: style)),
      ],
    ),
  );
}

/// Red validation or action error under the amount card.
class FundingError extends StatelessWidget {
  const FundingError(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    key: const Key('funding-error'),
    style: PortfolioTypography.caption.copyWith(color: PortfolioColors.negative),
  );
}
