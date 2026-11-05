import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart_plus/k_chart_plus.dart';
import 'package:vanta/features/trade/application/providers.dart';
import 'package:vanta/features/trade/presentation/widgets/order_form.dart';

import 'performance_fixture.dart';
import '../support/workspace_navigation.dart';

const performanceSuiteVersion = 2;

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
                'market_buy_preview',
                'limit_buy_submit',
              ].contains(id)
          ? traceScenario(id, measured)
          : measured();
    }

    final market = PerformanceFixture();
    try {
      await measure('home_load', 'Trading workspace load (200 candles)', () async {
        await tester.pumpWidget(market.app);
        await _waitFor(tester, find.byType(KChartWidget));
        await tester.pumpAndSettle();
      });
      await measure('markets_load', 'Market selector load (100 instruments)', () async {
        await tester.tap(find.text('BTC / USDT').first);
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

    for (final buy in [true, false]) {
      for (final isMarket in [true, false]) {
        final fixture = PerformanceFixture();
        final prefix = '${isMarket ? 'market' : 'limit'}_${buy ? 'buy' : 'sell'}';
        final label = 'Demo ${isMarket ? 'market' : 'limit'} ${buy ? 'buy' : 'sell'}';
        try {
          await tester.pumpWidget(fixture.app);
          await tester.pumpAndSettle();
          await selectWorkspace(tester, chart: false);
          fixture.container.read(accountProvider.notifier).connect();
          await tester.pumpAndSettle();
          final form = find.byType(OrderForm);
          final quantity = find.byKey(const Key('quantity-input'));
          // The Vanta form is inline; measure scrolling it into view, then
          // switching order type/side. There is no panel-open network request.
          await recorder.measureMilestones('${prefix}_open', '$label form access', () async {
            await tester.ensureVisible(quantity);
            await tester.pump();
            expect(quantity.hitTestable(), findsOneWidget);
          }, () => tester.pumpAndSettle());
          Future<void> select(String text) async {
            final target = find.descendant(of: form, matching: find.text(text)).first;
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
          }

          await select(isMarket ? '市价' : '限价');
          await select(buy ? '做多' : '做空');
          if (!isMarket) {
            final price = find.byKey(const Key('price-input'));
            await tester.ensureVisible(price);
            await tester.enterText(price, '79000');
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(quantity);
          await tester.pumpAndSettle();
          await measure('${prefix}_quote', '$label input to local estimate', () async {
            await tester.enterText(quantity, '0.01');
            await tester.pumpAndSettle();
            expect(tester.widget<TextField>(quantity).controller!.text, '0.01');
            expect(
              find.descendant(
                of: form,
                matching: find.text(isMarket ? '800.00 USDT' : '790.00 USDT'),
              ),
              findsOneWidget,
            );
          });
          final submit = find.byKey(const Key('submit-order'));
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          await measure('${prefix}_preview', '$label confirmation preview', () async {
            await tester.tap(submit);
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('confirm-order')), findsOneWidget);
            expect(find.text('这是本地模拟订单，不会发送到交易所。'), findsOneWidget);
          });
          final confirm = find.byKey(const Key('confirm-order'));
          await tester.ensureVisible(confirm);
          await tester.pumpAndSettle();
          await measure('${prefix}_submit', '$label submit to local result', () async {
            await tester.tap(confirm);
            await tester.pumpAndSettle();
            final account = fixture.container.read(accountProvider);
            final order = (isMarket ? account.positions : account.orders).single;
            expect(order.draft.buy, buy);
            expect(order.draft.market, isMarket);
            expect(order.draft.quantity, '0.01');
            expect(order.draft.symbol, 'BTCUSDT');
          });
          if (!isMarket) {
            final orders = find.text('挂单 (1)');
            await tester.ensureVisible(orders);
            await tester.pumpAndSettle();
            await tester.tap(orders);
            await tester.pumpAndSettle();
            final cancel = find.widgetWithText(OutlinedButton, '取消').last;
            await tester.ensureVisible(cancel);
            await tester.pumpAndSettle();
            await measure('${prefix}_cancel', '$label cancel to local list update', () async {
              await tester.tap(cancel);
              await tester.pumpAndSettle();
              expect(fixture.container.read(accountProvider).orders, isEmpty);
            });
          }
          expect(tester.takeException(), isNull);
        } finally {
          await _unmount(tester, fixture);
        }
      }
    }
  }
}
