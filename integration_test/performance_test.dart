import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/performance/performance_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native page and trading performance', (tester) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      fail('Performance reports support Android/iOS only');
    }
    if (!kProfileMode) fail('Run performance tests with --profile');
    const samples = int.fromEnvironment('PERF_SAMPLES', defaultValue: 30);
    const warmups = int.fromEnvironment('PERF_WARMUPS', defaultValue: 2);
    const traceScenarios =
        bool.fromEnvironment('PERF_TRACE_SCENARIOS') || bool.fromEnvironment('PERF_TRACE_DETAILS');
    if (traceScenarios) {
      debugProfileBuildsEnabled = true;
      debugProfileLayoutsEnabled = true;
      debugProfilePaintsEnabled = true;
    }
    // In profile, the debug-only "client -1" text-input shortcut is disabled.
    // Register the test channel so enterText uses the actual active client ID.
    // This also excludes native IME animations from the quote measurement.
    binding.testTextInput.register();
    final recorder = PerformanceRecorder(recordFrames: true)..start();
    try {
      await runPerformanceScenarios(
        tester,
        recorder,
        samples: samples,
        warmups: warmups,
        traceScenario: traceScenarios
            ? (scenarioId, action) => binding.traceAction(
                action,
                reportKey: '${scenarioId}_timeline',
                streams: ['Dart', 'Embedder', 'GC'],
              )
            : null,
      );
      // FrameTiming batches can arrive a second after their frame. Keep the
      // callback alive, but filter each frame by its engine build timestamp.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final results = recorder.results();
      for (final result in results) {
        expect(result['frames'], isNotEmpty, reason: 'No native frames for ${result['id']}');
      }
      binding.reportData = {
        ...?binding.reportData,
        'schema_version': 1,
        'suite_version': performanceSuiteVersion,
        'platform': Platform.operatingSystem,
        'mode': 'profile',
        'samples': samples,
        'warmups': warmups,
        'diagnostic_tracing': traceScenarios,
        'fixture': 'vanta-demo-controlled-repositories-no-network-no-wallet-v1',
        'logical_size': {
          'width': tester.view.physicalSize.width / tester.view.devicePixelRatio,
          'height': tester.view.physicalSize.height / tester.view.devicePixelRatio,
        },
        'refresh_rate_hz': tester.view.display.refreshRate,
        'scenarios': results,
      };
    } finally {
      recorder.stop();
      binding.testTextInput.unregister();
      debugProfileBuildsEnabled = false;
      debugProfileLayoutsEnabled = false;
      debugProfilePaintsEnabled = false;
    }
  });
}
