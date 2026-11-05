import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/event_engagement_provider.dart';
import '../application/trading_event_provider.dart';
import '../domain/event_engagement.dart';
import '../domain/event_registration.dart';
import '../domain/trading_event.dart';
import 'event_document_view.dart';
import 'event_participant_panel.dart';
import 'points_status.dart';

class EventEngagementPanel extends ConsumerWidget {
  const EventEngagementPanel({super.key, required this.event});
  final TradingEvent event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(eventTaskProgressProvider(event.id));
    final controller = ref.read(eventEngagementProvider(event.id).notifier),
        action = ref.watch(eventEngagementProvider(event.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.eventEngagementTitle, style: Theme.of(context).textTheme.titleLarge),
        Text(l10n.eventEngagementScope),
        PointsStatus(
          state: state,
          onRefresh: controller.reconcile,
          onStop: ref.read(eventTaskProgressProvider(event.id).notifier).stop,
          sectionKey: 'event-tasks',
        ),
        if (action.busy)
          Text(
            action.phase == EventRegistrationPhase.signing
                ? l10n.eventSigning
                : action.phase == EventRegistrationPhase.sending
                ? l10n.eventSending
                : l10n.eventChecking,
          ),
        if (action.phase == EventRegistrationPhase.verified) Text(l10n.eventEngagementVerified),
        if (action.phase == EventRegistrationPhase.acknowledged)
          Text(l10n.eventEngagementAcknowledged),
        if (action.phase == EventRegistrationPhase.unknown) Text(l10n.eventEngagementUnknown),
        if (action.failureKey case final key?) Text(_failure(key, l10n)),
        for (final task in event.tasks.where(
          (t) => const {'newUserTasks', 'dailyCheckIn', 'milestoneRewards'}.contains(t.metric),
        ))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _EngagementTask(event: event, task: task),
          ),
      ],
    );
  }
}

String _failure(String key, AppLocalizations l10n) => switch (key) {
  'eventEngagementReadFirst' => l10n.eventEngagementReadFirst,
  'eventEngagementIneligible' => l10n.eventEngagementIneligible,
  'eventEngagementUnknown' => l10n.eventEngagementUnknown,
  'eventEngagementStorage' => l10n.eventEngagementStorage,
  'eventEngagementBusy' => l10n.eventEngagementBusy,
  'eventEngagementReconcileFailed' => l10n.eventEngagementReconcileFailed,
  _ => eventActionFailure(key, l10n),
};

class _EngagementTask extends ConsumerWidget {
  const _EngagementTask({required this.event, required this.task});
  final TradingEvent event;
  final EventTask task;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(eventTaskProgressProvider(event.id)),
        now = eventNow(ref);
    final p = state.snapshot?.value;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (task.image != null) EventMedia(uri: task.image!, label: task.name),
          if (task.name.isNotEmpty) Text(task.name, style: Theme.of(context).textTheme.titleMedium),
          if (task.title.isNotEmpty) Text(task.title),
          if (task.description.isNotEmpty) Text(task.description),
          if (task.metric == 'newUserTasks')
            _NewUserTask(event: event, task: task, progress: p?.newUser),
          if (task.metric == 'dailyCheckIn') ...[
            ValueRow(l10n.eventDailyDate, p?.daily?.today ?? '—'),
            ValueRow(
              l10n.eventDailyVolume,
              p?.daily?.volume == null ? '—' : marketNumber(p!.daily!.volume!),
            ),
            ValueRow(l10n.eventTaskTarget, marketNumber(p?.daily?.target ?? task.threshold)),
            Text(
              p?.daily?.checkedIn == null
                  ? l10n.eventTaskUnknown
                  : p!.daily!.checkedIn!
                  ? l10n.eventCheckedIn
                  : l10n.eventNotCheckedIn,
            ),
            if (p?.daily != null) ...[
              Text(l10n.eventCheckedDays(p!.daily!.dates.length)),
              if (p.daily!.dates.isNotEmpty) SelectableText(p.daily!.dates.join(', ')),
              if (p.daily!.today != eventUtcDay(now)) Text(l10n.eventDailyExpired),
            ],
            _EngagementButton(event: event, action: EventEngagementAction.checkIn),
            _WebsiteAction(task: task),
          ],
          if (task.metric == 'milestoneRewards') ...[
            if (task.trackMetric != null) ValueRow(l10n.eventTrackedMetric, task.trackMetric!),
            ValueRow(
              l10n.eventMilestoneCurrent,
              p?.milestones?.current == null ? '—' : marketNumber(p!.milestones!.current!),
            ),
            for (final tier in task.milestones) _MilestoneRow(tier: tier, progress: p?.milestones),
            _WebsiteAction(task: task),
          ],
          if (state.stale) Text(l10n.pointsStale),
          Text(l10n.eventRewardNotCredit),
        ],
      ),
    );
  }
}

