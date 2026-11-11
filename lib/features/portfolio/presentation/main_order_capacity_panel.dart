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
import '../application/symbol_settings_activity.dart';
import '../domain/live_order.dart';
import '../domain/live_order_size.dart';
import '../domain/main_order_capacity_preview.dart';
import 'main_order_direction_card.dart';
import '../domain/main_order_capacity.dart';
import '../domain/main_order_allocation.dart';

part 'main_order_capacity_full.dart';

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
    this.compact = false,
    this.reviewWithoutPreview = false,
    this.onRefresh,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final ready =
        !refreshing &&
        !auth.busy &&
        auth.identity?.signingAvailable == true &&
        auth.identity?.walletAddress?.toLowerCase() == data.address.toLowerCase() &&
        selectedSymbol == data.symbol &&
        !state.loading &&
        !allocation.preparing &&
        !live.busy &&
        !live.needsRecheck &&
        live.context == data &&
        !operation.busy &&
        operation.owner == null &&
        !operation.recoveryBlocked &&
        !operation.unresolved;
    final enabled = ready && !live.stale;
    final facts = (
      state: state,
      allocation: allocation,
      live: live,
      controller: controller,
      preview: preview,
      refreshing: refreshing,
      ready: ready,
      enabled: enabled,
    );
    return compact ? _compactPanel(context, facts) : _fullPanel(context, ref, facts);
  }

  Widget _compactPanel(BuildContext context, _PanelFacts facts) {
    final (:state, :allocation, :live, :controller, :preview, :refreshing, :ready, :enabled) =
        facts;
    final expired =
        live.stale || state.stale || state.snapshot == null || controller.current == null;
    bool reviewable(MainOrderSidePreview? side) =>
        reviewWithoutPreview ||
        (side?.failure == null || side?.failure?.key == 'liveCapacityAboveMaximum') &&
            (side?.quantity ?? Decimal.zero) > Decimal.zero;
    VoidCallback? action(bool buy) {
      if (!ready) return null;
      // Expired data can always be re-read; review follows only when the
      // form had a reviewable size before the refresh.
      if (expired && onRefresh != null) {
        return () async {
          if (await onRefresh!(buy)) onReview?.call(buy);
        };
      }
      return enabled && onReview != null && reviewable(buy ? preview?.buy : preview?.sell)
          ? () => onReview!(buy)
          : null;
    }

    return Column(
      key: const Key('main-order-capacity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.failure case final failure?)
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
              showFailure: input.trim().isNotEmpty || (percent ?? 0) > 0,
              showLiquidation: draft.trigger == null && draft.trailing == null,
              pending:
                  (allocation.preparing || live.busy || refreshing || state.loading) &&
                  draft.buy == buy,
              onReview: action(buy),
            ),
          ),
      ],
    );
  }
}

typedef _PanelFacts = ({
  MainOrderCapacityState state,
  MainOrderAllocationState allocation,
  LiveOrderState live,
  MainOrderCapacityController controller,
  MainOrderCapacityPreview? preview,
  bool refreshing,
  bool ready,
  bool enabled,
});
