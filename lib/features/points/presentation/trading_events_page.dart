import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/trading_event_provider.dart';
import '../domain/trading_event.dart';
import 'event_document_view.dart';
import 'points_status.dart';
import 'trading_event_page.dart';
import '../../../core/presentation/status_view.dart';

String tradingEventStatus(String status, AppLocalizations l10n) => status == 'OPEN_FOR_REGISTRATION'
    ? l10n.eventRegistrationOpen
    : pointsCampaignStatus(status, l10n);

class TradingEventsPage extends ConsumerStatefulWidget {
  const TradingEventsPage({super.key});
  @override
  ConsumerState<TradingEventsPage> createState() => _TradingEventsPageState();
}

class _TradingEventsPageState extends ConsumerState<TradingEventsPage> {
  int page = 0;
  TradingEventType type = TradingEventType.retail;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(
          type == TradingEventType.retail ? tradingEventsProvider : channelEventsProvider,
        );
    final controller = ref.read(
      type == TradingEventType.retail
          ? tradingEventsProvider.notifier
          : channelEventsProvider.notifier,
    );
    final rows = state.snapshot?.value ?? const <TradingEvent>[];
    final pages = ((rows.length + 19) ~/ 20).clamp(1, 50), selected = page.clamp(0, pages - 1);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.eventsTitle)),
      body: ListView(
        key: const Key('trading-events-page'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.eventsScope),
          Wrap(
            spacing: 8,
            children: [
              for (final value in TradingEventType.values)
                ChoiceChip(
                  key: Key('event-type-${value.name}'),
                  label: Text(
                    value == TradingEventType.retail ? l10n.eventRetailTab : l10n.eventChannelTab,
                  ),
                  selected: type == value,
                  onSelected: (_) => setState(() {
                    type = value;
                    page = 0;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          PointsStatus(
            state: state,
            onRefresh: controller.refresh,
            onStop: controller.stop,
            sectionKey: 'events',
          ),
          if (state.snapshot != null && rows.isEmpty) StatusEmptyView(message: l10n.eventsEmpty),
          if (state.snapshot != null) Text(l10n.eventsCount(rows.length)),
          for (final event in rows.skip(selected * 20).take(20))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _EventCard(event: event),
            ),
          if (pages > 1)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: selected == 0 ? null : () => setState(() => page = selected - 1),
                  child: Text(l10n.pointsPrevious),
                ),
                Text(l10n.pointsPageNumber(selected + 1, pages)),
                OutlinedButton(
                  onPressed: selected == pages - 1
                      ? null
                      : () => setState(() => page = selected + 1),
                  child: Text(l10n.pointsNext),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event});
  final TradingEvent event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), now = eventNow(ref);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.image != null) EventMedia(uri: event.image!, label: event.name),
          Text(event.name, style: Theme.of(context).textTheme.titleLarge),
          if (event.subtitle.isNotEmpty) Text(event.subtitle),
          Text(
            !now.isBefore(event.end) &&
                    const {'ACTIVE', 'OPEN_FOR_REGISTRATION'}.contains(event.status)
                ? l10n.eventEnded
                : event.status == 'ACTIVE' && now.isBefore(event.start)
                ? l10n.eventUpcoming
                : tradingEventStatus(event.status, l10n),
          ),
          ValueRow(l10n.pointsPeriodStart, event.start.toIso8601String()),
          ValueRow(l10n.pointsPeriodEnd, event.end.toIso8601String()),
          FilledButton(
            key: Key('event-open-${event.id}'),
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => TradingEventPage(id: event.id))),
            child: Text(l10n.eventDetails),
          ),
        ],
      ),
    );
  }
}
