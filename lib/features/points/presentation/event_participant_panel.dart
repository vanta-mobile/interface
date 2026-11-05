import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../market/domain/market_precision.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../../trade/presentation/widgets/primitives.dart';
import '../application/event_registration_provider.dart';
import '../application/trading_event_provider.dart';
import '../domain/event_registration.dart';
import '../domain/points.dart';
import '../domain/trading_event.dart';
import 'points_status.dart';
import 'event_registration_button.dart';

class EventParticipantPanel extends ConsumerWidget {
  const EventParticipantPanel({super.key, required this.event});
  final TradingEvent event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context), identity = ref.watch(authProvider).identity;
    final address = identity?.walletAddress;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.eventMyParticipation, style: Theme.of(context).textTheme.titleLarge),
          if (address != null && isPointsEvmAddress(address)) ...[
            SelectableText(address),
            Text(l10n.eventPersonalScope),
            _ParticipantContent(
              key: ValueKey('${identity!.id}:${identity.walletKind}:${address.toLowerCase()}'),
              event: event,
            ),
          ] else ...[
            Text(l10n.eventRegistrationUnknownStatus),
            OutlinedButton(
              onPressed: () => showAccountSheet(context),
              child: Text(l10n.pointsConnectWallet),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipantContent extends ConsumerWidget {
  const _ParticipantContent({super.key, required this.event});
  final TradingEvent event;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context),
        state = ref.watch(eventParticipantProvider(event.id));
    final controller = ref.read(eventRegistrationProvider(event.id).notifier);
    final action = ref.watch(eventRegistrationProvider(event.id)),
        value = state.snapshot?.value,
        now = eventNow(ref);
    final board = event.publishesRankings
        ? ref.watch(
            event.type == TradingEventType.channel
                ? channelEventLeaderboardProvider(event.id)
                : eventLeaderboardProvider(event.id),
          )
        : null;
    final rank = value == null
        ? null
        : board?.snapshot?.value.rows
              .where((r) => pointsAddressKey(r.address) == pointsAddressKey(value.address))
              .firstOrNull
              ?.rank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          value == null
              ? l10n.eventRegistrationUnknownStatus
              : value.registered
              ? l10n.eventRegistered
              : l10n.eventNotRegistered,
        ),
        if (value?.blockReason != null)
          Text(
            value!.blockReason == 'blacklist'
                ? l10n.eventBlockedBlacklist
                : value.blockReason == 'exclusive_event' || value.blockReason == 'exclusive'
                ? l10n.eventBlockedExclusive(value.conflictingEvent ?? l10n.eventAnotherCampaign)
                : l10n.eventBlocked,
          ),
        ValueRow(
          l10n.eventOwnVolume,
          value?.ownVolume == null ? '—' : marketNumber(value!.ownVolume!),
        ),
        if (event.type == TradingEventType.channel) ...[
          ValueRow(
            l10n.eventNetworkVolume,
            value?.networkVolume == null ? '—' : marketNumber(value!.networkVolume!),
          ),
          ValueRow(
            l10n.eventPersonalTotalVolume,
            value?.ownVolume != null && value?.networkVolume != null
                ? marketNumber(value!.ownVolume! + value.networkVolume!)
                : '—',
          ),
        ],
        ValueRow(l10n.eventMyRank, rank == null ? '—' : '$rank'),
        if (value != null && rank == null) Text(l10n.pointsRankUnknown),
        if (board?.stale == true) Text(l10n.pointsStale),
        if (event.canRegister(now) && value?.registered != true) ...[
          Text(l10n.eventRegistrationReadFirst),
          EventRegistrationButton(id: event.id),
        ],
        Text(switch (action.phase) {
          EventRegistrationPhase.checking => l10n.eventChecking,
          EventRegistrationPhase.signing => l10n.eventSigning,
          EventRegistrationPhase.sending => l10n.eventSending,
          EventRegistrationPhase.verified => l10n.eventRegistered,
          EventRegistrationPhase.acknowledged => l10n.eventAcknowledged,
          EventRegistrationPhase.unknown => l10n.eventRegistrationUnknown,
          _ => '',
        }),
        if (action.failureKey case final key?) Text(eventActionFailure(key, l10n)),
        PointsStatus(
          state: state,
          onRefresh: controller.reconcile,
          onStop: ref.read(eventParticipantProvider(event.id).notifier).stop,
          sectionKey: 'event-participant',
        ),
      ],
    );
  }
}

String eventActionFailure(String key, AppLocalizations l10n) => switch (key) {
  'eventRegistrationReadFirst' => l10n.eventRegistrationReadFirst,
  'eventRegistrationUnknown' => l10n.eventRegistrationUnknown,
  'eventRegistrationChanged' => l10n.eventRegistrationChanged,
  'authWalletReconnect' || 'authWalletChanged' => l10n.eventWalletReconnect,
  'authWalletRejected' => l10n.eventSignatureRejected,
  'authWalletSignature' || 'authWalletUnavailable' => l10n.eventSignatureUnavailable,
  'pointsNetwork' => l10n.pointsNetwork,
  'pointsRateLimited' => l10n.pointsRateLimited,
  'pointsDataInvalid' => l10n.pointsDataInvalid,
  _ => l10n.pointsUnavailable,
};
