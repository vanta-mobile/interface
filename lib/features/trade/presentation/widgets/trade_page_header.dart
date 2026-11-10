import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../notifications/application/notification_provider.dart';
import '../../../notifications/presentation/notification_screen.dart';
import '../../../portfolio/application/order_recovery_provider.dart';
import '../../../portfolio/presentation/order_recovery_screen.dart';
import '../../application/navigation_provider.dart';
import '../trade_theme.dart';
import 'account_sheet.dart';
import 'primitives.dart';
import 'trade_icon.dart';

class TradePageHeader extends ConsumerWidget {
  const TradePageHeader({super.key, required this.onLanguage});
  final VoidCallback onLanguage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final unread = ref.watch(unreadNotificationsProvider);
    final pending = ref.watch(pendingWalletOrdersProvider).length;
    return Row(
      children: [
        Image.asset('assets/branding/mark.webp', width: 22, height: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(l.tradeNavigation, style: TradeTypography.heading)),
        IconButton(
          key: const Key('trade-settings'),
          tooltip: l.settings,
          onPressed: () => showAppSheet<void>(context, _TradeSettings(onLanguage: onLanguage)),
          icon: Badge(isLabelVisible: pending > 0, child: const TradeIcon('settings')),
        ),
        IconButton(
          key: const Key('notifications-entry'),
          tooltip: l.notificationTitle,
          onPressed: () => openNotifications(context),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const TradeIcon('bell'),
          ),
        ),
        Flexible(
          child: FilledButton(
            key: const Key('trade-ask-ai'),
            onPressed: () =>
                ref.read(appDestinationProvider.notifier).select(AppDestination.assistant),
            style: FilledButton.styleFrom(
              backgroundColor: TradeColors.accentBackground,
              foregroundColor: TradeColors.accent,
              minimumSize: const Size(78, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TradeIcon('ai', size: 24, color: TradeColors.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l.tradeAskAi,
                    style: TradeTypography.body.copyWith(color: TradeColors.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TradeSettings extends ConsumerWidget {
  const _TradeSettings({required this.onLanguage});
  final VoidCallback onLanguage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.settings, style: TradeTypography.heading),
        ListTile(
          key: const Key('account-button'),
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(l.account),
          onTap: () {
            Navigator.pop(context);
            showAccountSheet(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(tr(context, 'language')),
          onTap: () {
            Navigator.pop(context);
            onLanguage();
          },
        ),
        ListTile(
          key: const Key('order-recovery-entry'),
          leading: const Icon(Icons.restore),
          title: Text(l.orderRecoveryTitle),
          trailing: Text('${ref.watch(pendingWalletOrdersProvider).length}'),
          onTap: () {
            Navigator.pop(context);
            openOrderRecovery(context);
          },
        ),
      ],
    );
  }
}
