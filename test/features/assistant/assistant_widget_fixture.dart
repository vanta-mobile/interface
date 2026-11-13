import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/assistant/presentation/assistant_page.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import 'assistant_application_fixture.dart';

Future<void> drive(WidgetTester tester, Future<void> Function() operation) async {
  var done = false;
  unawaited(operation().whenComplete(() => done = true));
  for (var i = 0; i < 200 && !done; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(done, true, reason: 'Synthetic operation must finish while pumping the widget clock');
}

Future<AssistantApplicationHarness> mount(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double scale = 1,
  String language = 'en',
  bool connected = true,
  double keyboard = 0,
  AssistantApplicationHarness? harness,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h = harness ?? AssistantApplicationHarness(connected: connected);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp(
        theme: vantaTheme(),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: const AssistantPage(),
          ),
        ),
      ),
    ),
  );
  if (!settle) return h;
  // Entry restores a stored session through asynchronous fakes.
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
  return h;
}

Future<void> show(WidgetTester tester, Finder finder) async {
  final list = find.descendant(
    of: find.byKey(const Key('assistant-page')),
    matching: find.byType(Scrollable),
  );
  if (finder.evaluate().isEmpty && list.evaluate().isNotEmpty) {
    scrollController(tester).jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 180, scrollable: list.first, maxScrolls: 60);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

ScrollController scrollController(WidgetTester tester) => tester
    .widget<ListView>(
      find.descendant(of: find.byKey(const Key('assistant-page')), matching: find.byType(ListView)),
    )
    .controller!;

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await show(tester, finder);
  await tester.tap(finder);
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

Future<void> close(WidgetTester tester, AssistantApplicationHarness h) async {
  await tester.pumpWidget(const SizedBox());
  await drive(tester, h.close);
}
