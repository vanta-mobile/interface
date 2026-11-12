import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/presentation/status_view.dart';
import '../../../core/strings.dart';
import '../../../core/vanta_api/vanta_api_failure.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/vanta_api_session_provider.dart';
import '../../auth/domain/auth_session.dart';
import '../application/api_notification_provider.dart';

String notificationApiErrorText(BuildContext context, Object error) => switch (error) {
  VantaApiFailure() => apiErrorText(context, error.key, error.details),
  AuthFailure() => authFailureText(context, error),
  _ => tr(context, vantaApiRequestFailed),
};

class NotificationApiAccess extends ConsumerWidget {
  const NotificationApiAccess({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(vantaApiSessionProvider), l = AppLocalizations.of(context);
    final unavailable = access.status == VantaApiSessionStatus.unavailable;
    return StatusFailureView(
      retryKey: const Key('notification-api-sign-in'),
      title: unavailable
          ? l.vantaApiUnavailableTitle
          : access.pending
          ? l.vantaApiSigningTitle
          : l.vantaApiSignInTitle,
      message: access.failure != null
          ? notificationApiErrorText(context, access.failure!)
          : unavailable
          ? l.vantaApiUnavailable
          : access.pending
          ? l.vantaApiSigning
          : l.vantaApiSignIn,
      retrying: access.pending,
      retryLabel: l.vantaApiSignInAction,
      onRetry: unavailable || access.pending
          ? null
          : () async {
              await ref.read(vantaApiSessionProvider.notifier).ensure();
              if (context.mounted) await ref.read(apiNotificationInboxProvider.notifier).refresh();
            },
    );
  }
}
