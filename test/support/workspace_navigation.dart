import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

/// Exercise the user's tab selection; launch helpers retain the real default.
Future<void> selectWorkspace(WidgetTester tester, {required bool chart}) async {
  final tabs = find.byKey(const Key('trade-workspace-tabs'));
  final l10n = AppLocalizations.of(tester.element(tabs));
  await tester.ensureVisible(tabs);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: tabs,
      matching: find.byTooltip(chart ? l10n.quickOrderChartTab : l10n.trade),
    ),
  );
  await tester.pumpAndSettle();
}

/// Bring the account tabs and their lazy section into the page viewport.
Future<void> revealFuturesAccountTabs(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('futures-account-tab-0')),
    250,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('futures-workspace')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// A phone turned landscape opens the fullscreen chart on the chart tab.
/// Confirm it appeared, then leave it so the normal page can be exercised.
Future<void> leaveLandscapeChart(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final fullscreen = find.byKey(const Key('chart-fullscreen'));
  if (size.width <= size.height || size.shortestSide >= 600) {
    expect(fullscreen, findsNothing);
    return;
  }
  expect(fullscreen, findsOneWidget);
  await tester.tap(find.byKey(const Key('chart-expand')).last);
  await tester.pumpAndSettle();
  expect(fullscreen, findsNothing);
}

/// Quarter turns applied to the fullscreen chart: 1 in portrait, 0 in landscape.
int fullscreenTurns(WidgetTester tester) =>
    tester.widget<RotatedBox>(find.byKey(const Key('chart-fullscreen-rotation'))).quarterTurns;

const landscapeOnly = ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'];

/// Records preferred-orientation requests sent to the platform.
List<List<String>> recordOrientationRequests(WidgetTester tester) {
  final requests = <List<String>>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
    call,
  ) async {
    if (call.method == 'SystemChrome.setPreferredOrientations') {
      requests.add(List<String>.from(call.arguments as List));
    }
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return requests;
}
