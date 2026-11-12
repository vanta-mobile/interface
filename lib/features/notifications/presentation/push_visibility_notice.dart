import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/push_device_provider.dart';
import '../domain/push_device.dart';

/// The API requires an explicit warning only when server visibility is absent.
/// Keep the inbox usable; this message does not replace its delivered records.
class PushVisibilityNotice extends ConsumerWidget {
  const PushVisibilityNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushDeviceProvider), l = AppLocalizations.of(context);
    if (push.status?.capability != PushCapability.noServerVisibility) {
      return const SizedBox.shrink();
    }
    return Semantics(
      key: const Key('push-no-server-visibility'),
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Text(
              l.pushVisibilityTitle,
              style: NotificationTypography.detailSection.copyWith(
                color: NotificationColors.warning,
              ),
            ),
            Text(
              [l.pushNoServerVisibility, ?push.status?.note].join('\n'),
              style: NotificationTypography.detailLabel,
            ),
          ],
        ),
      ),
    );
  }
}
