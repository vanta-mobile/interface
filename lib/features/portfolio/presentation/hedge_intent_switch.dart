import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../../core/presentation/no_press_feedback.dart';

/// Hedge-mode Open/Close segment above the account settings. Open places
/// Long/Short entries; Close reduces the matching LONG/SHORT position.
class HedgeIntentSwitch extends StatelessWidget {
  const HedgeIntentSwitch({super.key, required this.closing, required this.onChanged});
  final bool closing;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      key: const Key('hedge-intent'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: TradeColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TradeColors.line),
      ),
      child: Row(
        children: [
          for (final (close, label, color) in [
            (false, l.tradeHedgeOpen, TradeColors.positive),
            (true, l.tradeHedgeClose, TradeColors.negative),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: closing == close,
                child: Material(
                  color: closing == close ? TradeColors.control : TradeColors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  clipBehavior: Clip.antiAlias,
                  child: NoPressFeedback(
                    child: InkWell(
                      key: Key(close ? 'hedge-intent-close' : 'hedge-intent-open'),
                      onTap: onChanged == null ? null : () => onChanged!(close),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 27),
                        child: Center(
                          child: Text(
                            label,
                            style: TradeTypography.caption.copyWith(color: color),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
