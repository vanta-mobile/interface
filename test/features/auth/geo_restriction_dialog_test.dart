import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vanta/features/auth/presentation/geo_restriction_dialog.dart';
import 'package:vanta/l10n/app_localization_delegates.dart';

void main() {
  testWidgets('system back leaves the region restriction visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(showGeoRestrictionDialog(context, ['Canada'])),
              child: const Text('Show restriction'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show restriction'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
