import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/auth/presentation/login_screen.dart';
import 'package:vanta/l10n/generated/app_localizations.dart';

import 'performance_fixture.dart';
import '../support/workspace_navigation.dart';

const performanceSuiteVersion = 3;

final class PerformanceRecorder {
  PerformanceRecorder({required this.recordFrames});
  final bool recordFrames;
  final _windows = <({String id, String label, int start, int end, double ms})>[];
  final _frames = <FrameTiming>[];
  bool warmingUp = false;

  void start() {
    if (recordFrames) WidgetsBinding.instance.addTimingsCallback(_collect);
  }

  void stop() {
    if (recordFrames) WidgetsBinding.instance.removeTimingsCallback(_collect);
  }

  void _collect(List<FrameTiming> frames) => _frames.addAll(frames);

  Future<void> measure(String id, String label, Future<void> Function() action) async {
    final start = developer.Timeline.now;
    final watch = Stopwatch()..start();
    await action();
    watch.stop();
    if (!warmingUp) {
      _windows.add((
        id: id,
        label: label,
        start: start,
        end: developer.Timeline.now,
        ms: watch.elapsedMicroseconds / 1000,
      ));
    }
  }

  /// Cumulative milestones share the trigger timestamp. An input can be usable
  /// while decorative number animations are still running.
  Future<void> measureMilestones(
    String id,
    String label,
    Future<void> Function() untilInteractive,
    Future<void> Function() untilSettled,
  ) async {
    final start = developer.Timeline.now;
    final watch = Stopwatch()..start();
    await untilInteractive();
    if (!warmingUp) {
      _windows.add((
        id: '${id}_ready',
        label: '$label to interactive',
        start: start,
        end: developer.Timeline.now,
        ms: watch.elapsedMicroseconds / 1000,
      ));
    }
    await untilSettled();
    watch.stop();
    if (!warmingUp) {
      _windows.add((
        id: '${id}_settled',
        label: '$label to animation complete',
        start: start,
        end: developer.Timeline.now,
        ms: watch.elapsedMicroseconds / 1000,
      ));
    }
  }

  List<Map<String, Object>> results() {
    final grouped = <String, Map<String, Object>>{};
    for (final window in _windows) {
      final row = grouped.putIfAbsent(
        window.id,
        () => {
          'id': window.id,
          'label': window.label,
          'duration_ms': <double>[],
          'frames': <Map<String, num>>[],
        },
      );
      (row['duration_ms']! as List<double>).add(window.ms);
      for (final frame in _frames) {
        final start = frame.timestampInMicroseconds(FramePhase.buildStart);
        if (start < window.start || start > window.end) continue;
        (row['frames']! as List<Map<String, num>>).add({
          'build_start_us': start,
          'build_ms': frame.buildDuration.inMicroseconds / 1000,
          'raster_ms': frame.rasterDuration.inMicroseconds / 1000,
          'total_ms': frame.totalSpan.inMicroseconds / 1000,
        });
      }
    }
    return grouped.values.toList();
  }
}

/// A bounded wait works even while shimmer/polling continues. Success means
/// the actual data or enabled control was rendered, not just a mounted page.
Future<void> waitForPerformanceState(
  WidgetTester tester,
  bool Function() ready, {
  required String description,
}) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (ready()) return;
  }
  fail('Timed out waiting for $description');
}

Future<void> _waitFor(WidgetTester tester, Finder finder) => waitForPerformanceState(
  tester,
  () => finder.evaluate().isNotEmpty,
  description: finder.toString(),
);

Future<void> _unmount(WidgetTester tester, PerformanceFixture fixture) async {
  await tester.pumpWidget(const SizedBox.shrink());
  expect(fixture.transportAccesses, 0, reason: 'Journeys must not initialize live transport');
  await fixture.dispose();
  await tester.pump();
}

