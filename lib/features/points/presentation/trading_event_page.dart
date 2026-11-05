import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/trading_event_provider.dart';
import '../domain/trading_event.dart';
import 'event_document_view.dart';
import 'event_leaderboard_panel.dart';
import 'event_participant_panel.dart';
import 'event_tasks_panel.dart';
import 'event_engagement_panel.dart';
import 'points_status.dart';
import 'trading_events_page.dart';

class TradingEventPage extends ConsumerWidget {
  const TradingEventPage({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(tradingEventProvider(id));
    final controller = ref.read(tradingEventProvider(id).notifier), event = state.snapshot?.value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.eventDetails)),
      body: SingleChildScrollView(
        key: Key('trading-event-$id'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.eventsScope),
            PointsStatus(
              state: state,
              onRefresh: controller.refresh,
              onStop: controller.stop,
              sectionKey: 'event-detail',
            ),
            if (event != null) ...[
              if (event.image != null) EventMedia(uri: event.image!, label: event.name),
              SelectableText(event.name, style: Theme.of(context).textTheme.headlineMedium),
              if (event.subtitle.isNotEmpty) SelectableText(event.subtitle),
              _EventTimeline(event: event),
              ValueRow(l10n.eventIdLabel, '${event.id}'),
              if (event.type == TradingEventType.channel) Text(l10n.eventChannelTab),
              if (event.channelName?.isNotEmpty == true)
                ValueRow(l10n.eventChannelName, event.channelName!),
              ValueRow(l10n.pointsBroker, event.broker),
              if (event.whitelistCount != null)
                ValueRow(l10n.eventWhitelistCount, '${event.whitelistCount}'),
              if (event.registrationCount != null)
                ValueRow(l10n.eventRegistrationCount, '${event.registrationCount}'),
              ValueRow(
                l10n.eventTotalVolume,
                event.volume == null ? '—' : marketNumber(event.volume!),
              ),
              const SizedBox(height: 16),
              EventParticipantPanel(event: event),
              const SizedBox(height: 16),
              EventTasksPanel(event: event),
              if (event.engagementTasks) EventEngagementPanel(event: event),
              if (event.rewards.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.eventRewardPool, style: Theme.of(context).textTheme.titleLarge),
                if (event.rewardTask.isNotEmpty) Text(event.rewardTask),
                for (final row in event.rewards) ValueRow(row.rank, row.reward),
              ],
              if (event.activityRules.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.eventActivityRules, style: Theme.of(context).textTheme.titleLarge),
                for (final rule in event.activityRules)
                  ExpansionTile(
                    title: Text(rule.title),
                    children: [EventDocumentView(document: rule.document)],
                  ),
              ],
              if (event.rules.blocks.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.eventCampaignRules, style: Theme.of(context).textTheme.titleLarge),
                EventDocumentView(document: event.rules),
              ],
              if (event.publishesRankings) ...[
                const SizedBox(height: 16),
                EventLeaderboardPanel(id: id, type: event.type),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _EventTimeline extends ConsumerWidget {
  const _EventTimeline({required this.event});
  final TradingEvent event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), now = eventNow(ref);
    final ended = !now.isBefore(event.end) || const {'ENDED', 'SETTLED'}.contains(event.status),
        started = !now.isBefore(event.start);
    final remaining = (started ? event.end : event.start).difference(now);
    final label = ended
        ? l10n.eventEnded
        : l10n.eventCountdown(
            started ? l10n.eventUntilEnd : l10n.eventUntilStart,
            '${remaining.inDays}',
            '${remaining.inHours % 24}'.padLeft(2, '0'),
            '${remaining.inMinutes % 60}'.padLeft(2, '0'),
            '${remaining.inSeconds % 60}'.padLeft(2, '0'),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.pointsStatus, tradingEventStatus(event.status, l10n)),
        Text(label),
        ValueRow(l10n.pointsPeriodStart, event.start.toIso8601String()),
        ValueRow(l10n.pointsPeriodEnd, event.end.toIso8601String()),
        if (event.registrationOpens != null)
          ValueRow(l10n.eventRegistrationOpens, event.registrationOpens!.toIso8601String()),
      ],
    );
  }
}
