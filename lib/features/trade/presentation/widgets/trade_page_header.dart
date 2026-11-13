import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../notifications/application/api_notification_provider.dart';
import '../../../notifications/presentation/notification_screen.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../trade_theme.dart';
import 'trade_icon.dart';

const _actionConstraints = BoxConstraints.tightFor(width: 24, height: 44);
const _actionStyle = ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap);

class TradePageHeader extends ConsumerWidget {
  const TradePageHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final unread = ref.watch(serverUnreadNotificationsProvider);
    return Row(
      children: [
        Image.asset('assets/branding/mark.webp', width: 22, height: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(l.tradeNavigation, style: TradeTypography.heading)),
        IconButton(
          key: const Key('trade-settings'),
          padding: EdgeInsets.zero,
          constraints: _actionConstraints,
          style: _actionStyle,
          tooltip: l.settings,
          onPressed: () => openSettings(context),
          icon: const TradeIcon('settings'),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('notifications-entry'),
          padding: EdgeInsets.zero,
          constraints: _actionConstraints,
          style: _actionStyle,
          tooltip: l.notificationTitle,
          onPressed: () => openNotifications(context),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const TradeIcon('bell'),
          ),
        ),
      ],
    );
  }
}