Future<void> runPerformanceScenarios(
  WidgetTester tester,
  PerformanceRecorder recorder, {
  int samples = 30,
  int warmups = 2,
  Future<void> Function(String scenarioId, Future<void> Function() action)? traceScenario,
}) async {
  if (samples < 1 || warmups < 0) throw ArgumentError('Invalid sample count');
  for (var round = -warmups; round < samples; round++) {
    recorder.warmingUp = round < 0;
    Future<void> measure(String id, String label, Future<void> Function() action) {
      Future<void> measured() => recorder.measure(id, label, action);
      return round == 0 &&
              traceScenario != null &&
              const [
                'markets_load',
                'details_load',
                'market_buy_mode',
                'limit_buy_connect',
              ].contains(id)
          ? traceScenario(id, measured)
          : measured();
    }

    final market = PerformanceFixture();
    try {
      await measure('home_load', 'Trading workspace load (200 candles)', () async {
        await tester.pumpWidget(market.app);
        await tester.pumpAndSettle();
        await selectWorkspace(tester, chart: true);
        await _waitFor(tester, find.byType(KChartWidget));
        await tester.pumpAndSettle();
      });
      await measure('markets_load', 'Market selector load (100 instruments)', () async {
        await tester.tap(find.byKey(const Key('trade-market-selector')));
        await _waitFor(tester, find.byKey(const Key('market-ETHUSDT')));
        await tester.pumpAndSettle();
      });
      final list = find
          .ancestor(of: find.byKey(const Key('market-ETHUSDT')), matching: find.byType(Scrollable))
          .first;
      final scrollState = tester.state<ScrollableState>(list);
      await measure('markets_scroll', 'Market selector scroll', () async {
        await tester.timedDrag(list, const Offset(0, -400), const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      });
      scrollState.position.jumpTo(0);
      await tester.pumpAndSettle();
      await measure('details_load', 'Switch instrument and render chart (200 candles)', () async {
        await tester.tap(find.byKey(const Key('market-ETHUSDT')));
        await tester.pumpAndSettle();
        expect(market.container.read(symbolProvider), 'ETHUSDT');
        expect(find.byType(KChartWidget), findsOneWidget);
      });
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, market);
    }

    // Unsigned entry exercises the production form gate. Financial execution
    // remains covered by signed repository/provider tests, not local demo fills.
    for (final buy in [true, false]) {
      for (final isMarket in [true, false]) {
        final fixture = PerformanceFixture();
        final prefix = '${isMarket ? 'market' : 'limit'}_${buy ? 'buy' : 'sell'}';
        final label = 'Unsigned ${isMarket ? 'market' : 'limit'} ${buy ? 'buy' : 'sell'}';
        try {
          await tester.pumpWidget(fixture.app);
          await tester.pumpAndSettle();
          await selectWorkspace(tester, chart: false);
          final quantity = find.byKey(const Key('trade-pending-quantity'));
          await recorder.measureMilestones('${prefix}_open', '$label form access', () async {
            await tester.ensureVisible(quantity);
            await tester.pump();
            expect(quantity.hitTestable(), findsOneWidget);
          }, () => tester.pumpAndSettle());
          await measure('${prefix}_mode', '$label order mode selection', () async {
            final selector = find.byKey(const Key('trade-order-type'));
            await tester.ensureVisible(selector);
            await tester.pumpAndSettle();
            await tester.tap(selector);
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(Key('order-mode-option-${isMarket ? 'market' : 'limit'}')));
            await tester.pumpAndSettle();
          });
          // Unsigned entry offers a single Connect button in the buy slot; no
          // Long/Short submission or separate account read is shown.
          final connect = find.byKey(const Key('trade-pending-buy'));
          await measure('${prefix}_disabled', '$label has no unsigned submission', () async {
            await tester.ensureVisible(connect);
            await tester.pumpAndSettle();
            final l = AppLocalizations.of(tester.element(connect));
            expect(find.descendant(of: connect, matching: find.text(l.connect)), findsOneWidget);
            expect(find.byKey(const Key('trade-pending-sell')), findsNothing);
            expect(find.byKey(const Key('live-order-read')), findsNothing);
            expect(tester.widget<TextField>(quantity).enabled, false);
            expect(fixture.container.read(accountProvider).connected, false);
          });
          await measure('${prefix}_connect', '$label account connection entry', () async {
            await tester.ensureVisible(connect);
            await tester.pumpAndSettle();
            await tester.tap(connect);
            await tester.pumpAndSettle();
            expect(find.byType(LoginScreen), findsOneWidget);
            expect(find.byKey(const Key('enter-demo')), findsNothing);
          });
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester, fixture);
        }
      }
    }
  }
}
