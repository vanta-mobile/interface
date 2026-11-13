import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until the one-shot startup intro hands over to the app. The
/// Rive file decodes a few frames after mount, so a single long pump can land
/// before the intro starts.
Future<void> pumpPastStartupIntro(WidgetTester tester) async {
  final splash = find.byKey(const Key('startup-splash'));
  for (var i = 0; i < 250 && splash.evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
