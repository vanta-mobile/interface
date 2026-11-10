import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/futures_history_provider.dart';
import '../domain/futures_history.dart';
import 'futures_history_labels.dart';
import '../../../core/presentation/app_toast.dart';

class FuturesHistoryFilters extends ConsumerWidget {
  const FuturesHistoryFilters({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(futuresHistoryProvider);
    final l10n = AppLocalizations.of(context);
    final identity = ref.watch(
      authProvider.select(
        (s) => (
          s.identity?.id,
          s.identity?.walletAddress,
          s.identity?.walletKind,
          s.identity?.signingAvailable,
        ),
      ),
    );
    final controller = ref.read(futuresHistoryProvider.notifier);
    final range = state.query.window;
    String date(int ms) =>
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS')
            .format(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey(('futures-history-symbol', state.query.kind, identity)),
          initialValue: state.query.symbol,
          enabled: !state.busy,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: state.query.kind == FuturesHistoryKind.trades
                ? l10n.futuresHistoryTradeSymbol
                : l10n.futuresHistorySymbol,
            helperText: l10n.futuresHistoryFilterHint,
            helperMaxLines: 5,
            errorText: state.query.validSymbol ? null : l10n.futuresHistoryInvalidSymbol,
            errorMaxLines: 4,
          ),
          onChanged: controller.setSymbol,
        ),
        if (state.query.kind == FuturesHistoryKind.income) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(('futures-history-income', identity, state.query.incomeType)),
            initialValue: state.query.incomeType,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.historyTransactionType),
            items: [
              DropdownMenuItem(value: '', child: Text(l10n.futuresHistoryAllTypes)),
              for (final type in futuresIncomeTypes)
                DropdownMenuItem(value: type, child: Text(futuresIncomeLabel(l10n, type))),
            ],
            onChanged: state.busy
                ? null
                : (value) {
                    if (value != null) controller.setIncomeType(value);
                  },
          ),
        ],
        const SizedBox(height: 16),
        Text(l10n.historyWindowLabel, style: Theme.of(context).textTheme.titleSmall),
        SelectableText(
          '${date(range.start)}\n${date(range.end)}',
          key: const Key('futures-history-window'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('futures-history-day'),
              onPressed: state.busy
                  ? null
                  : () => controller.setWindow(
                      HistoryWindow.recent(
                        ref.read(futuresHistoryClockProvider)(),
                        const Duration(days: 1),
                      ),
                    ),
              child: Text(l10n.historyDay),
            ),
            OutlinedButton(
              key: const Key('futures-history-week'),
              onPressed: state.busy
                  ? null
                  : () => controller.setWindow(
                      HistoryWindow.recent(
                        ref.read(futuresHistoryClockProvider)(),
                        const Duration(days: 7),
                      ),
                    ),
              child: Text(l10n.historyWeek),
            ),
            OutlinedButton(
              key: const Key('futures-history-dates'),
              onPressed: state.busy ? null : () => _pickDates(context, ref),
              child: Text(l10n.historyCustom),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _pickDates(BuildContext context, WidgetRef ref) async {
  final query = ref.read(futuresHistoryProvider).query;
  final identity = ref.read(authProvider).identity;
  final now = ref.read(futuresHistoryClockProvider)().toUtc();
  final today = DateTime(now.year, now.month, now.day);
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2017),
    lastDate: today,
    initialDateRange: DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
  );
  if (range == null ||
      !context.mounted ||
      ref.read(futuresHistoryProvider).query != query ||
      !identical(identity, ref.read(authProvider).identity)) {
    return;
  }
  final start = DateTime.utc(
    range.start.year,
    range.start.month,
    range.start.day,
  ).millisecondsSinceEpoch;
  final endOfDay =
      DateTime.utc(range.end.year, range.end.month, range.end.day + 1).millisecondsSinceEpoch - 1;
  final window = HistoryWindow(
    start,
    endOfDay < now.millisecondsSinceEpoch ? endOfDay : now.millisecondsSinceEpoch,
  );
  if (!window.valid) {
    AppToast.showFailure(context, AppLocalizations.of(context).futuresHistoryInvalidWindow);
    return;
  }
  ref.read(futuresHistoryProvider.notifier).setWindow(window);
}
