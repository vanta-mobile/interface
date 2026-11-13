part of 'position_tpsl_screen.dart';

/// Opens the position's existing TP/SL when it has any, otherwise the form.
void openPositionTpSl(BuildContext context, WidgetRef ref, PositionRisk position) {
  final existing = walletPositionExitGroups(
    position,
    ref.read(openOrdersReadProvider).account,
    ref.read(positionRiskProvider).account?.address,
  );
  if (existing.isEmpty) return _openPositionTpSlForm(context, position);
  Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => PositionTpSlListScreen(position: position)));
}

void _openPositionTpSlForm(BuildContext context, PositionRisk position) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => PositionTpSlScreen(position: position)));

/// The newest snapshot of [position], or [position] itself.
PositionRisk _latestPosition(WidgetRef ref, PositionRisk position) {
  for (final row
      in ref.watch(positionRiskProvider.select((s) => s.account?.positions)) ??
          const <PositionRisk>[]) {
    if (row.symbol == position.symbol && row.side == position.side && !row.balanceOnly) return row;
  }
  return position;
}

/// Existing TP/SL of one position, grouped by the order that set them, with
/// Add TP/SL opening the form. A group's Cancel cancels each of its orders.
class PositionTpSlListScreen extends ConsumerStatefulWidget {
  const PositionTpSlListScreen({super.key, required this.position});
  final PositionRisk position;
  @override
  ConsumerState<PositionTpSlListScreen> createState() => _PositionTpSlListScreenState();
}

