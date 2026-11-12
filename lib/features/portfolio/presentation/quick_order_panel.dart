import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/strings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../market/application/market_providers.dart'
    show selectedInstrumentProvider, selectedPrecisionProvider;
import '../../market/domain/market_precision.dart';
import '../../trade/application/providers.dart';
import '../../trade/presentation/trade_theme.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../application/quick_order_provider.dart';
import '../application/symbol_settings_activity.dart';
import 'quick_order_review.dart';

/// Chart-tab quick market entry pinned above the bottom navigation: Market Buy,
/// an independent base-asset quantity and Market Sell. Percent shortcuts appear
/// while the quantity is being edited.
class QuickOrderPanel extends ConsumerStatefulWidget {
  const QuickOrderPanel({super.key});
  @override
  ConsumerState<QuickOrderPanel> createState() => _QuickOrderPanelState();
}

class _QuickOrderPanelState extends ConsumerState<QuickOrderPanel> {
  final quantity = TextEditingController();
  final focus = FocusNode();
  bool? pending;

  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
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
    if (failure != null) message(this.context, accountErrorText(this.context, failure));
    return failure == null && controller.context != null;
  }

  Future<void> _percent(int value) async {
    if (!_connected) {
      showAccountSheet(context);
      return;
    }
    if (await _ensureSizing(percent: true)) {
      ref.read(quickOrderProvider.notifier).selectPercent(value);
    }
  }

  Future<void> _submit(bool buy) async {
    if (!_connected) {
      showAccountSheet(context);
      return;
    }
    if (pending != null) return;
    setState(() => pending = buy);
    try {
      final controller = ref.read(quickOrderProvider.notifier);
      final percent = ref.read(quickOrderProvider).percent != null;
      if (!await _ensureSizing(percent: percent) || !mounted) return;
      if (controller.validation(buy) case final failure?) {
        return message(context, tr(context, failure));
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
    final auth = ref.watch(authProvider), activity = ref.watch(symbolSettingsActivityProvider);
    final l10n = AppLocalizations.of(context);
    final data = live.context?.symbol == ref.watch(symbolProvider) ? live.context : null;
    final baseAsset = data?.rules.baseAsset ?? ref.watch(selectedInstrumentProvider)?.base;
    // An unknown outcome is verified before another quick order can be entered.
    final busy = state.loading || live.busy || live.needsRecheck || auth.busy || activity.busy;
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
          Row(
            children: [
              Expanded(
                child: _DirectionButton(
                  buy: true,
                  loading: loading(true),
                  onTap: busy || pending != null ? null : () => _submit(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuantityField(
                  controller: quantity,
                  focus: focus,
                  label: l10n.quickOrderAmount(baseAsset ?? '—'),
                  hint: l10n.quickOrderAvailable(
                    available == null
                        ? '—'
                        : '${TokenAmountFormatter.formatCompact(DecimalValue(available.toString()))} '
                              '${data!.rules.quoteAsset}',
                  ),
                  enabled: !busy && pending == null,
                  onChanged: (value) =>
                      ref.read(quickOrderProvider.notifier).setQuantity(value.replaceAll('%', '')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DirectionButton(
                  buy: false,
                  loading: loading(false),
                  onTap: busy || pending != null ? null : () => _submit(false),
                ),
              ),
            ],
          ),
          if (focus.hasFocus) ...[
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final percent in [25, 50, 75, 100])
                  _PercentChip(
                    key: ValueKey('quick-order-percent-$percent'),
                    percent: percent,
                    selected: state.percent == percent,
                    onTap: busy || pending != null ? null : () => _percent(percent),
                  ),
              ],
            ),
          ],
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
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(buy ? 'quick-order-buy' : 'quick-order-sell'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Line(
                    buy ? l10n.quickOrderMarketBuy : l10n.quickOrderMarketSell,
                    style.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  if (loading)
                    const SizedBox.square(
                      key: Key('quick-order-loading'),
                      dimension: 20,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TradeColors.onDirection,
                        ),
                      ),
                    )
                  else
                    _Line(
                      levels == null || levels.isEmpty
                          ? '—'
                          : marketNumber(levels.first.price, minimumDecimals: decimals),
                      style.copyWith(fontSize: 14, height: 20 / 14),
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
        padding: const EdgeInsets.all(8),
        decoration: ShapeDecoration(
          color: TradeColors.card,
          shape: StadiumBorder(
            side: focused ? const BorderSide(color: TradeColors.accent) : BorderSide.none,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Line(label, TradeTypography.body),
            const SizedBox(height: 2),
            // Keep the designed 20px value line; the whole pill focuses the field.
            SizedBox(
              height: 20,
              child: TextField(
                key: const Key('quick-order-quantity'),
                controller: controller,
                focusNode: focus,
                readOnly: !enabled,
                textAlign: TextAlign.center,
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
    final radius = BorderRadius.circular(4);
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
            constraints: const BoxConstraints(minHeight: 26, minWidth: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '$percent%',
                textAlign: TextAlign.center,
                style: TradeTypography.caption.copyWith(color: TradeColors.text),
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
