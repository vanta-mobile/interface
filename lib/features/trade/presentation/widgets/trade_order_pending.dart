import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market.dart';
import '../../application/providers.dart';
import '../trade_theme.dart';
import 'primitives.dart';

/// Unknown account facts remain unavailable until the explicit signed read.
class TradeOrderPending extends ConsumerWidget {
  const TradeOrderPending({super.key, required this.symbol, required this.market});
  final String symbol;
  final bool market;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final instrument = ref.watch(selectedInstrumentProvider);
    final base = instrument?.symbol == symbol ? instrument!.base : '—';
    final quote = ref.watch(currentMarketProvider);
    final selectedPrice = ref.watch(orderPriceProvider);
    final referencePrice = selectedPrice.isNotEmpty
        ? selectedPrice
        : quote != null && quote.symbol == symbol
        ? marketInput(quote.price)
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(('trade-pending-price', symbol, market, referencePrice)),
          initialValue: market ? l.market : referencePrice,
          enabled: false,
          style: TradeTypography.body,
          decoration: InputDecoration(
            labelText: l.liveOrderPrice('USDT'),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: '—',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('trade-pending-quantity'),
          enabled: false,
          style: TradeTypography.body,
          decoration: InputDecoration(
            labelText: l.liveOrderQuantity(base),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: '—',
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, disabledThumbRadius: 6),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: const SizedBox(height: 20, child: Slider(value: 0, divisions: 4, onChanged: null)),
        ),
        ValueRow(l.available, '—', key: const Key('trade-available')),
        for (final buy in [true, false])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _PendingDirection(buy: buy),
          ),
      ],
    );
  }
}

class _PendingDirection extends StatelessWidget {
  const _PendingDirection({required this.buy});
  final bool buy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          decoration: BoxDecoration(
            border: Border.all(color: TradeColors.card),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              for (final label in [l.tradeEstimatedLiquidation, l.tradeMargin, l.accountsMax])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(label, style: TradeTypography.caption)),
                      const SizedBox(width: 4),
                      Text('—', style: TradeTypography.caption.copyWith(color: TradeColors.text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        FilledButton(
          key: ValueKey('trade-pending-${buy ? 'buy' : 'sell'}'),
          onPressed: null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            disabledBackgroundColor: (buy ? TradeColors.positive : TradeColors.negative).withValues(
              alpha: .35,
            ),
            disabledForegroundColor: TradeColors.text,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
          child: Text(buy ? l.long : l.short),
        ),
      ],
    );
  }
}
