import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/presentation/drag_throttle.dart';
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

  /// Position share 0–1; the form turns it into a close amount.
  final ValueChanged<double> onFraction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), position = data.reductionPosition(draft);
    final amount = parseOrderDecimal(draft.quantity) ?? Decimal.zero;
    final share = position == null || position.quantity == Decimal.zero
        ? 0.0
        : (amount / position.quantity.abs()).toDouble().clamp(0.0, 1.0);
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
              child: _CloseFractionSlider(share: share, onFraction: enabled ? onFraction : null),
            ),
          if (!draft.entireClose)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final percent in [25, 50, 75, 100])
                  OutlinedButton(
                    key: ValueKey('live-close-fraction-$percent'),
                    onPressed: enabled ? () => onFraction(percent / 100) : null,
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

/// Each committed share rewrites the quantity and rebuilds the whole form, so
/// the thumb follows the drag continuously and commits are throttled.
class _CloseFractionSlider extends StatefulWidget {
  const _CloseFractionSlider({required this.share, required this.onFraction});
  final double share;
  final ValueChanged<double>? onFraction;

  @override
  State<_CloseFractionSlider> createState() => _CloseFractionSliderState();
}

class _CloseFractionSliderState extends State<_CloseFractionSlider> {
  late final _throttle = DragThrottle<double>((value) => widget.onFraction?.call(value));
  double? _drag;

  @override
  void didUpdateWidget(_CloseFractionSlider old) {
    super.didUpdateWidget(old);
    // A drag cut off by disabling never reports its end; drop its local value.
    if (widget.onFraction == null) {
      _throttle.cancel();
      _drag = null;
    }
  }

  @override
  void dispose() {
    _throttle.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onFraction != null;
    return Slider(
      key: const Key('live-close-percentage'),
      value: _drag ?? widget.share,
      semanticFormatterCallback: (value) => '${(value * 100).round()}%',
      onChanged: enabled
          ? (value) {
              setState(() => _drag = value);
              _throttle.add(value);
            }
          : null,
      onChangeEnd: enabled
          ? (value) {
              _throttle.end(value);
              if (mounted) setState(() => _drag = null);
            }
          : null,
    );
  }
}
