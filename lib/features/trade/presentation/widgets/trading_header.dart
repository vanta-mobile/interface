import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/strings.dart';
import '../../../../core/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../notifications/application/api_notification_provider.dart';
import '../../../notifications/presentation/notification_screen.dart';
import '../../application/providers.dart';
import 'account_sheet.dart';

class TradingHeader extends ConsumerWidget {
  const TradingHeader({super.key, required this.onLanguage});
  final VoidCallback onLanguage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unread = ref.watch(serverUnreadNotificationsProvider);
    final demo = ref.watch(accountProvider.select((a) => a.connected));
    final session = ref.watch(authProvider);
    final identity = session.identity;
    final address = identity?.walletAddress;
    final accountLabel = session.needsWalletConnection
        ? tr(context, 'connect')
        : address != null && address.length > 12
        ? '${address.substring(0, 6)}…${address.substring(address.length - 4)}'
        : tr(context, identity == null ? 'connect' : 'account');
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Image.asset(
            'assets/branding/vanta.webp',
            width: constraints.maxWidth < 330 ? 80 : 104,
            height: 28,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          IconButton(
            key: const Key('notifications-entry'),
            tooltip: l10n.notificationTitle,
            onPressed: () => openNotifications(context),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'language'),
            onPressed: onLanguage,
            icon: const Icon(Icons.language_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          Flexible(
            flex: 3,
            child: FilledButton(
              key: const Key('account-button'),
              onPressed: () => showAccountSheet(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: demo ? AppColors.accentSoft : AppColors.accent,
                foregroundColor: demo ? AppColors.accent : AppColors.onAccent,
              ),
              child: Text(
                demo ? tr(context, 'demo') : accountLabel,
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
