import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/core/theme.dart';
import 'package:vanta/features/settings/presentation/push_settings_sheet.dart';
import 'package:vanta/features/settings/presentation/settings_components.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import '../../support/api_notifications.dart';
import '../../support/push_device.dart';
import '../../support/vanta_api.dart';

const _prefs = {
  'fills': true,
  'triggers': false,
  'orders': true,
  'funding': false,
  'transfers': false,
  'announcements': true,
  'quiet_start': '22:00',
  'quiet_end': '07:30',
  'min_notional': '100',
  'quiet_timezone': 'device',
};

Future<void> _mount(WidgetTester tester, InboxFixture f, {String language = 'en'}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: f.container,
      child: MaterialApp(
        theme: vantaTheme(),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => openPushSettings(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

bool _switch(WidgetTester tester, String key) => tester
    .widget<SettingsSwitch>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(SettingsSwitch)),
    )
    .value;

Future<void> _toggle(WidgetTester tester, String key) async {
  final target = find.descendant(of: find.byKey(Key(key)), matching: find.byType(SettingsSwitch));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

List<Map<String, Object?>> _prefWrites(InboxFixture f) => [
  for (final request in f.backend.requests)
    if (request.url.path == '/v1/push/prefs') jsonDecode(request.body) as Map<String, Object?>,
];

/// Scroll a wheel to [value], as a user flick would settle on it.
Future<void> _select(WidgetTester tester, String key, int value) async {
  final wheel = tester.widget<ListWheelScrollView>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(ListWheelScrollView)),
  );
  (wheel.controller! as FixedExtentScrollController).jumpToItem(value);
  await tester.pumpAndSettle();
}

