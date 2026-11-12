import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/position_mark_prices_provider.dart';
import '../application/position_risk_provider.dart';
import '../domain/position_risk.dart';
import '../../market/domain/mark_prices.dart';
import '../domain/position_valuation.dart';
import 'position_return_rows.dart';

/// Observe each symbol near its values so unrelated marks do not rebuild the
/// full account page, address, filters, or the signature controls.
class PositionValuationRows extends ConsumerWidget {
  const PositionValuationRows({super.key, required this.position});
  final PositionRisk position;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = position;
    final l10n = AppLocalizations.of(context);
    final (quote, fresh) = watchPositionMark(ref, p);
    final staleAccount = ref.watch(positionRiskProvider.select((s) => s.stale));
    final values = PositionValuation(position: p, quote: quote);
    final priceUnit = p.units == null ? null : '${p.units!.quote}/${p.units!.base}';
    String amount(Decimal? value, String? unit) =>
        value == null ? '—' : '${marketNumber(value)} ${unit ?? l10n.accountUnitUnavailable}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(
          quote == null
              ? l10n.positionMarkSnapshot
              : fresh
              ? l10n.positionMarkCurrent
              : l10n.positionMarkHistorical,
          amount(values.mark, priceUnit),
        ),
        if (quote != null) ...[
          ValueRow(
            l10n.positionMarkTime,
            DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(quote.eventTime.toUtc()),
          ),
          ValueRow(l10n.positionEstimatedNotional, amount(values.notional, p.units?.quote)),
          ValueRow(
            l10n.positionEstimatedPnl,
            amount(values.unrealizedProfit, p.units?.margin),
            color: values.unrealizedProfit == null || values.unrealizedProfit == Decimal.zero
                ? AppColors.text
                : values.unrealizedProfit! > Decimal.zero
                ? AppColors.positive
                : AppColors.negative,
          ),
          if (!fresh || staleAccount)
            Text(
              l10n.positionEstimateStale,
              key: Key('position-estimate-stale-${p.symbol}-${p.side}'),
              style: const TextStyle(color: AppColors.warning),
            ),
        ],
        ValueRow(l10n.positionSnapshotNotional, amount(p.notional, p.units?.quote)),
        ValueRow(
          p.eventTime == null ? l10n.positionSnapshotPnl : l10n.positionEventPnl,
          amount(p.unrealizedProfit, p.units?.margin),
        ),
        PositionReturnRows(
          position: p,
          mark: values.mark,
          pnl: quote == null ? p.unrealizedProfit : values.unrealizedProfit,
          publicMark: quote != null,
        ),
      ],
    );
  }
}

/// The public mark that may replace [p]'s snapshot values, with its freshness.
/// A newer private snapshot takes precedence until another public price is
/// received; a retained mark must not silently roll it back after refresh.
(MarkPriceQuote?, bool) watchPositionMark(WidgetRef ref, PositionRisk p) {
  final mark = ref.watch(
    positionMarkPricesProvider.select(
      (s) => (s.value?.quotes[p.symbol], s.value?.fresh.contains(p.symbol) == true),
    ),
  );
  final received = ref.watch(positionRiskProvider.select((s) => s.account?.receivedAt));
  final quote =
      p.balanceOnly ||
          received == null ||
          mark.$1 == null ||
          mark.$1!.receivedAt.isBefore(received) ||
          p.eventTime != null && p.updatedAt != null && mark.$1!.eventTime.isBefore(p.updatedAt!)
      ? null
      : mark.$1;
  return (quote, mark.$2);
}
