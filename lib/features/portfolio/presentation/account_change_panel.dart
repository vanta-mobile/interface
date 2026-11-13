import '../../../core/errors/error_text.dart';
import '../application/futures_history_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../funding/application/transfer_history_provider.dart';
import '../../trade/presentation/widgets/account_sheet.dart';
import '../application/account_change_provider.dart';
import '../application/spot_account_change_provider.dart';
import '../application/spot_account_provider.dart';
import '../application/spot_history_provider.dart';
import '../application/account_read_provider.dart';
import '../application/open_orders_provider.dart';
import '../application/spot_open_orders_provider.dart';
import '../application/position_risk_provider.dart';
import '../domain/account_change_stream.dart';
import '../domain/account_snapshot.dart';

class AccountChangePanel extends ConsumerWidget {
  const AccountChangePanel({super.key, this.initiallyExpanded = false, this.spot = false});
  final bool initiallyExpanded, spot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = spot ? ref.watch(spotAccountChangeProvider) : ref.watch(accountChangeProvider);
    final status = switch (state.connection) {
      AccountChangeConnection.stopped => l10n.accountChangeStopped,
      AccountChangeConnection.connecting => l10n.accountChangeConnecting,
      AccountChangeConnection.connected => l10n.accountChangeConnected,
      AccountChangeConnection.disconnected => l10n.accountChangeDisconnected,
      AccountChangeConnection.paused => l10n.accountChangePaused,
      AccountChangeConnection.expired => l10n.accountChangeExpired,
    };
    return ExpansionTile(
      key: Key(spot ? 'spot-account-change-panel' : 'account-change-panel'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      title: Text(spot ? l10n.spotAccountChangeTitle : l10n.accountChangeTitle),
      subtitle: Text(
        status,
        key: Key(spot ? 'spot-account-change-status' : 'account-change-status'),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 16),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(spot ? l10n.spotAccountChangeScope : l10n.accountChangeScope),
        ),
        const SizedBox(height: 12),
        _Controls(state: state, spot: spot),
        if (state.step != AccountReadStep.idle) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          Text(switch (state.step) {
            AccountReadStep.signing => l10n.accountReadSigning,
            AccountReadStep.loading => l10n.accountReadLoading,
            _ => l10n.accountReadPreparing,
          }),
        ],
        if (state.failure case final failure?)
          Text(
            accountErrorText(context, failure),
            style: const TextStyle(color: AppColors.negative),
          ),
        if (state.renewalDue && state.connection != AccountChangeConnection.expired)
          Text(l10n.accountChangeRenewalDue, style: const TextStyle(color: AppColors.warning)),
        if (state.expiresAt case final time?) Text(l10n.accountChangeExpiry(_time(context, time))),
        if (state.lastEventAt case final time?)
          Text(
            l10n.accountChangeLastEvent(_time(context, time)),
            key: Key(spot ? 'spot-account-change-last-event' : 'account-change-last-event'),
          ),
      ],
    );
  }

  String _time(BuildContext context, DateTime time) =>
      DateFormat.yMd(Localizations.localeOf(context).toLanguageTag())
          .add_Hms()
          .format(time.toLocal());
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.state, required this.spot});
  final bool spot;
  final AccountChangeState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authProvider);
    final otherReadBusy =
        ref.watch(transferHistoryProvider.select((s) => s.busy)) ||
        ref.watch(accountReadProvider.select((s) => s.busy)) ||
        ref.watch(openOrdersReadProvider.select((s) => s.busy)) ||
        ref.watch(spotOpenOrdersProvider.select((s) => s.busy)) ||
        ref.watch(positionRiskProvider.select((s) => s.busy)) ||
        ref.watch(spotAccountReadProvider.select((s) => s.busy)) ||
        ref.watch(spotHistoryProvider.select((s) => s.busy)) ||
        ref.watch(futuresHistoryProvider.select((s) => s.busy)) ||
        (spot ? ref.watch(accountChangeProvider).busy : ref.watch(spotAccountChangeProvider).busy);
    final controller = spot
        ? ref.read(spotAccountChangeProvider.notifier)
        : ref.read(accountChangeProvider.notifier);
    final validLease =
        state.expiresAt != null && state.connection != AccountChangeConnection.expired;
    final canSign =
        session.identity?.walletAddress != null && session.identity?.signingAvailable == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: Key(spot ? 'authorize-spot-account-changes' : 'authorize-account-changes'),
          onPressed: state.busy || otherReadBusy || session.busy
              ? null
              : canSign
              ? controller.authorize
              : () => showAccountSheet(context),
          icon: const Icon(Icons.sensors),
          label: Text(
            !canSign
                ? session.identity == null
                      ? l10n.accountSignInToRead
                      : session.identity?.walletAddress == null
                      ? tr(context, 'createWallet')
                      : tr(context, 'reconnectExternalWallet')
                : validLease
                ? spot
                      ? l10n.spotAccountChangeRenew
                      : l10n.accountChangeRenew
                : spot
                ? l10n.spotAccountChangeStart
                : l10n.accountChangeStart,
          ),
        ),
        if (validLease && state.connection == AccountChangeConnection.disconnected)
          OutlinedButton(
            key: Key(spot ? 'reconnect-spot-account-changes' : 'reconnect-account-changes'),
            onPressed: state.busy ? null : controller.reconnect,
            child: Text(l10n.accountChangeReconnect),
          ),
        if (state.busy || state.connection != AccountChangeConnection.stopped)
          TextButton(
            key: Key(spot ? 'stop-spot-account-changes' : 'stop-account-changes'),
            onPressed: controller.stop,
            child: Text(l10n.accountChangeStop),
          ),
      ],
    );
  }
}
