import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'performance_scenarios.dart';

void main() {
  testWidgets('all native performance journeys exercise Vanta demo controls', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recorder = PerformanceRecorder(recordFrames: false);
    await runPerformanceScenarios(tester, recorder, samples: 1, warmups: 1);
    final results = recorder.results();
    expect(results, hasLength(26));
    expect(results.map((row) => row['id']).toSet(), hasLength(26));
    for (final row in results) {
      expect(row['duration_ms'], hasLength(1), reason: 'Warmups must be excluded: ${row['id']}');
    }
  });
}
