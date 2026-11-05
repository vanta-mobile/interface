import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/position_margin_adjustment.dart';
import '../domain/isolated_margin_ratio.dart';

String marginDirectionLabel(AppLocalizations l, MarginDirection direction) =>
    direction == MarginDirection.add ? l.marginAdjustAdd : l.marginAdjustRemove;

class PositionMarginForm extends StatelessWidget {
  const PositionMarginForm({
    super.key,
    required this.settings,
    required this.direction,
    required this.amount,
    required this.stale,
    required this.busy,
    required this.onDirection,
    required this.onInput,
    required this.onReview,
  });
  final PositionMarginContext settings;
  final MarginDirection direction;
  final TextEditingController amount;
  final bool stale, busy;
  final ValueChanged<MarginDirection> onDirection;
  final VoidCallback onInput;
  final VoidCallback? onReview;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), p = settings.position;
    final asset = settings.asset, max = settings.maximum(direction);
    final own = settings.account.positions
        .where((row) => row.symbol == p.symbol && row.side == p.side)
        .singleOrNull;
    final ratio = own == null ? null : isolatedMarginRatio(own);
    final parsed = settings.amount(amount.text, direction);
    final raw = Decimal.tryParse(amount.text);
    final overMax = raw != null && max != null && raw > max;
    final adjustment = amount.text.isEmpty ? Decimal.zero : parsed;
    final preview = adjustment == null ? null : settings.liquidation(direction, adjustment);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${DateFormat('yyyy-MM-dd HH:mm:ss').format(settings.receivedAt.toUtc())} UTC'),
        if (stale) Text(l.marginAdjustExpired, style: const TextStyle(color: AppColors.warning)),
        if (ratio != null) ...[
          ValueRow(
            l.marginAdjustRatio,
            ratio.percent == null ? '—' : '${ratio.percent!.toStringAsFixed(2)}%',
          ),
          if (ratio.atRisk)
            Text(l.marginAdjustEquityRisk, style: const TextStyle(color: AppColors.warning)),
        ],
        ValueRow(l.marginAdjustWallet, '${p.isolatedWallet} $asset'),
        ValueRow(l.marginAdjustMaximum, max == null ? '—' : '$max $asset'),
        const SizedBox(height: 12),
        DropdownButtonFormField<MarginDirection>(
          key: ValueKey(('margin-adjust-direction', direction)),
          initialValue: direction,
          isExpanded: true,
          items: [
            for (final d in MarginDirection.values)
              DropdownMenuItem(value: d, child: Text(marginDirectionLabel(l, d))),
          ],
          onChanged: busy
              ? null
              : (v) {
                  if (v != null) onDirection(v);
                },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('margin-adjust-amount'),
          controller: amount,
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          maxLength: 100,
          onChanged: (_) => onInput(),
          decoration: InputDecoration(
            labelText: '${l.marginAdjustAmountLabel} ($asset)',
            errorText: amount.text.isNotEmpty && parsed == null
                ? (overMax ? l.marginAdjustOverMaximum : l.marginAdjustAmount)
                : null,
          ),
        ),
        OutlinedButton(
          key: const Key('margin-adjust-max'),
          onPressed: busy || stale || max == null
              ? null
              : () {
                  amount.text = settings.maxInput(direction)!;
                  onInput();
                },
          child: Text(l.marginAdjustMax),
        ),
        ValueRow(
          l.marginAdjustNextWallet,
          adjustment == null
              ? '—'
              : '${p.isolatedWallet + (direction == MarginDirection.add ? adjustment : -adjustment)} $asset',
        ),
        ValueRow(
          l.marginAdjustLiquidation,
          preview == null
              ? '—'
              : '${preview.toStringAsFixed(8)} ${p.units!.quote}/${p.units!.base}',
        ),
        Text(l.marginAdjustPreviewHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('margin-adjust-review'),
          onPressed: onReview,
          child: Text(l.marginAdjustReview),
        ),
      ],
    );
  }
}
