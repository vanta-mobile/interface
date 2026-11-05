import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null || data['scenarios'] == null) {
      throw StateError('Performance run returned no metrics');
    }
    final destination = Platform.environment['PERF_OUTPUT_DIR'] ?? 'build/performance';
    for (final scenarioId in [
      'markets_load',
      'details_load',
      'market_buy_preview',
      'limit_buy_submit',
    ]) {
      final timeline = data.remove('${scenarioId}_timeline');
      if (timeline is Map<String, dynamic>) {
        await writeResponseData(
          timeline,
          testOutputFilename: '${scenarioId.replaceAll('_', '-')}-timeline',
          destinationDirectory: destination,
        );
      }
    }
    await writeResponseData(data, testOutputFilename: 'raw', destinationDirectory: destination);
  },
);
