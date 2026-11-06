import '../../../core/errors/error_text.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/decimal_value.dart';
import '../../../core/formatters/token_amount_formatter.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../market/application/selection_providers.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../application/main_order_allocation_provider.dart';
import '../application/main_order_capacity_provider.dart';
import '../application/main_order_refresh_provider.dart';
import '../application/main_order_capacity_preview_provider.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';
import '../domain/main_order_capacity_preview.dart';

/// Explicit read only. Rebuilding, editing inputs or switching order types
/// never starts a request or wallet prompt, and failure never edits the draft.
class MainOrderCapacityPanel extends ConsumerWidget {
  const MainOrderCapacityPanel({
    super.key,
    required this.data,
    required this.draft,
    required this.unit,
    required this.input,
    this.percent,
    this.onReview,
    this.showReview = false,
  });
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  final OrderSizeUnit unit;
  final String input;
  final int? percent;
  final ValueChanged<bool>? onReview;
  final bool showReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(mainOrderCapacityProvider);
    final allocation = ref.watch(mainOrderAllocationProvider);
    final live = ref.watch(liveOrderProvider);
    final operation = ref.watch(symbolSettingsActivityProvider);
    final auth = ref.watch(authProvider);
    final selectedSymbol = ref.watch(symbolProvider);
    final controller = ref.read(mainOrderCapacityProvider.notifier);
    final preview = ref.watch(
      mainOrderCapacityPreviewProvider((
        context: data,
        draft: draft,
        unit: unit,
        input: input,
        percent: percent,
      )),
    );
    final refreshing = ref.watch(mainOrderRefreshProvider).loading;
    final enabled =
        !refreshing &&
        !auth.busy &&
        auth.identity?.signingAvailable == true &&
        auth.identity?.walletAddress?.toLowerCase() == data.address.toLowerCase() &&
        selectedSymbol == data.symbol &&
        !state.loading &&
        !allocation.preparing &&
        !live.busy &&
        !live.needsRecheck &&
        !live.stale &&
        live.context == data &&
        !operation.busy &&
        operation.owner == null &&
        !operation.recoveryBlocked &&
        !operation.unresolved;
    return Column(
      key: const Key('main-order-capacity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(l10n.liveCapacityTitle, style: Theme.of(context).textTheme.titleSmall),
        Text(l10n.liveCapacityReadHint, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('main-order-capacity-read'),
              onPressed: enabled ? () => controller.load(data.symbol) : null,
              child: Text(l10n.liveCapacityRead),
            ),
            if (state.loading || allocation.preparing)
              TextButton(
                key: const Key('main-order-capacity-stop'),
                onPressed: () {
                  if (refreshing) {
                    ref.read(mainOrderRefreshProvider.notifier).stop();
                    return;
                  }
                  ref.read(mainOrderAllocationProvider.notifier).stop();
                  controller.stop();
                },
                child: Text(l10n.cancel),
              ),
          ],
        ),
        if (state.loading || allocation.preparing) ...[
          const LinearProgressIndicator(),
          Text(allocation.preparing ? l10n.liveAllocationChecking : l10n.accountReadLoading),
        ],
        if (state.failure case final failure?)
          Text(
            accountErrorText(context, failure),
            style: const TextStyle(color: AppColors.negative),
          ),
        if (state.stale && !state.loading && state.snapshot != null)
          Text(l10n.liveCapacityStale, style: const TextStyle(color: AppColors.warning)),
        if (preview != null && controller.current != null)
          Text(l10n.accountSnapshotTime(state.snapshot!.receivedAt.toUtc().toIso8601String())),
        LayoutBuilder(
          builder: (context, constraints) {
            final buy = _Side(
              value: preview?.buy,
              data: data,
              unit: unit,
              buy: true,
              pending: allocation.preparing && draft.buy,
              onReview: enabled && onReview != null ? () => onReview!(true) : null,
              showReview: showReview || onReview != null,
            );
            final sell = _Side(
              value: preview?.sell,
              data: data,
              unit: unit,
              buy: false,
              pending: allocation.preparing && !draft.buy,
              onReview: enabled && onReview != null ? () => onReview!(false) : null,
              showReview: showReview || onReview != null,
            );
            return constraints.maxWidth < 520 || MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [buy, sell])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: buy),
                      const SizedBox(width: 12),
                      Expanded(child: sell),
                    ],
                  );
          },
        ),
        Text(l10n.liveCapacityEstimateHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.value,
    required this.data,
    required this.unit,
    required this.buy,
    this.onReview,
    this.showReview = false,
    this.pending = false,
  });
  final MainOrderSidePreview? value;
  final LiveOrderContext data;
  final OrderSizeUnit unit;
  final bool buy;
  final VoidCallback? onReview;
  final bool showReview;
  final bool pending;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), side = buy ? 'buy' : 'sell';
    final cost = value?.cost;
    return Card(
      key: Key('main-order-capacity-$side'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(buy ? l10n.long : l10n.short, style: Theme.of(context).textTheme.titleSmall),
            ValueRow(
              l10n.liveCapacityMaximum,
              value?.capacity == null
                  ? '—'
                  : unit == OrderSizeUnit.quote
                  ? '≈ ${value!.capacity!.maximumQuote} ${data.rules.quoteAsset}'
                  : '${value!.capacity!.maximum} ${data.rules.baseAsset}',
              key: Key('main-order-maximum-$side'),
            ),
            ValueRow(
              l10n.liveOrderQuantity(data.rules.baseAsset),
              value?.quantity == null ? '—' : '${value!.quantity} ${data.rules.baseAsset}',
            ),
            ValueRow(
              l10n.liveOrderEstimatedNotional,
              value?.notional == null ? '—' : '${value!.notional} ${data.rules.quoteAsset}',
            ),
            ValueRow(
              l10n.liveCapacityCost,
              cost == null
                  ? '—'
                  : '≈ ${cost.total.toDecimal(scaleOnInfinitePrecision: 18)} ${data.rules.quoteAsset}',
              key: Key('main-order-cost-$side'),
            ),
            ValueRow(
              l10n.liveCapacityLiquidation,
              _liquidationText(),
              key: Key('main-order-liquidation-$side'),
            ),
            if (value?.failure case final failure?)
              Text(
                accountErrorText(context, failure),
                style: const TextStyle(color: AppColors.warning),
              ),
            if (showReview)
              FilledButton(
                key: Key('main-order-review-$side'),
                onPressed:
                    (value?.failure == null || value?.failure?.key == 'liveCapacityAboveMaximum') &&
                        (value?.quantity ?? Decimal.zero) > Decimal.zero
                    ? onReview
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pending)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    Text(buy ? l10n.liveAllocationReviewBuy : l10n.liveAllocationReviewSell),
                    Text(
                      value?.quantity == null
                          ? '—'
                          : unit == OrderSizeUnit.quote
                          ? '≈ ${value!.size?.estimatedNotional ?? value!.notional} ${data.rules.quoteAsset}'
                          : '${value!.quantity} ${data.rules.baseAsset}',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _liquidationText() {
    final price = value?.liquidation, precision = data.rules.pricePrecision;
    if (price == null || precision == null || precision < 0 || precision > 80) return '—';
    final rounded = price.toDecimal(
      scaleOnInfinitePrecision: precision,
      toBigInt: (r) => r.round(),
    );
    if (rounded <= Decimal.zero) return '—';
    return '≈ ${TokenAmountFormatter.formatFixed(DecimalValue(rounded.toString()), decimals: precision)} ${data.rules.quoteAsset}';
  }
}
