import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../notifications/application/api_notification_provider.dart';
import '../../../notifications/presentation/notification_screen.dart';
import '../../application/navigation_provider.dart';
import '../trade_theme.dart';
import 'trade_icon.dart';
import 'trade_mode_settings.dart';

const _actionConstraints = BoxConstraints.tightFor(width: 24, height: 44);
const _actionStyle = ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap);

class TradePageHeader extends ConsumerWidget {
  const TradePageHeader({super.key, required this.onLanguage});
  final VoidCallback onLanguage;
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
          onPressed: () => openTradeModeSettings(context),
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
        const SizedBox(width: 8),
        FilledButton(
          key: const Key('trade-ask-ai'),
          onPressed: () =>
              ref.read(appDestinationProvider.notifier).select(AppDestination.assistant),
          style: FilledButton.styleFrom(
            backgroundColor: TradeColors.accentBackground,
            foregroundColor: TradeColors.accent,
            minimumSize: const Size(78, 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      ],
    );
  }
}
