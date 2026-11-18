import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'error_event_filter.dart';

export 'error_event_filter.dart' show sanitizeErrorEvent;
export 'failure_reporter.dart' show ErrorMonitoringObserver, reportHandledFailure;

/// Public build configuration only. Authentication tokens never belong here.
class ErrorMonitoringConfiguration {
  const ErrorMonitoringConfiguration({
    this.dsn = const String.fromEnvironment('SENTRY_DSN'),
    this.environment = const String.fromEnvironment('SENTRY_ENVIRONMENT'),
    this.release = const String.fromEnvironment('SENTRY_RELEASE'),
    this.dist = const String.fromEnvironment('SENTRY_DIST'),
  });

  final String dsn;
  final String environment;
  final String release;
  final String dist;

  bool get enabled {
    final uri = Uri.tryParse(dsn);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isNotEmpty &&
        !uri.userInfo.contains(':') &&
        RegExp(r'^/[0-9]+$').hasMatch(uri.path) &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        const {'development', 'staging', 'production'}.contains(environment);
  }
}

Future<void> runWithErrorMonitoring(
  FutureOr<void> Function() appRunner, {
  ErrorMonitoringConfiguration configuration = const ErrorMonitoringConfiguration(),
}) async {
  final mobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!mobile || !configuration.enabled) {
    await appRunner();
    return;
  }
  await SentryFlutter.init(
    (options) => configureErrorMonitoring(options, configuration),
    appRunner: appRunner,
  );
}

void configureErrorMonitoring(
  SentryFlutterOptions options,
  ErrorMonitoringConfiguration configuration,
) {
  options
    ..dsn = configuration.dsn
    ..environment = configuration.environment
    ..debug = false
    ..sendDefaultPii = false
    ..sampleRate = 1
    ..tracesSampleRate = 0
    // Release health: native sessions carry only a random installation ID.
    ..enableAutoSessionTracking = true
    ..enableAutoPerformanceTracing = false
    ..enableUserInteractionTracing = false
    ..enableUserInteractionBreadcrumbs = false
    ..enableAutoNativeBreadcrumbs = false
    ..enablePrintBreadcrumbs = false
    // Only lifecycle, memory pressure and typed failure breadcrumbs survive the filter.
    ..enableAppLifecycleBreadcrumbs = true
    ..enableMemoryPressureBreadcrumbs = true
    ..maxBreadcrumbs = 30
    ..attachScreenshot = false
    ..attachViewHierarchy = false
    ..reportPackages = false
    // Native crash envelopes bypass Dart's privacy filter. Enable only after
    // equivalent native filters and device acceptance checks are implemented.
    ..enableNativeCrashHandling = false
    ..anrEnabled = false
    ..enableAppHangTracking = false
    ..enableWatchdogTerminationTracking = false
    ..beforeSend = (event, _) => sanitizeErrorEvent(event);
  options.beforeBreadcrumb = (crumb, _) => crumb == null ? null : sanitizeBreadcrumb(crumb);
  options.beforeSendLog = (_, _) => null;
  options.beforeSendMetric = (_, _) => null;
  options.replay
    ..sessionSampleRate = 0
    ..onErrorSampleRate = 0;
  if (configuration.release.isNotEmpty) options.release = configuration.release;
  if (configuration.dist.isNotEmpty) options.dist = configuration.dist;
}
