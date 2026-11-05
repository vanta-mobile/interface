import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../domain/aster_account.dart';
import '../domain/live_order_trigger.dart';
import '../domain/order_query.dart';
import '../domain/strategy_execution.dart';

String _status(AppLocalizations l10n, String value) => switch (value) {
  'NEW' => l10n.openOrdersNew,
  'PARTIALLY_FILLED' => l10n.openOrdersPartiallyFilled,
  'FILLED' => l10n.historyFilled,
  'CANCELED' => l10n.historyCanceled,
  'EXPIRED' || 'EXPIRED_IN_MATCH' => l10n.historyExpired,
  'REJECTED' => l10n.historyRejected,
  'PENDING_CANCEL' => l10n.historyPendingCancel,
  _ => l10n.historyUnknownCode(value),
};
String _time(DateTime value) => DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(value.toUtc());
String _amount(Decimal? value, String? unit, AppLocalizations l10n) =>
    value == null ? '—' : '$value ${unit ?? l10n.accountUnitUnavailable}';

class StrategyExecutionLegCard extends StatelessWidget {
  const StrategyExecutionLegCard({super.key, required this.leg, required this.query, this.units});
  final StrategyExecutionLeg leg;
  final OrderQuery query;
  final AsterContractUnits? units;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), row = leg.execution;
    final sequence = leg.strategyLeg.sequence;
    final role = sequence == 1
        ? l10n.strategyExecutionEntry
        : query.draft.attachment!.exits[sequence - 2].kind == LiveOrderTriggerKind.takeProfit
        ? l10n.attachedOrderTakeProfit
        : l10n.attachedOrderStopLoss;
    return Card(
      key: Key('strategy-execution-leg-$sequence'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(role, style: Theme.of(context).textTheme.titleSmall),
            ValueRow(l10n.strategyExecutionStrategyLegStatus, leg.strategyLeg.status),
            if (leg.strategyLeg.orderId case final id?) SelectableText(id),
            if (leg.strategyLeg.orderId == null) Text(l10n.strategyExecutionNoOrder),
            if (leg.failure case final failure?)
              Text(
                '${tr(context, failure.key)}${failure.code == null ? '' : ' ${l10n.accountErrorCode(failure.code!)}'}',
                style: const TextStyle(color: AppColors.warning),
              ),
            if (row != null) ..._execution(l10n, row),
          ],
        ),
      ),
    );
  }

  List<Widget> _execution(AppLocalizations l10n, StrategyLegExecution row) => [
    ValueRow(l10n.strategyExecutionOrderStatus, _status(l10n, row.status)),
    if (row.originalType.startsWith('STOP') || row.originalType.startsWith('TAKE_PROFIT'))
      Text(
        row.triggered ? l10n.strategyExecutionTriggered : l10n.strategyExecutionTriggerUnconfirmed,
      ),
    ValueRow(l10n.strategyExecutionOriginalSize, _amount(row.quantity, units?.base, l10n)),
    ValueRow(l10n.strategyExecutionFilledSize, _amount(row.executed, units?.base, l10n)),
    ValueRow(l10n.strategyExecutionFilledValue, _amount(row.quoteAmount, units?.quote, l10n)),
    ValueRow(
      l10n.strategyExecutionAveragePrice,
      row.executed == Decimal.zero ? '—' : _amount(row.averagePrice, units?.quote, l10n),
    ),
    ValueRow(l10n.historyUpdatedUTC, _time(row.updatedAt)),
    ValueRow(l10n.strategyExecutionOrderTime, _time(row.checkedAt)),
    if (row.termsChanged)
      Text(l10n.strategyExecutionTermsChanged, style: const TextStyle(color: AppColors.warning)),
  ];
}
