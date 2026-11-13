import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../portfolio/presentation/mode_settings_sheet.dart';
import '../../trade/presentation/trade_theme.dart';

Future<void> openLanguageSettings(BuildContext context) =>
    showModeSettingsSheet<void>(context, const SettingsLanguageSheet());

/// Only the two shipped catalogs are offered.
String languageName(AppLocalizations l, String code) =>
    code == 'zh' ? l.settingsChinese : l.languageEnglish;

class SettingsLanguageSheet extends ConsumerWidget {
  const SettingsLanguageSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final failed = ref.watch(localeSaveErrorProvider);
    return ModeSheetBody(
      key: const Key('settings-language-sheet'),
      title: l.language,
      children: [
        for (final (index, code) in const ['en', 'zh'].indexed) ...[
          if (index > 0) const SizedBox(height: 16),
          InkWell(
            key: Key('settings-language-$code'),
            onTap: () {
              unawaited(ref.read(localeProvider.notifier).select(code));
              Navigator.pop(context);
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  languageName(l, code),
                  style: TradeTypography.option.copyWith(color: TradeColors.secondary),
                ),
              ),
            ),
          ),
        ],
        if (failed) ModeError(l.languageSaveFailed),
      ],
    );
  }
}
