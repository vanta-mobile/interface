part of 'position_tpsl_screen.dart';

/// Inputs of one take-profit or stop-loss leg. The trigger price is the
/// source of truth; the PnL/ROI box mirrors it or, when typed, sets it.
class _LegInput {
  _LegInput(this.kind, this.basis);
  final LiveOrderTriggerKind kind;
  LiveOrderTriggerBasis basis;
  final trigger = TextEditingController(), estimate = TextEditingController();
  final limitInput = TextEditingController();
  bool limit = false;
  LiveOrderPeg? peg;

  bool get active => trigger.text.trim().isNotEmpty;
  Decimal? get triggerPrice => parseOrderDecimal(trigger.text.trim());
  String? get limitPrice =>
      parseOrderDecimal(limitInput.text.trim()) == null ? null : limitInput.text.trim();

  /// Limit execution applies to partial closes only; entire closes are market.
  PositionTpSlLeg snapshot({required bool partial}) => PositionTpSlLeg(
    kind: kind,
    trigger: trigger.text.trim(),
    basis: basis,
    limitPrice: partial && limit && peg == null ? limitPrice : null,
    peg: partial && limit ? peg : null,
  );

  void syncEstimate(_LegEstimate value) => estimate.text = value.text(triggerPrice) ?? '';

  void clear() {
    trigger.clear();
    estimate.clear();
    limitInput.clear();
  }

  void dispose() {
    trigger.dispose();
    estimate.dispose();
    limitInput.dispose();
  }
}

/// Converts between a trigger price and the estimated PnL or ROI of closing
/// [quantity] there.
class _LegEstimate {
  const _LegEstimate({
    required this.position,
    required this.quantity,
    required this.leverage,
    required this.mode,
  });
  final PositionRisk position;
  final Decimal? quantity;
  final int leverage;
  final PositionTriggerInput mode;

  Decimal? pnl(Decimal? trigger) => estimatedTriggerPnl(
    entry: position.entryPrice,
    long: position.long,
    quantity: quantity,
    trigger: trigger,
  );

  String? text(Decimal? trigger) {
    final value = mode == PositionTriggerInput.pnl
        ? pnl(trigger)?.round(scale: 2)
        : estimatedTriggerRoi(
            entry: position.entryPrice,
            long: position.long,
            leverage: leverage,
            trigger: trigger,
          );
    return value == null ? null : '${value > Decimal.zero ? '+' : ''}${value.toStringAsFixed(2)}';
  }

  /// Trigger price on the exchange tick for a typed estimate, or null.
  String? price(LiveOrderContext? data, String input) {
    final p = position, amount = p.quantity.abs();
    if (data == null) return null;
    final result = calculatePositionTriggerPrice(
      position: LiveOrderPosition(
        side: p.side,
        quantity: p.long ? amount : -amount,
        entryPrice: p.entryPrice,
      ),
      quantity: quantity,
      leverage: leverage,
      rules: data.rules,
      mode: mode,
      input: input.startsWith('+') ? input.substring(1) : input,
    );
    return result.price?.toString();
  }
}

class _LegSection extends StatelessWidget {
  const _LegSection({
    required this.leg,
    required this.title,
    required this.scope,
    required this.data,
    required this.estimate,
    required this.quoteAsset,
    required this.enabled,
    required this.onChanged,
    required this.onMode,
  });
  final _LegInput leg;
  final String title, quoteAsset;
  final PositionTpSlScope scope;
  final LiveOrderContext? data;
  final _LegEstimate estimate;
  final bool enabled;
  final void Function([VoidCallback? change]) onChanged;
  final VoidCallback onMode;

  Future<void> _chooseBasis(BuildContext context) async {
    final value = await showPositionTriggerTypeSheet(context, leg.basis);
    if (value != null && value != leg.basis) onChanged(() => leg.basis = value);
  }

