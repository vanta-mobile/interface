part of 'position_tpsl_screen.dart';

class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: OverflowBox(
                maxWidth: 44,
                maxHeight: 44,
                child: IconButton(
                  key: const Key('position-tpsl-back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  icon: const PortfolioIcon('back.svg', size: 24, color: TradeColors.text),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TradeTypography.heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Divider(height: 1, thickness: 1, color: TradeColors.line),
    ],
  );
}

class _AmountSection extends StatelessWidget {
  const _AmountSection({
    required this.controller,
    required this.unit,
    required this.position,
    required this.positionValue,
    required this.enabled,
    required this.onTyped,
    required this.onPosition,
  });
  final TextEditingController controller;
  final String unit;
  final double position;
  final Decimal? positionValue;
  final bool enabled;
  final VoidCallback onTyped;
  final ValueChanged<double> onPosition;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PositionTpSlSectionHeader(title: l10n.positionTpslAmount),
        const SizedBox(height: 8),
        PositionField(
          child: PositionValueInput(
            fieldKey: const Key('position-tpsl-amount'),
            controller: controller,
            enabled: enabled,
            onChanged: onTyped,
            suffix: PositionSuffix(label: unit, caret: false),
          ),
        ),
        const SizedBox(height: 6),
        PositionAmountSlider(
          sliderKey: const Key('position-tpsl-percent'),
          position: position,
          continuous: positionValue != null,
          onCommit: enabled ? onPosition : null,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.positionTpslPositionAmount,
                style: TradeTypography.caption.copyWith(color: TradeColors.secondary),
              ),
            ),
            Text(
              positionValue == null ? '--' : '${portfolioAmount(positionValue)} $unit',
              style: TradeTypography.body,
            ),
          ],
        ),
      ],
    );
  }
}
