import '../../../core/errors/error_text.dart';
import 'order_recovery_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../trade/application/providers.dart';
import '../../market/application/market_providers.dart' show selectedInstrumentProvider;
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../application/order_confirmation_provider.dart';
import '../application/quick_order_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/live_order.dart';
import '../domain/quick_order.dart';
import 'live_order_status.dart';
import 'quick_order_review.dart';
import 'quick_order_account_settings.dart';

class QuickOrderPanel extends ConsumerStatefulWidget {
  const QuickOrderPanel({super.key});
  @override
  ConsumerState<QuickOrderPanel> createState() => _QuickOrderPanelState();
}

class _QuickOrderPanelState extends ConsumerState<QuickOrderPanel> {
  final quantity = TextEditingController();
  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickOrderProvider), live = ref.watch(liveOrderProvider);
    final auth = ref.watch(authProvider), activity = ref.watch(symbolSettingsActivityProvider);
    final controller = ref.read(quickOrderProvider.notifier), l10n = AppLocalizations.of(context);
    final data = live.context?.symbol == ref.watch(symbolProvider) ? live.context : null;
    final baseAsset = data?.rules.baseAsset ?? ref.watch(selectedInstrumentProvider)?.base;
    final disabled = state.loading || live.busy || auth.busy || activity.busy;
    final preference = ref.watch(marketOrderConfirmationProvider);
    if (quantity.text != state.quantity) quantity.text = state.quantity;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          key: const Key('quick-order-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OrderRecoveryNotice(showOrders: false),
            Text(l10n.quickOrderTitle, style: Theme.of(context).textTheme.titleMedium),
            Text(l10n.quickOrderHint),
            SelectableText(ref.watch(symbolProvider)),
            if (auth.identity?.walletAddress case final address?) SelectableText(address),
            OutlinedButton.icon(
              key: const Key('quick-order-read'),
              onPressed: disabled || activity.owner != null
                  ? null
                  : auth.identity?.signingAvailable == true && auth.identity?.walletAddress != null
                  ? controller.load
                  : () => showAccountSheet(context),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.quickOrderRead),
            ),
            Text(l10n.quickOrderReadHint),
            if (state.loading || live.busy) const LinearProgressIndicator(),
            QuickOrderAccountSettings(data: data),
            if (data != null && live.stale) Text(l10n.liveOrderContextExpired),
            _QuickOrderInput(
              quantity: quantity,
              state: state,
              data: data,
              baseAsset: baseAsset,
              disabled: disabled,
            ),
            if (state.failure case final failure?) ...[
              Text(
                accountErrorText(context, failure),
                style: const TextStyle(color: AppColors.negative),
              ),
              Text(l10n.quickOrderSizingFailure),
            ],
            _QuickOrderButtons(
              buy: disabled ? null : controller.prepare(true),
              sell: disabled ? null : controller.prepare(false),
            ),
            SwitchListTile(
              key: const Key('quick-order-confirmation-preference'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.quickOrderConfirmPreference),
              value: preference.required,
              onChanged: disabled || preference.loading
                  ? null
                  : ref.read(marketOrderConfirmationProvider.notifier).select,
            ),
            if (preference.failure) Text(l10n.quickOrderPreferenceFailure),
            const LiveOrderStatus(),
          ],
        ),
      ),
    );
  }
}

class _QuickOrderInput extends ConsumerWidget {
  const _QuickOrderInput({
    required this.quantity,
    required this.state,
    required this.data,
    required this.baseAsset,
    required this.disabled,
  });
  final TextEditingController quantity;
  final QuickOrderState state;
  final LiveOrderContext? data;
  final String? baseAsset;
  final bool disabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(quickOrderProvider.notifier), l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('quick-order-quantity'),
          controller: quantity,
          readOnly: disabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.liveOrderQuantity(baseAsset ?? '—'),
            helperText: state.percent == null
                ? l10n.quickOrderIndependent
                : l10n.quickOrderPercentSelected(state.percent!),
            helperMaxLines: 4,
          ),
          onChanged: controller.setQuantity,
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final percent in [25, 50, 75, 100])
              ChoiceChip(
                key: ValueKey('quick-order-percent-$percent'),
                label: Text('$percent%'),
                selected: state.percent == percent,
                onSelected: disabled || state.sizing == null || controller.context == null
                    ? null
                    : (_) => controller.selectPercent(percent),
              ),
          ],
        ),
        if (state.percent != null) ...[
          ValueRow(
            l10n.quickOrderBuyQuantity,
            '${controller.quantity(true) ?? '—'} ${data?.rules.baseAsset ?? ''}',
          ),
          ValueRow(
            l10n.quickOrderSellQuantity,
            '${controller.quantity(false) ?? '—'} ${data?.rules.baseAsset ?? ''}',
          ),
        ],
        Text(l10n.quickOrderSizingHint, style: Theme.of(context).textTheme.bodySmall),
        if (state.quantity.trim().isNotEmpty || state.percent != null)
          for (final buy in [true, false])
            if (controller.validation(buy) case final failure?)
              Text(
                '${buy ? l10n.quickOrderBuy : l10n.quickOrderSell}: ${tr(context, failure)}',
                style: const TextStyle(color: AppColors.negative),
              ),
      ],
    );
  }
}

class _QuickOrderButtons extends ConsumerWidget {
  const _QuickOrderButtons({required this.buy, required this.sell});
  final LiveOrderIntent? buy, sell;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(bookProvider);
    final book = feed.isLoading || feed.hasError ? null : feed.value;
    final live = book != null && book.connected && !book.offline;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in [(true, buy), (false, sell)])
          FilledButton(
            key: ValueKey(entry.$1 ? 'quick-order-buy' : 'quick-order-sell'),
            style: FilledButton.styleFrom(
              backgroundColor: entry.$1 ? AppColors.positive : AppColors.negative,
              foregroundColor: AppColors.onAccent,
            ),
            onPressed: entry.$2 == null ? null : () => reviewQuickOrder(context, ref, entry.$2!),
            child: Column(
              children: [
                Text(entry.$1 ? l10n.quickOrderBuy : l10n.quickOrderSell),
                Text(
                  live && (entry.$1 ? book.asks : book.bids).isNotEmpty
                      ? '${(entry.$1 ? book.asks : book.bids).first.price} USDT'
                      : '—',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
