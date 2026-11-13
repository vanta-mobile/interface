import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../authorization/application/trading_agent_provider.dart';
import '../../market/application/market_providers.dart'
    show selectedInstrumentProvider, selectedPrecisionProvider;
import '../../market/domain/market_precision.dart';
import '../../trade/application/providers.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/live_order_provider.dart';
import '../application/quick_order_provider.dart';
import 'quick_order_review.dart';

/// Chart-tab quick market entry pinned above the bottom navigation: an
/// independent quote-asset amount followed by Market Buy and Market Sell.
/// Percent shortcuts appear above it while the quantity is being edited; validation and
/// sizing failures appear in a banner above the bar until the input changes.
class QuickOrderPanel extends ConsumerStatefulWidget {
  const QuickOrderPanel({super.key});
  @override
  ConsumerState<QuickOrderPanel> createState() => _QuickOrderPanelState();
}

class _QuickOrderPanelState extends ConsumerState<QuickOrderPanel> {
  final quantity = TextEditingController();
  final focus = FocusNode();
  bool? pending;
  String? error;
  int _percentTap = 0;

  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
    // Ready the percentage sizing as soon as the bar is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetch());
  }

  void _prefetch() {
    if (mounted) unawaited(ref.read(quickOrderProvider.notifier).prefetch());
  }

  @override
  void dispose() {
    quantity.dispose();
    focus.dispose();
    super.dispose();
  }

  bool get _connected {
    final identity = ref.read(authProvider).identity;
    return identity?.signingAvailable == true && identity?.walletAddress != null;
  }

  /// Signed reads run only after an explicit tap; failures keep the input.
  Future<bool> _ensureSizing({required bool percent}) async {
    final controller = ref.read(quickOrderProvider.notifier);
    final sizing = ref.read(quickOrderProvider).sizing;
    final context = controller.context;
    if (context != null && (!percent || sizing?.context == context)) return true;
    await controller.load();
    if (!mounted) return false;
    final failure = ref.read(quickOrderProvider).failure;
    if (failure != null) setState(() => error = accountErrorText(this.context, failure));
    return failure == null && controller.context != null;
  }

  Future<void> _percent(int value) async {
    if (!_connected) {
      showAccountSheet(context);
      return;
    }
    setState(() => error = null);
    // Only the latest tap applies; a slower earlier one never overrides it.
    final tap = ++_percentTap;
    // Sizing already read for this account (a renewal may have replaced its
    // snapshot) lets the choice apply at once; the order is still sized against
    // the current snapshot when it is submitted.
    final ok = ref.read(quickOrderProvider).sizing != null || await _ensureSizing(percent: true);
    if (ok && mounted && tap == _percentTap) {
      ref.read(quickOrderProvider.notifier).selectPercent(value);
    }
  }

  Future<void> _submit(bool buy) async {
    if (!_connected) {
      showAccountSheet(context);
      return;
    }
    if (pending != null) return;
    setState(() {
      pending = buy;
      error = null;
    });
    try {
      final controller = ref.read(quickOrderProvider.notifier);
      // An order is prepared only once background reads have settled.
      await controller.settle();
      if (!mounted) return;
      final percent = ref.read(quickOrderProvider).percent != null;
      if (!await _ensureSizing(percent: percent) || !mounted) return;
      if (controller.validation(buy) case final failure?) {
        return setState(() => error = tr(context, failure));
      }
      final intent = controller.prepare(buy);
      if (intent == null) return;
      // The confirmation owns the pending state; submission shows its own progress.
      setState(() => pending = null);
      await reviewQuickOrder(context, ref, intent);
    } finally {
      if (mounted && pending == buy) setState(() => pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickOrderProvider), live = ref.watch(liveOrderProvider);
    final auth = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);
    ref.listen(symbolProvider, (_, _) {
      if (error != null) setState(() => error = null);
    });
    // Each renewed account snapshot (or a newly active grant) gets fresh sizing.
    ref.listen(liveOrderProvider.select((s) => s.context), (_, _) => _prefetch());
    ref.listen(tradingAgentProvider, (_, _) => _prefetch());
    final data = live.context?.symbol == ref.watch(symbolProvider) ? live.context : null;
    final quoteAsset = data?.rules.quoteAsset ?? ref.watch(selectedInstrumentProvider)?.quote;
    // Background reads and setting leases never lock the bar (that would close
    // the keyboard and drop taps); a tap during them waits for them instead.
    // Only this entry's own read, an order being submitted, an auth change and
    // an unknown outcome lock it.
    final busy =
        state.loading || live.busy && live.intent != null || live.needsRecheck || auth.busy;
    final text = state.percent == null ? state.quantity : '${state.percent}%';
    if (quantity.text != text) quantity.text = text;
    final available = data?.funds?.account.availableBalance;
    final submitting = live.busy && live.intent?.draft.quickEntry == true;
    bool loading(bool buy) => pending == buy || submitting && live.intent?.draft.buy == buy;
    return TextFieldTapRegion(
      child: Column(
        key: const Key('quick-order-panel'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error case final text?) ...[_ErrorBanner(text), const SizedBox(height: 10)],
          if (focus.hasFocus) ...[
            _PercentShortcuts(
              selected: state.percent,
              onTap: busy || pending != null ? null : _percent,
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: _QuantityField(
                  controller: quantity,
                  focus: focus,
                  label: l10n.quickOrderAmount(quoteAsset ?? '—'),
                  hint: l10n.quickOrderAvailable(
                    available == null
                        ? '—'
                        : '${TokenAmountFormatter.formatCompact(DecimalValue(available.toString()))} '
                              '${data!.rules.quoteAsset}',
                  ),
                  enabled: !busy && pending == null,
                  onChanged: (value) {
                    if (error != null) setState(() => error = null);
                    ref.read(quickOrderProvider.notifier).setQuantity(value.replaceAll('%', ''));
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Both directions share the remaining half and grow together when
              // a long quote wraps.
              Expanded(
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final buy in [true, false]) ...[
                        if (!buy) const SizedBox(width: 6),
                        Expanded(
                          child: _DirectionButton(
                            buy: buy,
                            loading: loading(buy),
                            onTap: busy || pending != null ? null : () => _submit(buy),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectionButton extends ConsumerWidget {
  const _DirectionButton({required this.buy, required this.loading, required this.onTap});
  final bool buy, loading;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(bookProvider);
    final book = feed.isLoading || feed.hasError ? null : feed.value;
    final levels = book == null || !book.connected || book.offline
        ? null
        : buy
        ? book.asks
        : book.bids;
    final decimals = ref.watch(selectedPrecisionProvider).priceDecimals;
    final l10n = AppLocalizations.of(context);
    final style = TradeTypography.body.copyWith(color: TradeColors.onDirection);
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: buy ? TradeColors.positive : TradeColors.negative,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(buy ? 'quick-order-buy' : 'quick-order-sell'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Line(
                    buy ? l10n.quickOrderMarketBuy : l10n.quickOrderMarketSell,
                    style.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (loading)
                    const SizedBox.square(
                      key: Key('quick-order-loading'),
                      dimension: 16,
                      child: Padding(
                        padding: EdgeInsets.all(1),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TradeColors.onDirection,
                        ),
                      ),
                    )
                  else
                    // Centered on one line when it fits; wraps only when it does not.
                    Text(
                      levels == null || levels.isEmpty
                          ? '—'
                          : marketNumber(levels.first.price, minimumDecimals: decimals),
                      textAlign: TextAlign.center,
                      style: TradeTypography.caption.copyWith(color: TradeColors.secondary),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.controller,
    required this.focus,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final String label, hint;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final focused = focus.hasFocus;
    final value = TradeTypography.body.copyWith(fontSize: 14, height: 20 / 14);
    return GestureDetector(
      onTap: focus.requestFocus,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TradeColors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: focused ? TradeColors.accent : TradeColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TradeTypography.tag.copyWith(color: TradeColors.secondary),
            ),
            const SizedBox(height: 2),
            // Keep the designed 20px value line; the whole field box focuses it.
            SizedBox(
              height: 20,
              child: TextField(
                key: const Key('quick-order-quantity'),
                controller: controller,
                focusNode: focus,
                readOnly: !enabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                cursorColor: TradeColors.accent,
                cursorHeight: 16,
                style: value,
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(height: 20),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: hint,
                  hintMaxLines: 1,
                  hintStyle: focused
                      ? value
                      : value.copyWith(color: TradeColors.muted, fontWeight: FontWeight.w700),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('quick-order-error'),
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: TradeColors.errorLabel,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Semantics(
      liveRegion: true,
      child: Text(text, style: TradeTypography.body.copyWith(color: TradeColors.negative)),
    ),
  );
}

/// Design row of four equal shortcuts, left-aligned above the amount field.
/// Its 208px width grows with the text scale and never exceeds the panel.
class _PercentShortcuts extends StatelessWidget {
  const _PercentShortcuts({required this.selected, required this.onTap});
  final int? selected;
  final ValueChanged<int>? onTap;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.textScalerOf(context).scale(208);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Row(
          children: [
            for (final percent in [25, 50, 75, 100]) ...[
              if (percent != 25) const SizedBox(width: 4),
              Expanded(
                child: _PercentChip(
                  key: ValueKey('quick-order-percent-$percent'),
                  percent: percent,
                  selected: selected == percent,
                  onTap: onTap == null ? null : () => onTap!(percent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  const _PercentChip({
    super.key,
    required this.percent,
    required this.selected,
    required this.onTap,
  });
  final int percent;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: TradeColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: TradeColors.line),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 26),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              // Shrinks only when a narrow panel with enlarged text cannot fit it.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$percent%',
                  maxLines: 1,
                  style: TradeTypography.caption.copyWith(color: TradeColors.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, this.style);
  final String text;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, style: style),
  );
}