  Future<void> _chooseLevel(BuildContext context) async {
    final l10n = AppLocalizations.of(context), current = leg.peg;
    if (current == null) return;
    final value = await showTradeOptionSheet(
      context,
      key: const Key('position-tpsl-bbo-levels'),
      title: l10n.liveOrderBboModeTitle,
      selected: current,
      footer: l10n.liveOrderBboModeHint,
      options: [
        for (final peg in const [LiveOrderPeg.counterparty, LiveOrderPeg.queue])
          (value: peg, label: _levelLabel(l10n, peg), description: null),
      ],
    );
    if (value != null && leg.peg != null) onChanged(() => leg.peg = value);
  }

  static String _levelLabel(AppLocalizations l10n, LiveOrderPeg peg) => peg == LiveOrderPeg.queue
      ? l10n.liveOrderBboQueue(AttachedEntryPeg.queue1.depth)
      : l10n.liveOrderBboCounterparty(AttachedEntryPeg.counterparty1.depth);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final takeProfit = leg.kind == LiveOrderTriggerKind.takeProfit;
    final partial = scope == PositionTpSlScope.partial;
    final name = takeProfit ? 'tp' : 'sl';
    final pnlMode = estimate.mode == PositionTriggerInput.pnl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PositionTpSlSectionHeader(
          title: title,
          inline: takeProfit
              ? PositionTriggerSwitch(onTap: enabled ? () => _chooseBasis(context) : null)
              : null,
          trailing: partial
              ? TradeCheckOption(
                  inline: true,
                  minHeight: 20,
                  tapKey: Key('position-tpsl-$name-limit'),
                  label: l10n.positionTpslLimitOrder,
                  value: leg.limit,
                  onChanged: (value) {
                    if (enabled) onChanged(() => leg.limit = value);
                  },
                )
              : null,
        ),
        const SizedBox(height: 8),
        PositionTriggerRow(
          name: name,
          priceLabel: takeProfit && leg.basis == LiveOrderTriggerBasis.mark
              ? l10n.positionTpslMarkPrice
              : l10n.positionTpslTriggerPrice,
          price: leg.trigger,
          priceSuffix: takeProfit
              ? Text(quoteAsset, style: TradeTypography.body)
              : PositionSuffix(
                  key: Key('position-tpsl-$name-basis'),
                  label: leg.basis == LiveOrderTriggerBasis.mark
                      ? l10n.openOrdersMarkPrice
                      : l10n.openOrdersLastPrice,
                  tooltip: l10n.positionTpslTriggerTitle,
                  onTap: enabled ? () => _chooseBasis(context) : null,
                ),
          estimateLabel: pnlMode ? l10n.positionTpslPnl : l10n.positionTpslRoi,
          estimate: leg.estimate,
          estimateSuffix: PositionSuffix(
            key: Key('position-tpsl-$name-mode'),
            label: pnlMode ? r'$' : '%',
            tooltip: l10n.positionTpslSettingsTitle,
            onTap: enabled ? onMode : null,
          ),
          enabled: enabled,
          gap: partial && leg.limit ? 0 : 2,
          onPrice: () => onChanged(() => leg.syncEstimate(estimate)),
          onEstimate: () => onChanged(() {
            if (estimate.price(data, leg.estimate.text.trim()) case final price?) {
              leg.trigger.text = price;
            }
          }),
        ),
        if (partial && leg.limit) ...[
          const SizedBox(height: 6),
          PositionPriceRow(
            controller: leg.limitInput,
            caption: l10n.positionOrderPrice,
            suffix: PositionSuffix(label: quoteAsset, caret: false),
            enabled: enabled,
            onChanged: onChanged,
            onBbo: () => onChanged(() => leg.peg = leg.peg == null ? LiveOrderPeg.queue : null),
            bboLevel: leg.peg == null ? null : _levelLabel(l10n, leg.peg!),
            onBboLevel: () => _chooseLevel(context),
          ),
        ],
      ],
    );
  }
}