class _NewUserTask extends StatelessWidget {
  const _NewUserTask({required this.event, required this.task, this.progress});
  final TradingEvent event;
  final EventTask task;
  final EventNewUserProgress? progress;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context), terms = task.newUser;
    String status(bool? value) => value == null
        ? l10n.eventTaskUnknown
        : value
        ? l10n.eventTaskCompleted
        : l10n.eventTaskPending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueRow(l10n.eventNewRegistration, status(progress?.registrationCompleted)),
        if (terms?.registrationReward.isNotEmpty == true) Text(terms!.registrationReward),
        ValueRow(l10n.eventNewWallet, status(progress?.walletCompleted)),
        if (terms?.walletReward.isNotEmpty == true) Text(terms!.walletReward),
        _EngagementButton(event: event, action: EventEngagementAction.walletConnect),
        ValueRow(l10n.eventNewDeposit, status(progress?.depositCompleted)),
        if (terms != null)
          ValueRow(l10n.eventTaskTarget, '${marketNumber(terms.amount)} ${terms.token}'),
        if (progress?.required != null)
          ValueRow(
            l10n.eventDepositRequired,
            '${marketNumber(progress!.required!)} ${progress!.token ?? '—'}',
          ),
        ValueRow(
          l10n.eventDepositCurrent,
          progress?.current == null
              ? '—'
              : '${marketNumber(progress!.current!)} ${progress!.token ?? '—'}',
        ),
        if (progress?.remaining != null)
          ValueRow(
            l10n.eventDepositRemaining,
            '${marketNumber(progress!.remaining!)} ${progress!.token ?? '—'}',
          ),
        if (progress?.chainId != null || terms?.chainId != null)
          ValueRow(l10n.eventDepositChain, '${progress?.chainId ?? terms!.chainId}'),
        if (terms?.depositReward.isNotEmpty == true) Text(terms!.depositReward),
        EventLinkButton(
          uri: task.buttonUrl ?? Uri.https('app.vanta.exchange', '/portfolio'),
          label: l10n.eventWebsiteDeposit,
        ),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.tier, this.progress});
  final EventMilestone tier;
  final EventMilestoneProgress? progress;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context),
        item = progress?.items.where((m) => m.threshold == tier.threshold).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueRow(l10n.eventTaskTarget, marketNumber(tier.threshold)),
          if (tier.description.isNotEmpty) Text(tier.description),
          if (tier.reward.isNotEmpty) Text(tier.reward),
          Text(
            item?.completed == null
                ? l10n.eventTaskUnknown
                : item!.completed!
                ? l10n.eventMilestoneUnlocked
                : l10n.eventTaskPending,
          ),
          if (item?.remaining != null)
            ValueRow(l10n.eventMilestoneRemaining, marketNumber(item!.remaining!)),
        ],
      ),
    );
  }
}

class _WebsiteAction extends StatelessWidget {
  const _WebsiteAction({required this.task});
  final EventTask task;
  @override
  Widget build(BuildContext context) => EventLinkButton(
    uri: task.buttonUrl ?? Uri.https('app.vanta.exchange', '/perp/PERP_BTC_USDC'),
    label: AppLocalizations.of(context).eventOpenTrading,
  );
}

class _EngagementButton extends ConsumerWidget {
  const _EngagementButton({required this.event, required this.action});
  final TradingEvent event;
  final EventEngagementAction action;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), state = ref.watch(eventEngagementProvider(event.id));
    final eventState = ref.watch(tradingEventProvider(event.id)),
        participant = ref.watch(eventParticipantProvider(event.id)),
        tasks = ref.watch(eventTaskProgressProvider(event.id));
    final identity = ref.watch(authProvider).identity;
    final eligible =
        identity?.signingAvailable == true &&
        !state.busy &&
        !state.locked &&
        !eventState.stale &&
        !participant.stale &&
        !tasks.stale &&
        eventState.active &&
        participant.active &&
        tasks.active &&
        !eventState.loading &&
        !participant.loading &&
        !tasks.loading &&
        participant.snapshot != null &&
        tasks.snapshot != null &&
        engagementEligible(
          event,
          participant.snapshot!.value,
          tasks.snapshot!.value,
          action,
          eventNow(ref),
        );
    return OutlinedButton(
      key: Key('event-${action.path}'),
      onPressed: !eligible
          ? null
          : () async {
              final controller = ref.read(eventEngagementProvider(event.id).notifier),
                  approval = ref.read(eventEngagementProvider(event.id).notifier).prepare(action);
              if (approval == null) return;
              final yes = await _confirm(context, approval);
              if (yes == true && context.mounted) await controller.confirm(approval);
            },
      child: Text(
        action == EventEngagementAction.checkIn ? l10n.eventCheckIn : l10n.eventRecordWallet,
      ),
    );
  }
}

Future<bool?> _confirm(BuildContext context, EventEngagementApproval approval) {
  final l10n = AppLocalizations.of(context),
      label = approval.action == EventEngagementAction.checkIn
          ? l10n.eventCheckIn
          : l10n.eventRecordWallet;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(approval.event.name),
            SelectableText(approval.identity.walletAddress!),
            if (approval.action == EventEngagementAction.checkIn) Text('${approval.day} (UTC)'),
            Text(l10n.eventEngagementSigningScope),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.eventCancel)),
        FilledButton(
          key: const Key('event-engagement-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(label),
        ),
      ],
    ),
  );
}
