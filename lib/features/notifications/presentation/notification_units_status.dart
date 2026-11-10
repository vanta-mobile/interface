import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/notification_provider.dart';
import '../../../core/presentation/status_view.dart';

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
    return StatusFailureView(
      message: l10n.notificationUnitFailure,
      retryKey: Key(spot ? 'spot-notification-units-retry' : 'notification-units-retry'),
      onRetry: () async {
        if (spot) {
          ref.invalidate(spotNotificationUnitsProvider);
          await ref.read(spotNotificationUnitsProvider.future);
        } else {
          ref.invalidate(notificationUnitsProvider);
          await ref.read(notificationUnitsProvider.future);
        }
      },
    );
  }
}
