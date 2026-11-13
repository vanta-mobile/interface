import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../trade/presentation/trade_theme.dart';

class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.asset, {super.key, this.width = 16, this.height = 16});
  final String asset;
  final double width, height;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/settings/$asset.svg',
    width: width,
    height: height,
    excludeFromSemantics: true,
  );
}

/// Rounded group of 40px rows separated by hairlines, per the settings design.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SettingsDivider(),
          children[i],
        ],
      ],
    ),
  );
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(height: 1, thickness: 1, color: TradeColors.line),
  );
}

/// Label on the left, optional bold value and trailing widget on the right.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.busy = false,
  });
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TradeTypography.option.copyWith(color: TradeColors.secondary),
              ),
            ),
            const SizedBox(width: 8),
            // Align fills the loose half so short values stay flush right.
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: busy
                    ? const SettingsSpinner()
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (value != null)
                            Flexible(
                              child: Text(
                                value!,
                                textAlign: TextAlign.end,
                                style: TradeTypography.symbol,
                              ),
                            ),
                          if (value != null && trailing != null) const SizedBox(width: 4),
                          ?trailing,
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The designed 46×26 switch; [onChanged] null renders it disabled.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.label,
    this.onChanged,
    this.busy = false,
  });
  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  /// A write for this switch is in flight: show a spinner and ignore taps.
  final bool busy;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    enabled: onChanged != null && !busy,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null || busy ? null : () => onChanged!(!value),
      child: SizedBox(
        width: 46,
        height: 40,
        child: Center(
          child: busy
              ? const SettingsSpinner()
              : Opacity(
                  opacity: onChanged == null ? .5 : 1,
                  child: SettingsIcon(value ? 'switch-on' : 'switch-off', width: 46, height: 26),
                ),
        ),
      ),
    ),
  );
}

/// Inline 16px progress indicator for a single settings control.
class SettingsSpinner extends StatelessWidget {
  const SettingsSpinner({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: CircularProgressIndicator(strokeWidth: 2, color: TradeColors.text),
  );
}
