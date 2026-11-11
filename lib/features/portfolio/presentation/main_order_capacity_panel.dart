import '../../../core/errors/error_text.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../application/main_order_pricing_provider.dart';
import '../domain/main_order_pricing.dart';
import '../application/symbol_settings_activity.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';
import '../domain/main_order_capacity_preview.dart';
import 'main_order_direction_card.dart';
import '../domain/main_order_capacity.dart';
import '../domain/main_order_allocation.dart';
import '../domain/account_snapshot.dart';

part 'main_order_capacity_full.dart';

/// Explicit read only. Rebuilding, editing inputs or switching order types
/// never starts a request or wallet prompt, and failure never edits the draft.
class MainOrderCapacityPanel extends ConsumerStatefulWidget {
  const MainOrderCapacityPanel({
    super.key,
    required this.data,
    required this.draft,
    required this.unit,
    required this.input,
    this.percent,
    this.onReview,
    this.showReview = false,
    this.compact = false,
    this.reviewWithoutPreview = false,
    this.onRefresh,
    this.refreshingReviewDirection,
  });
  final LiveOrderContext data;
  final LiveOrderDraft draft;
  final OrderSizeUnit unit;
  final String input;
  final int? percent;
  final ValueChanged<bool>? onReview;
  final bool showReview;

  /// Trade-workspace layout: designed direction cards only. Account reads are
  /// started by the workspace itself, so no read controls are shown.
  final bool compact;

  /// Compound-entry pegs are reviewed from the form's own intent, not the
  /// allocation preview, so their buttons do not wait for a preview quantity.
  final bool reviewWithoutPreview;

  /// Compact only: re-reads expired order data before a direction is
  /// reviewed. Returns whether the refresh completed.
  final Future<bool> Function(bool buy)? onRefresh;
  final bool? refreshingReviewDirection;

  @override
  ConsumerState<MainOrderCapacityPanel> createState() => _MainOrderCapacityPanelState();

  Widget _compactPanel(BuildContext context, _PanelFacts facts, {required bool canRequestReview}) {
    final (
      :state,
      :allocation,
      :live,
      :controller,
      :preview,
      :refreshing,
      ready: _,
      :enabled,
      resultsPending: _,
      retainedMaximum: _,
      :readFailure,
    ) = facts;
    final expired =
        refreshing ||
        live.stale ||
        state.stale ||
        state.snapshot == null ||
        controller.current == null;
    final hasSize = percent != null
        ? percent! > 0
        : (parseOrderDecimal(input.trim()) ?? Decimal.zero) > Decimal.zero;
    bool reviewable(MainOrderSidePreview? side) =>
        reviewWithoutPreview ||
        (side?.failure == null || side?.failure?.key == 'liveCapacityAboveMaximum') &&
            (side?.quantity ?? Decimal.zero) > Decimal.zero;
    VoidCallback? action(bool buy) {
      if (!canRequestReview || !hasSize || onReview == null) return null;
      // A direction click refreshes pending/stale facts before review.
      if (expired && onRefresh != null) {
        return () async {
          if (await onRefresh!(buy)) onReview?.call(buy);
        };
      }
      return enabled && reviewable(buy ? preview?.buy : preview?.sell)
          ? () => onReview!(buy)
          : null;
    }

    return Column(
      key: const Key('main-order-capacity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (readFailure case final failure?
            when !refreshing &&
                (hasSize ||
                    !const {
                      'liveCapacityPriceUnavailable',
                      'liveCapacityRatesUnavailable',
                    }.contains(failure.key)))
          Text(
            accountErrorText(context, failure),
            style: const TextStyle(color: AppColors.negative),
          ),
        for (final buy in [true, false])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MainOrderDirectionCard(
              value: buy ? preview?.buy : preview?.sell,
              data: data,
              unit: unit,
              buy: buy,
              hasSize: hasSize,
              showFailure: !refreshing && readFailure == null && hasSize,
              showLiquidation: draft.trigger == null && draft.trailing == null,
              resultsPending: facts.resultsPending,
              retainedCapacity: buy
                  ? facts.retainedMaximum?.buy.capacity
                  : facts.retainedMaximum?.sell.capacity,
              pending:
                  refreshingReviewDirection == buy ||
                  (allocation.preparing || live.busy && live.intent != null) && draft.buy == buy,
              onReview: action(buy),
            ),
          ),
      ],
    );
  }
}

