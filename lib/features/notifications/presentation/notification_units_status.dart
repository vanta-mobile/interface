import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/notification_provider.dart';

class NotificationUnitsStatus extends ConsumerWidget {
  const NotificationUnitsStatus({super.key, this.spot = false});
  final bool spot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = spot
        ? ref.watch(spotNotificationUnitsProvider)
        : ref.watch(notificationUnitsProvider);
    final l10n = AppLocalizations.of(context);
    if (units.isLoading) return const LinearProgressIndicator();
    if (!units.hasError) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.notificationUnitFailure),
        OutlinedButton(
          key: Key(spot ? 'spot-notification-units-retry' : 'notification-units-retry'),
          onPressed: () {
            if (spot) {
              ref.invalidate(spotNotificationUnitsProvider);
            } else {
              ref.invalidate(notificationUnitsProvider);
            }
          },
          child: Text(l10n.retry),
        ),
      ],
    );
  }
}
