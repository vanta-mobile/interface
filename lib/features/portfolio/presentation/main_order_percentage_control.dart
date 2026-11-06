import '../../../core/errors/error_text.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/live_order_provider.dart';
import '../application/main_order_allocation_provider.dart';
import '../application/main_order_capacity_provider.dart';
import '../application/main_order_refresh_provider.dart';
import '../application/main_order_pricing_provider.dart';
import '../domain/account_snapshot.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/main_order_allocation.dart';
import '../domain/live_order_size.dart';

class MainOrderPercentageControl extends ConsumerWidget {
  const MainOrderPercentageControl({
    super.key,
    this.unit = OrderSizeUnit.quote,
    this.manualCheck = true,
  });
  final OrderSizeUnit unit;
  final bool manualCheck;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(mainOrderAllocationProvider);
    ref.watch(mainOrderCapacityProvider);
    ref.watch(liveOrderProvider);
    ref.watch(symbolSettingsActivityProvider);
    ref.watch(mainOrderRefreshProvider);
    final controller = ref.read(mainOrderAllocationProvider.notifier);
    final pricing = ref.watch(mainOrderPricingProvider);
    var available = false;
    final snapshot = ref.read(mainOrderCapacityProvider.notifier).current;
    if (snapshot != null) {
      try {
        pricing.revalue(snapshot);
        available = true;
      } on AccountReadFailure {
        /* Missing prices keep the slider disabled. */
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.liveAllocationPercent(state.percent ?? 0)),
        // Keep the adjustable control in its own accessible subtree while the
        // dialog route closes and the form changes between enabled/disabled.
        Semantics(
          container: true,
          child: Slider(
            key: const Key('main-order-percentage'),
            min: 0,
            max: 100,
            divisions: 100,
            value: (state.percent ?? 0).toDouble(),
            label: '${state.percent ?? 0}%',
            semanticFormatterCallback: (value) => l10n.liveAllocationPercent(value.round()),
            onChanged: available && controller.editable
                ? (value) => controller.selectPercent(value.round())
                : null,
          ),
        ),
        if (state.percent == null) Text(l10n.liveAllocationManual),
        Text(
          state.percent == null && manualCheck
              ? l10n.liveAllocationManualHint
              : l10n.liveAllocationHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (state.preparing) Text(l10n.liveAllocationChecking),
        if (state.failure case final failure?)
          Text(
            failure is MainOrderCapacityExceeded
                ? l10n.liveAllocationMaximumChanged(
                    failure.capacity.buy ? l10n.long : l10n.short,
                    unit == OrderSizeUnit.quote
                        ? '≈ ${failure.capacity.maximumQuote}'
                        : '${failure.capacity.maximum}',
                    unit == OrderSizeUnit.quote
                        ? failure.context.rules.quoteAsset
                        : failure.context.rules.baseAsset,
                  )
                : accountErrorText(context, failure),
            key: const Key('main-order-allocation-failure'),
            style: const TextStyle(color: AppColors.negative),
          ),
      ],
    );
  }
}

class MainOrderAllocationTerms extends StatelessWidget {
  const MainOrderAllocationTerms({super.key, required this.review});
  final MainOrderAllocationReview review;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), unit = review.intent.context.rules.quoteAsset;
    return Column(
      key: const Key('main-order-frozen-capacity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.liveAllocationFrozen),
        ValueRow(
          l10n.liveCapacityMaximum,
          '${review.side.capacity!.maximum} ${review.intent.context.rules.baseAsset}',
        ),
        ValueRow(
          l10n.liveCapacityCost,
          '≈ ${review.side.cost!.total.toDecimal(scaleOnInfinitePrecision: 18)} $unit',
        ),
        Text(l10n.accountSnapshotTime(review.capacity.receivedAt.toUtc().toIso8601String())),
      ],
    );
  }
}
