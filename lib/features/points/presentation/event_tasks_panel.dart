import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/trading_event_provider.dart';
import '../domain/trading_event.dart';
import 'event_document_view.dart';

class EventTasksPanel extends StatelessWidget {
  const EventTasksPanel({super.key, required this.event});
  final TradingEvent event;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.eventTasks, style: Theme.of(context).textTheme.titleLarge),
        if (event.tasks.isEmpty) Text(l10n.eventNoTasks),
        for (final task in event.tasks.where(
          (t) => !const {'newUserTasks', 'dailyCheckIn', 'milestoneRewards'}.contains(t.metric),
        ))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _EventTaskCard(event: event, task: task),
          ),
      ],
    );
  }
}

class _EventTaskCard extends ConsumerWidget {
  const _EventTaskCard({required this.event, required this.task});
  final TradingEvent event;
  final EventTask task;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), now = eventNow(ref);
    final participant = ref.watch(eventParticipantProvider(event.id));
    final value = participant.snapshot?.value;
    final volume = task.metric == 'whitelistTotalVolume'
        ? (value?.whitelistTotalVolume ?? event.volume)
        : value?.registered != true
        ? null
        : switch (task.metric) {
            'ownVolume' => value?.ownVolume,
            'totalVolume' =>
              value?.ownVolume != null && value?.networkVolume != null
                  ? value!.ownVolume! + value.networkVolume!
                  : null,
            'qualifiedInviteeCount' =>
              value?.qualifiedInviteeCount == null
                  ? null
                  : Decimal.fromInt(value!.qualifiedInviteeCount!),
            'networkActiveTraderCount' =>
              value?.networkActiveTraderCount == null
                  ? null
                  : Decimal.fromInt(value!.networkActiveTraderCount!),
            'chainDeposit' => value?.depositProgress['${task.chainId}:${task.token}'],
            _ => null,
          };
    final trading =
        value?.registered == true &&
        !participant.stale &&
        !now.isBefore(event.start) &&
        now.isBefore(event.end) &&
        const {'OPEN_FOR_REGISTRATION', 'ACTIVE'}.contains(event.status);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (task.image != null) EventMedia(uri: task.image!, label: task.name),
          if (task.title.isNotEmpty)
            Text(task.title, style: Theme.of(context).textTheme.titleMedium),
          if (task.name.isNotEmpty) Text(task.name),
          if (task.description.isNotEmpty) Text(task.description),
          ValueRow(l10n.eventTaskTarget, marketNumber(task.threshold)),
          ValueRow(l10n.eventTaskProgress, volume == null ? '—' : marketNumber(volume)),
          Text(
            volume == null
                ? l10n.eventTaskUnknown
                : volume >= task.threshold
                ? l10n.eventTaskCompleted
                : l10n.eventTaskPending,
          ),
          if (participant.stale) Text(l10n.pointsStale),
          if (trading)
            EventLinkButton(
              uri:
                  task.buttonUrl ??
                  Uri.https(
                    'app.vanta.exchange',
                    const {
                          'qualifiedInviteeCount',
                          'networkActiveTraderCount',
                        }.contains(task.metric)
                        ? '/rewards/affiliate'
                        : task.metric == 'chainDeposit'
                        ? '/portfolio'
                        : '/perp/PERP_BTC_USDC',
                  ),
              label: task.buttonLabel.isEmpty ? l10n.eventOpenTrading : task.buttonLabel,
            )
          else
            Text(!now.isBefore(event.end) ? l10n.eventEnded : l10n.eventTradingEligibility),
        ],
      ),
    );
  }
}
