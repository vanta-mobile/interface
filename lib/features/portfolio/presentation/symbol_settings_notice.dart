import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/symbol_settings_activity.dart';

class SymbolSettingsNotice extends ConsumerWidget {
  const SymbolSettingsNotice({super.key, required this.setting});
  final SymbolSetting setting;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(symbolSettingsActivityProvider).blocks(setting)
      ? Text(
          AppLocalizations.of(context).symbolSettingsOtherPending,
          style: const TextStyle(color: AppColors.warning),
        )
      : const SizedBox.shrink();
}
