import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/trade_theme.dart';
import '../application/open_order_strategies_provider.dart';
import '../domain/account_snapshot.dart';
import '../domain/aster_open_orders.dart';
import 'futures_history_labels.dart';
import 'mode_settings_sheet.dart';
import 'order_choice_sheet.dart';

/// Design 331:77732: the OTO/OTOCO strategy behind a linked order — entry A,
/// then its take-profit B and stop-loss C, each with its current status.
Future<void> showOpenOrderStrategySheet(
  BuildContext context,
  AsterOpenOrder order,
  OpenOrderStrategy linked,
) => showModeSettingsSheet<void>(context, OpenOrderStrategySheet(order: order, linked: linked));

class OpenOrderStrategySheet extends ConsumerWidget {
  const OpenOrderStrategySheet({super.key, required this.order, required this.linked});
  final AsterOpenOrder order;

  /// The order's strategy linkage (from the row or the background read).
  final OpenOrderStrategy linked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final details = ref.watch(openOrderStrategyDetailsProvider((order: order, linked: linked)));
    return OrderChoiceSheet(
      key: const Key('open-order-strategy-sheet'),
      title: l10n.orderDetailsTitle,
      children: [
        const SizedBox(height: 8),
        switch (details) {
          AsyncData(:final value) => _StrategyTree(strategy: value, base: order.units?.base),
          AsyncError(:final error) => Text(
            error is AccountReadFailure && error.key == 'openOrdersStrategyClosed'
                ? l10n.orderDetailsClosed
                : accountErrorText(
                    context,
                    error is AccountReadFailure
                        ? error
                        : const AccountReadFailure('accountReadFailed'),
                  ),
            key: const Key('open-order-strategy-error'),
            style: TradeTypography.body.copyWith(color: TradeColors.negative),
          ),
          _ => const Column(
            key: Key('open-order-strategy-loading'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBox(height: 140, radius: 12),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsetsDirectional.only(start: 121),
                child: SkeletonBox(height: 160, radius: 12),
              ),
            ],
          ),
        },
      ],
    );
  }
}

/// Entry card across the full width; exit cards indented, joined to it by
/// the design's 2px connector lines.
class _StrategyTree extends StatelessWidget {
  const _StrategyTree({required this.strategy, required this.base});
  final OpenOrderStrategy strategy;
  final String? base;

  static const _exitWidth = 240.0, _lineX = 52.0, _gap = 20.0, _line = 2.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final legs = strategy.legs;
    final entry = legs.where((leg) => leg.sequence == 1).firstOrNull;
    final exits = legs.where((leg) => leg.sequence > 1).toList();
    String? hint(OpenOrderStrategyLeg leg) => switch (leg.sequence) {
      1 => exits.length > 1 ? l10n.orderDetailsPlacesBoth : l10n.orderDetailsPlacesOne,
      2 when exits.length > 1 => l10n.orderDetailsCancelsC,
      3 => l10n.orderDetailsCancelsB,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entry != null) _LegCard(leg: entry, hint: hint(entry), base: base),
        for (final (index, exit) in exits.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: _lineX - _line / 2),
                // Vertical trunk down to the last exit's middle; a branch
                // into each exit card.
                SizedBox(
                  width: _line,
                  child: Column(
                    children: [
                      Expanded(child: Container(color: TradeColors.line)),
                      Expanded(
                        child: index == exits.length - 1
                            ? const SizedBox.shrink()
                            : Container(color: TradeColors.line),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(height: _line, color: TradeColors.line),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: _gap),
                  child: SizedBox(
                    width: _exitWidth,
                    child: _LegCard(leg: exit, hint: hint(exit), base: base),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LegCard extends StatelessWidget {
  const _LegCard({required this.leg, required this.hint, required this.base});
  final OpenOrderStrategyLeg leg;
  final String? hint;
  final String? base;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entry = leg.sequence == 1;
    return Container(
      key: ValueKey('open-order-strategy-leg-${leg.sequence}'),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: entry ? 12 : 16),
      decoration: BoxDecoration(color: TradeColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.orderDetailsLeg(String.fromCharCode(0x40 + leg.sequence)),
            style: TradeTypography.section,
          ),
          if (hint case final text?) ...[
            const SizedBox(height: 8),
            Text(text, style: TradeTypography.body.copyWith(color: TradeColors.warning)),
          ],
          const SizedBox(height: 12),
          for (final (index, (label, value, color)) in <(String, String, Color?)>[
            (_type(l10n, leg.type), futuresHistoryStatus(l10n, leg.status), null),
            (
              l10n.orderDetailsSide,
              leg.buy ? l10n.openOrdersBuy : l10n.openOrdersSell,
              leg.buy ? TradeColors.positive : TradeColors.negative,
            ),
            (
              l10n.orderDetailsAmount,
              '${marketNumber(leg.quantity)} ${base ?? l10n.accountUnitUnavailable}',
              null,
            ),
            if (entry)
              (
                l10n.openOrdersReduceOnly,
                leg.reduceOnly ? l10n.openOrdersYes : l10n.openOrdersNo,
                null,
              )
            else
              (
                l10n.orderDetailsStop,
                leg.stopPrice == null ? '—' : marketNumber(leg.stopPrice!),
                null,
              ),
          ].indexed) ...[
            if (index > 0) const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TradeTypography.body.copyWith(color: TradeColors.secondary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(value, style: TradeTypography.body.copyWith(color: color)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _type(AppLocalizations l10n, String type) => switch (type) {
    'MARKET' => l10n.openOrdersMarket,
    'LIMIT' => l10n.limit,
    'TAKE_PROFIT_MARKET' => l10n.orderDetailsTpMarket,
    'STOP_MARKET' => l10n.orderDetailsSlMarket,
    'TAKE_PROFIT' => l10n.orderDetailsTpLimit,
    'STOP' => l10n.orderDetailsSlLimit,
    _ => futuresHistoryOrderType(l10n, type),
  };
}
