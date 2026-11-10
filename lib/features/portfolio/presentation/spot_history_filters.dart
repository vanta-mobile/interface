import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/spot_history_provider.dart';
import '../domain/spot_history.dart';
import '../../../core/presentation/app_toast.dart';

class SpotHistoryFilters extends ConsumerWidget {
  const SpotHistoryFilters({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spotHistoryProvider);
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
    final controller = ref.read(spotHistoryProvider.notifier);
    final range = state.query.window;
    String date(int ms) =>
        DateFormat('yyyy-MM-dd HH:mm:ss.SSS')
            .format(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey(('history-scope', state.query.kind, identity)),
          initialValue: state.query.scope,
          enabled: !state.busy,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: state.query.kind == SpotHistoryKind.transactions
                ? l10n.historyAssetFilter
                : l10n.historySymbolFilter,
            helperText: l10n.historyFilterHint,
            helperMaxLines: 5,
            errorText: state.query.validScope ? null : l10n.historyInvalidScope,
            errorMaxLines: 4,
          ),
          onChanged: controller.setScope,
        ),
        const SizedBox(height: 16),
        Text(l10n.historyWindowLabel, style: Theme.of(context).textTheme.titleSmall),
        SelectableText(
          '${date(range.start)}\n${date(range.end)}',
          key: const Key('history-window'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('history-day'),
              onPressed: state.busy
                  ? null
                  : () => controller.setWindow(
                      HistoryWindow.recent(
                        ref.read(spotHistoryClockProvider)(),
                        const Duration(days: 1),
                      ),
                    ),
              child: Text(l10n.historyDay),
            ),
            OutlinedButton(
              key: const Key('history-week'),
              onPressed: state.busy
                  ? null
                  : () => controller.setWindow(
                      HistoryWindow.recent(
                        ref.read(spotHistoryClockProvider)(),
                        const Duration(days: 7),
                      ),
                    ),
              child: Text(l10n.historyWeek),
            ),
            OutlinedButton(
              key: const Key('history-dates'),
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
  final query = ref.read(spotHistoryProvider).query;
  final identity = ref.read(authProvider).identity;
  final now = ref.read(spotHistoryClockProvider)().toUtc();
  final today = DateTime(now.year, now.month, now.day);
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2017),
    lastDate: today,
    initialDateRange: DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
  );
  if (range == null ||
      !context.mounted ||
      ref.read(spotHistoryProvider).query != query ||
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
  if (!query.inWindow(window).validWindow) {
    AppToast.showFailure(context, AppLocalizations.of(context).historyInvalidWindow);
    return;
  }
  ref.read(spotHistoryProvider.notifier).setWindow(window);
}
