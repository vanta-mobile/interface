import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/futures_position_mode.dart';
import '../domain/live_order.dart';

class LiveOrderReductionControls extends StatelessWidget {
  const LiveOrderReductionControls({
    super.key,
    required this.data,
    required this.draft,
    required this.enabled,
    required this.onReduce,
    required this.onFraction,
  });
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  final bool enabled;
  final ValueChanged<bool> onReduce;
  final ValueChanged<int> onFraction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), position = data.reductionPosition(draft);
    final amount = parseOrderDecimal(draft.quantity) ?? Decimal.zero;
    final percentage = position == null || position.quantity == Decimal.zero
        ? 0
        : ((amount * Decimal.fromInt(100)) / position.quantity.abs()).floor().toInt().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft.closingSide == null)
          if (data.mode == FuturesPositionMode.oneWay)
            SwitchListTile(
              key: const Key('live-order-reduce-only'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.reduceOnly),
              subtitle: Text(l10n.liveOrderReduceHint),
              value: draft.reduceOnly,
              onChanged: enabled ? onReduce : null,
            )
          else
            Text(l10n.liveOrderReduceHedge, style: Theme.of(context).textTheme.bodySmall),
        if (draft.closingSide != null && position != null) ...[
          Text(
            position.long ? l10n.liveCloseLong : l10n.liveCloseShort,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!draft.entireClose)
            Semantics(
              label: l10n.scalePercentage,
              child: Slider(
                key: const Key('live-close-percentage'),
                value: percentage.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$percentage%',
                onChanged: enabled ? (value) => onFraction(value.round()) : null,
              ),
            ),
          if (!draft.entireClose)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final percent in [25, 50, 75, 100])
                  OutlinedButton(
                    key: ValueKey('live-close-fraction-$percent'),
                    onPressed: enabled ? () => onFraction(percent) : null,
                    child: Text('$percent%'),
                  ),
              ],
            ),
        ],
        if (draft.reducing && position != null) ...[
          ValueRow(
            l10n.liveClosePositionAmount,
            '${position.quantity.abs()} ${data.rules.baseAsset}',
          ),
          ValueRow(l10n.entry, '${position.entryPrice} ${data.rules.quoteAsset}'),
          ValueRow(
            l10n.liveCloseEstimatedPnl,
            data.estimatedClosePnl(draft) == null
                ? '—'
                : '${data.estimatedClosePnl(draft)} ${data.rules.quoteAsset}',
          ),
          Text(
            draft.trailing != null
                ? l10n.liveTrailingEstimateHint
                : draft.entireClose
                ? l10n.liveEntireEstimateHint
                : draft.trigger == null
                ? l10n.liveCloseEstimateHint
                : l10n.liveOrderConditionalEstimateHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
