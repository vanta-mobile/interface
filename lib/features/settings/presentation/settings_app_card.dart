import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/formatters/byte_size_formatter.dart';
import '../../../core/legal_links.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/presentation/app_toast.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../notifications/presentation/notification_api_error.dart';
import '../application/settings_providers.dart';
import 'push_settings_sheet.dart';
import 'settings_components.dart';
import 'settings_language_sheet.dart';

class SettingsAppCard extends ConsumerWidget {
  const SettingsAppCard({super.key});

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    try {
      final result = await ref.read(appUpdateCheckProvider.notifier).check();
      if (!context.mounted) return;
      if (result.updateRequired) {
        AppToast.showFailure(context, l.settingsUpdateRequired(result.minimum!.text));
      } else {
        AppToast.showSuccess(context, l.settingsUpToDate);
      }
    } catch (error) {
      if (context.mounted) AppToast.showFailure(context, notificationApiErrorText(context, error));
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    try {
      await ref.read(appCacheProvider.notifier).clear();
      if (context.mounted) AppToast.showSuccess(context, l.settingsCacheCleared);
    } catch (_) {
      if (context.mounted) AppToast.showFailure(context, l.settingsCacheClearFailed);
    }
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final message = AppLocalizations.of(context).settingsLinkFailed;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) AppToast.showFailure(context, message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final language =
        ref.watch(localeProvider)?.languageCode ?? Localizations.localeOf(context).languageCode;
    final version = ref.watch(appVersionProvider).value;
    final checking = ref.watch(appUpdateCheckProvider);
    final cache = ref.watch(appCacheProvider);
    const chevron = SettingsIcon('chevron-right');
    return SettingsCard(
      children: [
        SettingsRow(
          key: const Key('settings-language'),
          label: l.language,
          value: languageName(l, language),
          trailing: chevron,
          onTap: () => openLanguageSettings(context),
        ),
        SettingsRow(
          key: const Key('settings-push'),
          label: l.settingsPushNotifications,
          trailing: chevron,
          onTap: () => openPushSettings(context),
        ),
        SettingsRow(
          key: const Key('settings-check-update'),
          label: l.settingsCheckUpdates,
          value: l.settingsCheck,
          busy: checking,
          onTap: () => unawaited(_checkUpdate(context, ref)),
        ),
        SettingsRow(
          key: const Key('settings-app-version'),
          label: l.settingsAppVersion,
          value: version == null ? '—' : 'v$version',
        ),
        SettingsRow(
          key: const Key('settings-cache'),
          label: l.settingsCacheSize,
          value: l.settingsCacheValue(
            cache.bytes == null ? '—' : ByteSizeFormatter.format(cache.bytes!),
          ),
          busy: cache.clearing,
          onTap: () => unawaited(_clearCache(context, ref)),
        ),
        SettingsRow(
          key: const Key('settings-terms'),
          label: l.authTermsOfUse,
          trailing: chevron,
          onTap: () => unawaited(_open(context, LegalLinks.termsOfUse)),
        ),
        SettingsRow(
          key: const Key('settings-privacy'),
          label: l.authPrivacyPolicy,
          trailing: chevron,
          onTap: () => unawaited(_open(context, LegalLinks.privacyPolicy)),
        ),
      ],
    );
  }
}