/// Retained estimates are presentation only. All review actions still depend
/// on fresh controller state; changed form terms discard the old estimate.
class _MainOrderCapacityPanelState extends ConsumerState<MainOrderCapacityPanel> {
  Object? _previewTerms, _maximumTerms;
  MainOrderCapacityPreview? _lastPreview;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mainOrderCapacityProvider);
    final allocation = ref.watch(mainOrderAllocationProvider);
    final live = ref.watch(liveOrderProvider);
    final operation = ref.watch(symbolSettingsActivityProvider);
    final auth = ref.watch(authProvider);
    final selectedSymbol = ref.watch(symbolProvider);
    final controller = ref.read(mainOrderCapacityProvider.notifier);
    final currentPreview = ref.watch(
      mainOrderCapacityPreviewProvider((
        context: widget.data,
        draft: widget.draft,
        unit: widget.unit,
        input: widget.input,
        percent: widget.percent,
      )),
    );
    final source = ref.watch(mainOrderPricingProvider);
    final refreshing =
        ref.watch(mainOrderRefreshProvider).loading ||
        source is MainOrderMarketData && source.pending;
    final maximumTerms = (
      widget.data.address.toLowerCase(),
      widget.data.symbol,
      widget.data.leverage,
      widget.data.mode,
      widget.data.marginMode,
      liveOrderDraftKey(widget.draft.withQuantity('').withDirection(true)),
      widget.unit,
    );
    final terms = (maximumTerms, widget.input, widget.percent);
    final refresh = ref.watch(mainOrderRefreshProvider);
    final readFailure = refresh.failure ?? live.failure ?? state.failure;
    final retaining =
        refreshing ||
        allocation.preparing ||
        refresh.background && readFailure != null ||
        live.stale && (readFailure == null || refresh.background);
    final preview = retaining && _previewTerms == terms ? _lastPreview : currentPreview;
    final retainedMaximum = retaining && _maximumTerms == maximumTerms ? _lastPreview : null;
    if (!retaining &&
        currentPreview != null &&
        (currentPreview.buy.capacity != null || currentPreview.sell.capacity != null)) {
      _maximumTerms = maximumTerms;
      _previewTerms = terms;
      _lastPreview = currentPreview;
    }
    final resultsPending =
        retaining && (refreshing || readFailure == null) && _previewTerms != terms;
    final ready =
        !refreshing &&
        !auth.busy &&
        auth.identity?.signingAvailable == true &&
        auth.identity?.walletAddress?.toLowerCase() == widget.data.address.toLowerCase() &&
        selectedSymbol == widget.data.symbol &&
        !state.loading &&
        !allocation.preparing &&
        !live.busy &&
        live.context == widget.data &&
        !operation.busy &&
        operation.owner == null &&
        !operation.recoveryBlocked &&
        !operation.unresolved;
    final enabled = ready && !live.stale;
    final backgroundRead = refresh.loading && refresh.background && live.intent == null;
    // A click can take over a silent read and request fresh facts. It is not
    // evidence that cached estimates are safe to submit.
    final canRequestReview =
        widget.refreshingReviewDirection == null &&
        !auth.busy &&
        auth.identity?.signingAvailable == true &&
        auth.identity?.walletAddress?.toLowerCase() == widget.data.address.toLowerCase() &&
        selectedSymbol == widget.data.symbol &&
        (!refresh.loading || backgroundRead) &&
        (!state.loading || backgroundRead) &&
        (!live.busy || backgroundRead) &&
        !allocation.preparing &&
        live.context == widget.data &&
        (!operation.busy && operation.owner == null ||
            backgroundRead && operation.owner == SymbolSetting.order) &&
        !operation.recoveryBlocked &&
        !operation.unresolved;
    final facts = (
      state: state,
      allocation: allocation,
      live: live,
      controller: controller,
      preview: preview,
      resultsPending: resultsPending,
      retainedMaximum: retainedMaximum,
      refreshing: refreshing,
      ready: ready,
      enabled: enabled,
      readFailure: readFailure,
    );
    return widget.compact
        ? widget._compactPanel(context, facts, canRequestReview: canRequestReview)
        : widget._fullPanel(context, ref, facts);
  }
}

typedef _PanelFacts = ({
  MainOrderCapacityState state,
  MainOrderAllocationState allocation,
  LiveOrderState live,
  MainOrderCapacityController controller,
  MainOrderCapacityPreview? preview,
  bool resultsPending,
  MainOrderCapacityPreview? retainedMaximum,
  bool refreshing,
  bool ready,
  bool enabled,
  AccountReadFailure? readFailure,
});