class _PositionTpSlListScreenState extends ConsumerState<PositionTpSlListScreen> {
  PositionTpSlScope scope = PositionTpSlScope.partial;
  PositionExitGroup? cancelling;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(openOrdersAutoReadProvider);
    final p = _latestPosition(ref, widget.position);
    final (quote, _) = watchPositionMark(ref, p);
    final mark = PositionValuation(position: p, quote: quote).mark;
    final address = ref.watch(positionRiskProvider.select((s) => s.account?.address));
    final orders = ref.watch(openOrdersReadProvider.select((s) => s.account));
    final busy = ref.watch(openOrdersReadProvider.select((s) => s.busy));
    final cancellation = ref.watch(orderCancellationProvider);
    final session = ref.watch(authProvider);
    final canCancel =
        cancelling == null &&
        session.identity?.signingAvailable == true &&
        !session.busy &&
        !busy &&
        !cancellation.busy &&
        !cancellation.needsRecheck;
    final groups = walletPositionExitGroups(
      p,
      orders,
      address,
    ).where((g) => g.entire == (scope == PositionTpSlScope.entire)).toList();
    return Scaffold(
      backgroundColor: TradeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Header(title: l10n.positionTpslTitle),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => Future.wait([
                  ref.read(openOrdersReadProvider.notifier).refresh(),
                  ref.read(positionRiskProvider.notifier).refresh(),
                ]),
                child: ListView(
                  key: const Key('position-tpsl-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    PositionTabs<PositionTpSlScope>(
                      tabs: [
                        (PositionTpSlScope.partial, l10n.positionTpslPartial),
                        (PositionTpSlScope.entire, l10n.positionTpslEntire),
                      ],
                      selected: scope,
                      onSelect: (value) => setState(() => scope = value),
                    ),
                    const OrderCancellationStatus(),
                    for (final group in groups) ...[
                      const SizedBox(height: 16),
                      _ExitGroupCard(
                        key: Key('position-tpsl-group-${group.orders.first.orderId}'),
                        position: p,
                        group: group,
                        mark: mark,
                        pending: identical(cancelling, group),
                        onCancel: canCancel ? () => _cancel(group) : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PositionActionButton(
                key: const Key('position-tpsl-add'),
                label: l10n.positionTpslAdd,
                onPressed: () => _openPositionTpSlForm(context, p),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cancels the group's orders one at a time with the single-order flow; a
  /// failed or unconfirmed cancellation stops before the next order.
  Future<void> _cancel(PositionExitGroup group) async {
    final controller = ref.read(orderCancellationProvider.notifier);
    if (group.orders.any((order) => controller.prepare(order) == null)) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showOpenOrderCancelDialog(
      context,
      title: l10n.orderCancelTitle,
      confirmKey: const Key('confirm-order-cancel'),
      content: [
        Text(
          l10n.orderCancelConfirmHint,
          style: TradeTypography.option.copyWith(color: TradeColors.muted),
        ),
        const SizedBox(height: 12),
        for (final order in group.orders)
          SelectableText('${order.symbol} · ${order.orderId}', style: TradeTypography.body),
      ],
    );
    if (!confirmed || !mounted) return;
    setState(() => cancelling = group);
    try {
      for (final order in group.orders) {
        final intent = controller.prepare(order);
        if (intent == null) break;
        await controller.cancel(intent);
        if (!mounted) return;
        final state = ref.read(orderCancellationProvider);
        if (state.failure != null || state.needsRecheck || state.result?.failure != null) break;
      }
    } finally {
      if (mounted) setState(() => cancelling = null);
    }
  }
}

class _ExitGroupCard extends StatelessWidget {
  const _ExitGroupCard({
    super.key,
    required this.position,
    required this.group,
    required this.mark,
    required this.pending,
    required this.onCancel,
  });
  final PositionRisk position;
  final PositionExitGroup group;
  final Decimal? mark;
  final bool pending;
  final VoidCallback? onCancel;

  /// Entire orders close the whole position; partial ones their own quantity.
  Decimal _quantity(AsterOpenOrder order) =>
      order.closePosition ? position.quantity.abs() : order.origQty;

  @override
  Widget build(BuildContext context) {
    final p = position;
    Decimal? pnl(AsterOpenOrder? order) => order == null
        ? null
        : estimatedTriggerPnl(
            entry: p.entryPrice,
            long: p.long,
            quantity: _quantity(order),
            trigger: order.stopPrice,
          );
    final legs = [
      if (group.takeProfit case final order?) (order, true),
      if (group.stopLoss case final order?) (order, false),
    ];
    return PortfolioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ExitSummary(
            position: p,
            takeProfitPnl: group.takeProfit == null ? null : (pnl(group.takeProfit),),
            stopLossPnl: group.stopLoss == null ? null : (pnl(group.stopLoss),),
            amount: mark == null ? null : _quantity(group.orders.first) * mark!,
          ),
          for (final (index, (order, takeProfit)) in legs.indexed) ...[
            if (index > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: TradeColors.line),
            ],
            const SizedBox(height: 12),
            _ExitLeg(order: order, takeProfit: takeProfit),
          ],
          const SizedBox(height: 12),
          OpenOrderChipButton(
            key: Key('position-tpsl-cancel-${group.orders.first.orderId}'),
            label: AppLocalizations.of(context).cancel,
            pending: pending,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Estimated PnL of the legs present and the closing amount at the mark.
class _ExitSummary extends StatelessWidget {
  const _ExitSummary({
    required this.position,
    required this.takeProfitPnl,
    required this.stopLossPnl,
    required this.amount,
  });
  final PositionRisk position;

  /// Null when the group has no such leg; the inner value when it is unknown.
  final (Decimal?,)? takeProfitPnl, stopLossPnl;
  final Decimal? amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String text(Decimal? value) => value == null ? openOrderPlaceholder : portfolioAmount(value);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: TradeColors.sheet, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.positionTpslEstimatedPnlUnit(
                    position.units?.margin ?? l10n.accountUnitUnavailable,
                  ),
                  style: _exitLabelStyle,
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      if (takeProfitPnl case (final value,))
                        TextSpan(
                          text: text(value),
                          style: const TextStyle(color: TradeColors.positive),
                        ),
                      if (takeProfitPnl != null && stopLossPnl != null)
                        const TextSpan(text: '  /  '),
                      if (stopLossPnl case (final value,))
                        TextSpan(
                          text: text(value),
                          style: const TextStyle(color: TradeColors.negative),
                        ),
                    ],
                  ),
                  style: _exitValueStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.positionTpslAmountUnit(position.units?.quote ?? l10n.accountUnitUnavailable),
                  style: _exitLabelStyle,
                  textAlign: TextAlign.end,
                ),
                const SizedBox(height: 4),
                Text(text(amount), style: _exitValueStyle, textAlign: TextAlign.end),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitLeg extends StatelessWidget {
  const _ExitLeg({required this.order, required this.takeProfit});
  final AsterOpenOrder order;
  final bool takeProfit;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quote = order.units?.quote ?? l10n.accountUnitUnavailable;
    final price = openOrderPrice(l10n, order);
    final priced =
        order.price > Decimal.zero && !order.closePosition && order.origQty > Decimal.zero;
    final value = priced ? '${marketNumber(order.origQty * order.price)} $quote' : price;
    return Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: takeProfit ? TradeColors.buyLabel : TradeColors.sellLabel,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            takeProfit ? l10n.tradeTp : l10n.tradeSl,
            textAlign: TextAlign.center,
            style: TradeTypography.tag.copyWith(
              color: takeProfit ? TradeColors.positive : TradeColors.negative,
            ),
          ),
        ),
        const SizedBox(width: 56),
        Expanded(
          child: Column(
            children: [
              _ExitLegRow(
                l10n.openOrdersTriggerPrice,
                openOrderTrigger(l10n, order) ?? openOrderPlaceholder,
              ),
              const SizedBox(height: 6),
              _ExitLegRow(l10n.openOrdersOrderValue, value),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExitLegRow extends StatelessWidget {
  const _ExitLegRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TradeTypography.body.copyWith(color: TradeColors.secondary)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(value, style: TradeTypography.body, textAlign: TextAlign.end),
      ),
    ],
  );
}

const _exitLabelStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 12,
  height: 18 / 12,
  fontWeight: FontWeight.w500,
  color: TradeColors.secondary,
);

const _exitValueStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
  height: 20 / 14,
  fontWeight: FontWeight.w500,
  color: TradeColors.text,
);
