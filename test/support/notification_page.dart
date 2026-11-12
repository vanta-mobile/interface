import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/notifications/presentation/notification_screen.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

/// Exercise notification routes independently of the wallet onboarding flow.
Future<void> launchNotificationCenter(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: vantaTheme(),
        locale: container.read(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
