import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/app_toast.dart';
import '../../../core/presentation/status_view.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../notifications/presentation/notification_api_error.dart';
import '../../portfolio/presentation/mode_settings_sheet.dart';
import '../../trade/presentation/trade_theme.dart';
import '../domain/app_version.dart';
import '../application/settings_providers.dart';

final appUpdateLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

Future<void> showAppUpdate(BuildContext context, AppUpdateCheck check) =>
    showModeSettingsSheet<void>(context, SettingsUpdateSheet(check));

class SettingsUpdateSheet extends ConsumerStatefulWidget {
  const SettingsUpdateSheet(this.check, {super.key});
  final AppUpdateCheck check;
  @override
  ConsumerState<SettingsUpdateSheet> createState() => _SettingsUpdateSheetState();
}

class _SettingsUpdateSheetState extends ConsumerState<SettingsUpdateSheet> {
  bool _opening = false;
  late AppUpdateCheck _check = widget.check;
  Future<void> _refresh() async {
    try {
      final next = await ref.read(appUpdateCheckProvider.notifier).check();
      if (mounted) setState(() => _check = next);
    } catch (error) {
      if (mounted) AppToast.showFailure(context, notificationApiErrorText(context, error));
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    final uri = _check.release?.storeUri;
    if (uri == null) return;
    setState(() => _opening = true);
    try {
      final opened = await ref.read(appUpdateLauncherProvider)(uri);
      if (!opened && mounted) {
        AppToast.showFailure(context, AppLocalizations.of(context).settingsLinkFailed);
      }
    } catch (_) {
      if (mounted) AppToast.showFailure(context, AppLocalizations.of(context).settingsLinkFailed);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), check = _check;
    final notes = check.release?.notesFor(Localizations.localeOf(context).toLanguageTag());
    return ModeSheetBody(
      key: const Key('settings-update-sheet'),
      title: check.updateAvailable
          ? l.settingsUpdateAvailable(check.target!.text)
          : l.settingsCheckUpdates,
      onRefresh: _refresh,
      children: [
        if (check.updateRequired)
          Text(l.settingsUpdateRequired(check.target!.text), style: TradeTypography.body),
        if (notes != null) ...[
          const SizedBox(height: 16),
          Text(notes, style: TradeTypography.body),
        ],
        const SizedBox(height: 16),
        if (!check.updateAvailable)
          Text(
            check.hasPublishedVersion ? l.settingsUpToDate : l.settingsUpdateUnavailable,
            style: TradeTypography.body,
          )
        else if (check.release?.storeUri != null)
          StatusActionButton(
            key: const Key('settings-update-download'),
            label: l.settingsUpdateAction,
            loading: _opening,
            onPressed: _open,
          )
        else
          Text(l.settingsUpdateLinkUnavailable, style: TradeTypography.body),
      ],
    );
  }
}
