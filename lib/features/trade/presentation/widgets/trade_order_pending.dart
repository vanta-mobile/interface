import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/presentation/status_view.dart';
import '../../../market/domain/market.dart';
import '../../application/providers.dart';
import '../../../portfolio/application/order_entry_gate_provider.dart';
import '../../../funding/domain/funding_catalog.dart';
import '../../../funding/presentation/funding_screen.dart';
import '../../../portfolio/domain/live_order_time_in_force.dart';
import '../../../portfolio/presentation/embedded_time_in_force_selector.dart';
import '../../../portfolio/presentation/live_order_embedded_controls.dart';
import '../../../portfolio/presentation/live_order_embedded_inputs.dart';
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
    final quote = ref.watch(currentMarketProvider);
    final selectedPrice = ref.watch(orderPriceProvider);
    final referencePrice = selectedPrice.isNotEmpty
        ? selectedPrice
        : quote != null && quote.symbol == symbol
        ? marketInput(quote.price)
        : '';
    // Order controls are inert until account rules load; without a wallet
    // they lead to the connection flow instead.
    final connect = gate == OrderEntryGate.connect ? () => showAccountSheet(context) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        EmbeddedPriceField(
          key: ValueKey(('trade-pending-price', symbol, market)),
          controller: null,
          asset: 'USDT',
          tick: Decimal.zero,
          enabled: connect != null,
          onChanged: () {},
          fixedLabel: market ? l.market : (referencePrice.isEmpty ? '—' : referencePrice),
          bboVisible: !market,
          onBbo: market ? null : connect,
        ),
        const SizedBox(height: 8),
        EmbeddedInputBox(
          label: l.tradeOrderSize,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('trade-pending-quantity'),
                  enabled: false,
                  style: TradeTypography.body,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: '—',
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              EmbeddedSelector(label: 'USDT', tooltip: l.tradeSelectUnitType, onTap: connect),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
        _PendingAdvanced(market: market, onConnect: connect),
        for (final buy in [true, if (gate == OrderEntryGate.ready) false])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _PendingDirection(buy: buy, gate: gate, loading: loading),
          ),
      ],
    );
  }
}

/// Advanced options stay visible before account rules load; without a wallet
/// each option opens the connection flow.
class _PendingAdvanced extends StatelessWidget {
  const _PendingAdvanced({required this.market, required this.onConnect});
  final bool market;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final onChanged = onConnect == null ? null : (bool _) => onConnect!();
    return EmbeddedAdvancedSection(
      children: [
        EmbeddedCheckRow(
          key: const Key('trade-pending-tpsl'),
          label: l.tradeTpSl,
          value: false,
          onChanged: onChanged,
        ),
        if (!market)
          EmbeddedCheckRow(
            key: const Key('trade-pending-hidden'),
            label: l.tradeHiddenOrder,
            value: false,
            onChanged: onChanged,
          ),
        EmbeddedCheckRow(
          key: const Key('trade-pending-reduce-only'),
          label: l.reduceOnly,
          value: false,
          onChanged: onChanged,
          trailing: market
              ? null
              : EmbeddedTimeInForceSelector(
                  selected: LiveOrderTimeInForce.gtc,
                  available: const {LiveOrderTimeInForce.gtc},
                  onChanged: null,
                  onTap: onConnect,
                ),
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
