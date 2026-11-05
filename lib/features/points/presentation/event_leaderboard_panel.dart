import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/trading_event_provider.dart';
import '../domain/trading_event.dart';
import 'points_status.dart';

class EventLeaderboardPanel extends ConsumerStatefulWidget {
  const EventLeaderboardPanel({super.key, required this.id, this.type = TradingEventType.retail});
  final int id;
  final TradingEventType type;
  @override
  ConsumerState<EventLeaderboardPanel> createState() => _EventLeaderboardPanelState();
}

class _EventLeaderboardPanelState extends ConsumerState<EventLeaderboardPanel> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(
          widget.type == TradingEventType.channel
              ? channelEventLeaderboardProvider(widget.id)
              : eventLeaderboardProvider(widget.id),
        );
    final controller = ref.read(
      widget.type == TradingEventType.channel
          ? channelEventLeaderboardProvider(widget.id).notifier
          : eventLeaderboardProvider(widget.id).notifier,
    );
    final rows = state.snapshot?.value.rows ?? const <EventRanking>[];
    final pages = ((rows.length + 9) ~/ 10).clamp(1, 3), selected = page.clamp(0, pages - 1);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.pointsLeaderboard, style: Theme.of(context).textTheme.titleLarge),
          Text(
            widget.type == TradingEventType.channel
                ? l10n.eventChannelRankingScope
                : l10n.eventRankingScope,
          ),
          if (state.snapshot != null && rows.isEmpty) Text(l10n.pointsNoRankings),
          for (final row in rows.skip(selected * 10).take(10))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.pointsRankNumber('${row.rank}')),
                  SelectableText(row.address),
                  ValueRow(l10n.eventRankingVolume, marketNumber(row.volume)),
                ],
              ),
            ),
          if (pages > 1)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  key: const Key('event-rank-previous'),
                  onPressed: selected == 0 ? null : () => setState(() => page = selected - 1),
                  child: Text(l10n.pointsPrevious),
                ),
                Text(l10n.pointsPageNumber(selected + 1, pages)),
                OutlinedButton(
                  key: const Key('event-rank-next'),
                  onPressed: selected == pages - 1
                      ? null
                      : () => setState(() => page = selected + 1),
                  child: Text(l10n.pointsNext),
                ),
              ],
            ),
          PointsStatus(
            state: state,
            onRefresh: controller.refresh,
            onStop: controller.stop,
            sectionKey: 'event-board',
          ),
        ],
      ),
    );
  }
}
