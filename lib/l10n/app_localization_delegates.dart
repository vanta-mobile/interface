import 'package:flutter_localizations/flutter_localizations.dart' as flutter_l10n;
import 'package:material_ui/material_ui.dart';

import 'generated/app_localizations.dart';

/// Supports the app's Material UI widgets and Flutter-native SDK routes.
const appLocalizationDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
  flutter_l10n.GlobalMaterialLocalizations.delegate,
];