void main() {
  late InboxFixture f;
  late Map<String, Object?> prefs;
  setUp(() {
    f = InboxFixture();
    prefs = {..._prefs};
    f.backend.routes['GET /v1/push/status'] = (_) => json(pushStatusJson(prefs: prefs));
    f.backend.routes['POST /v1/push/prefs'] = (request) {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      prefs.addAll(body);
      return json(prefs);
    };
  });
  tearDown(() => f.dispose());

  for (final language in ['en', 'zh']) {
    testWidgets('renders server preferences with every category: $language', (tester) async {
      await _mount(tester, f, language: language);
      final l = AppLocalizations.of(tester.element(find.byType(PushSettingsSheet)));
      expect(find.text(l.settingsPushNotifications), findsOneWidget);
      expect(_switch(tester, 'push-quiet-hours'), isTrue);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('07:30'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(_switch(tester, 'push-category-fills'), isTrue);
      expect(_switch(tester, 'push-category-triggers'), isFalse);
      expect(_switch(tester, 'push-category-announcements'), isTrue);
      for (final label in [
        l.pushTradeExecutions,
        l.pushConditionalTriggers,
        l.pushOrderUpdates,
        l.pushFundingFees,
        l.pushTransfers,
        l.pushAnnouncements,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('category switch writes only that category and shows the server result', (
    tester,
  ) async {
    await _mount(tester, f);
    await _toggle(tester, 'push-category-triggers');
    expect(_prefWrites(f), [
      {'triggers': true},
    ]);
    expect(_switch(tester, 'push-category-triggers'), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('server rejection keeps the switch and shows the API message', (tester) async {
    f.backend.routes['POST /v1/push/prefs'] = (_) =>
        json({'code': 'bad_request', 'message': 'Preference update rejected'}, 400);
    await _mount(tester, f);
    await _toggle(tester, 'push-category-funding');
    expect(_switch(tester, 'push-category-funding'), isFalse);
    expect(find.text('Preference update rejected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('quiet hours off clears both bounds', (tester) async {
    await _mount(tester, f);
    await _toggle(tester, 'push-quiet-hours');
    expect(_prefWrites(f), [
      {'quiet_start': null, 'quiet_end': null},
    ]);
    expect(_switch(tester, 'push-quiet-hours'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('enabling quiet hours writes only after both times are picked', (tester) async {
    prefs
      ..['quiet_start'] = null
      ..['quiet_end'] = null;
    await _mount(tester, f);
    expect(_switch(tester, 'push-quiet-hours'), isFalse);
    await _toggle(tester, 'push-quiet-hours');
    expect(_switch(tester, 'push-quiet-hours'), isTrue);
    expect(_prefWrites(f), isEmpty);

    await tester.tap(find.byKey(const Key('push-quiet-start')));
    await tester.pumpAndSettle();
    expect(find.text('Start time'), findsOneWidget);
    await _select(tester, 'quiet-time-hour', 2);
    await tester.tap(find.byKey(const Key('quiet-time-confirm')));
    await tester.pumpAndSettle();
    expect(_prefWrites(f), isEmpty);
    expect(find.text('02:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('push-quiet-end')));
    await tester.pumpAndSettle();
    expect(find.text('End time'), findsOneWidget);
    await _select(tester, 'quiet-time-hour', 2);
    await tester.tap(find.byKey(const Key('quiet-time-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Start and end time must be different.'), findsOneWidget);
    expect(_prefWrites(f), isEmpty);

    await tester.tap(find.byKey(const Key('push-quiet-end')));
    await tester.pumpAndSettle();
    await _select(tester, 'quiet-time-hour', 6);
    await _select(tester, 'quiet-time-minute', 30);
    await tester.tap(find.byKey(const Key('quiet-time-confirm')));
    await tester.pumpAndSettle();
    expect(_prefWrites(f), [
      {'quiet_start': '02:00', 'quiet_end': '06:30'},
    ]);
    expect(find.text('02:00'), findsOneWidget);
    expect(find.text('06:30'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancelling the time picker changes nothing', (tester) async {
    await _mount(tester, f);
    await tester.tap(find.byKey(const Key('push-quiet-start')));
    await tester.pumpAndSettle();
    await _select(tester, 'quiet-time-hour', 3);
    await tester.tap(find.byKey(const Key('quiet-time-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quiet-time-picker')), findsNothing);
    expect(find.text('22:00'), findsOneWidget);
    expect(_prefWrites(f), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('minimum trade value submits an exact decimal string', (tester) async {
    await _mount(tester, f);
    final field = find.descendant(
      of: find.byKey(const Key('push-minimum-notional')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '250.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_prefWrites(f), [
      {'min_notional': '250.5'},
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('picking a time turns quiet hours on; switching off clears the times', (
    tester,
  ) async {
    prefs
      ..['quiet_start'] = null
      ..['quiet_end'] = null;
    await _mount(tester, f);
    expect(_switch(tester, 'push-quiet-hours'), isFalse);
    await tester.tap(find.byKey(const Key('push-quiet-start')));
    await tester.pumpAndSettle();
    await _select(tester, 'quiet-time-hour', 1);
    await tester.tap(find.byKey(const Key('quiet-time-confirm')));
    await tester.pumpAndSettle();
    expect(_switch(tester, 'push-quiet-hours'), isTrue);
    expect(_prefWrites(f), isEmpty);
    await tester.tap(find.byKey(const Key('push-quiet-end')));
    await tester.pumpAndSettle();
    await _select(tester, 'quiet-time-hour', 5);
    await tester.tap(find.byKey(const Key('quiet-time-confirm')));
    await tester.pumpAndSettle();
    expect(_prefWrites(f), [
      {'quiet_start': '01:00', 'quiet_end': '05:00'},
    ]);
    expect(_switch(tester, 'push-quiet-hours'), isTrue);
    await _toggle(tester, 'push-quiet-hours');
    expect(_switch(tester, 'push-quiet-hours'), isFalse);
    expect(_prefWrites(f).last, {'quiet_start': null, 'quiet_end': null});
    expect(find.text('01:00'), findsNothing);
    expect(find.text('05:00'), findsNothing);
    expect(find.text('00:00'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('switching off before both times are set discards the local time', (tester) async {
    prefs
      ..['quiet_start'] = null
      ..['quiet_end'] = null;
    await _mount(tester, f);
    await tester.tap(find.byKey(const Key('push-quiet-start')));
    await tester.pumpAndSettle();
    await _select(tester, 'quiet-time-hour', 3);
    await tester.tap(find.byKey(const Key('quiet-time-confirm')));
    await tester.pumpAndSettle();
    await _toggle(tester, 'push-quiet-hours');
    expect(_switch(tester, 'push-quiet-hours'), isFalse);
    expect(find.text('03:00'), findsNothing);
    expect(_prefWrites(f), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a pending write shows a spinner only on its own control', (tester) async {
    final gate = Completer<void>();
    f.backend.routes['POST /v1/push/prefs'] = (request) async {
      await gate.future;
      prefs.addAll(jsonDecode(request.body) as Map<String, Object?>);
      return json(prefs);
    };
    await _mount(tester, f);
    final field = find.descendant(
      of: find.byKey(const Key('push-minimum-notional')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '250.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final minimumSpinner = find.descendant(
      of: find.byKey(const Key('push-minimum-notional')),
      matching: find.byType(SettingsSpinner),
    );
    expect(minimumSpinner, findsOneWidget);
    expect(find.byType(SettingsSpinner), findsOneWidget);
    // The submitted value stays visible and other controls stay usable.
    expect(tester.widget<TextField>(field).controller!.text, '250.5');
    expect(tester.widget<TextField>(field).enabled, isTrue);
    final fills = tester.widget<SettingsSwitch>(
      find.descendant(
        of: find.byKey(const Key('push-category-fills')),
        matching: find.byType(SettingsSwitch),
      ),
    );
    expect(fills.onChanged, isNotNull);
    expect(fills.busy, isFalse);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSpinner), findsNothing);
    expect(tester.widget<TextField>(field).controller!.text, '250.5');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('absent or zero minimum shows a 0 placeholder; tapping the \$ box focuses it', (
    tester,
  ) async {
    prefs.remove('min_notional');
    await _mount(tester, f);
    final box = find.byKey(const Key('push-minimum-notional'));
    final field = find.descendant(of: box, matching: find.byType(TextField));
    final input = tester.widget<TextField>(field);
    expect(input.controller!.text, '');
    expect(input.decoration!.hintText, '0');
    expect(input.decoration!.focusedBorder, InputBorder.none);
    await tester.tapAt(tester.getTopLeft(box) + const Offset(14, 14));
    await tester.pump();
    expect(input.focusNode!.hasFocus, isTrue);
    // Leaving the default untouched sends nothing.
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(_prefWrites(f), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clearing a set minimum restores the default of 0', (tester) async {
    await _mount(tester, f);
    final field = find.descendant(
      of: find.byKey(const Key('push-minimum-notional')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).controller!.text, '100');
    await tester.enterText(field, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_prefWrites(f), [
      {'min_notional': '0'},
    ]);
    expect(tester.widget<TextField>(field).controller!.text, '');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signed-out sheet asks for Vanta API sign-in instead of showing switches', (
    tester,
  ) async {
    f.dispose();
    f = InboxFixture(signedIn: false, storedSession: false);
    await _mount(tester, f);
    expect(find.byKey(const Key('notification-api-sign-in')), findsOneWidget);
    expect(find.byType(SettingsSwitch), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
