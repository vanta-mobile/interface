import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/presentation/status_view.dart';
import '../../../market/application/market_providers.dart';
import '../../../market/domain/market.dart';
import '../../application/providers.dart';
import '../../../portfolio/application/order_entry_gate_provider.dart';
import '../../../funding/domain/funding_catalog.dart';
import '../../../funding/presentation/funding_screen.dart';
import 'account_sheet.dart';
import '../trade_theme.dart';
import 'primitives.dart';

/// Unknown account facts remain unavailable until the explicit signed read.
class TradeOrderPending extends ConsumerWidget {
  const TradeOrderPending({
    super.key,
    required this.symbol,
    required this.market,
    this.loading = false,
  });
  final String symbol;
  final bool market;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gate = ref.watch(orderEntryGateProvider);
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
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(child: Text(l.available, style: TradeTypography.caption)),
                const SkeletonBox(key: Key('trade-available-pending'), width: 72, height: 14),
              ],
            ),
          )
        else
          ValueRow(l.available, '—', key: const Key('trade-available')),
        for (final buy in [true, if (gate == OrderEntryGate.ready) false])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _PendingDirection(buy: buy, gate: gate, loading: loading),
          ),
      ],
    );
  }
}

class _PendingDirection extends StatelessWidget {
  const _PendingDirection({required this.buy, required this.gate, required this.loading});
  final bool buy;
  final OrderEntryGate gate;
  final bool loading;

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
              for (final (label, name) in [
                (l.tradeEstimatedLiquidation, 'liquidation'),
                (l.tradeMargin, 'cost'),
                (l.accountsMax, 'maximum'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    key: Key('trade-pending-$name-${buy ? 'buy' : 'sell'}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(label, style: TradeTypography.caption)),
                      const SizedBox(width: 4),
                      if (loading && name == 'maximum')
                        const SkeletonBox(width: 72, height: 14)
                      else
                        Text('—', style: TradeTypography.caption.copyWith(color: TradeColors.text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        FilledButton(
          key: ValueKey('trade-pending-${buy ? 'buy' : 'sell'}'),
          onPressed: gate == OrderEntryGate.connect
              ? () => showAccountSheet(context)
              : gate == OrderEntryGate.deposit
              ? () => openFunding(context, FundingOperation.deposit)
              : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 36),
            backgroundColor: TradeColors.positive,
            foregroundColor: TradeColors.text,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            disabledBackgroundColor: (buy ? TradeColors.positive : TradeColors.negative).withValues(
              alpha: .35,
            ),
            disabledForegroundColor: TradeColors.text,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: TradeTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
          child: Text(switch (gate) {
            OrderEntryGate.connect => l.connect,
            OrderEntryGate.deposit => l.fundingDeposit,
            OrderEntryGate.ready => buy ? l.long : l.short,
          }),
        ),
      ],
    );
  }
}
