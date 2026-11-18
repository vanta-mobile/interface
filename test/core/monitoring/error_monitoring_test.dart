import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vanta/core/errors/api_error_details.dart';
import 'package:vanta/core/monitoring/error_event_filter.dart';
import 'package:vanta/core/monitoring/error_monitoring.dart';
import 'package:vanta/core/monitoring/failure_reporter.dart';
import 'package:vanta/core/vanta_api/vanta_api_failure.dart';

void main() {
  test('monitoring requires a public HTTPS DSN and explicit environment', () {
    expect(const ErrorMonitoringConfiguration().enabled, isFalse);
    for (final dsn in [
      '',
      'https://key:secret@example.com/1',
      'http://key@example.com/1',
      'https://key@example.com/1?secret=x',
    ]) {
      expect(ErrorMonitoringConfiguration(dsn: dsn, environment: 'production').enabled, isFalse);
    }
    expect(const ErrorMonitoringConfiguration(dsn: 'https://key@example.com/1').enabled, isFalse);
    expect(
      const ErrorMonitoringConfiguration(
        dsn: 'https://key@example.com/1',
        environment: 'staging',
      ).enabled,
      isTrue,
    );
  });

  test('privacy filter removes payloads while preserving error locations and debug IDs', () {
    final event = SentryEvent(
      user: SentryUser(id: 'private-wallet', email: 'private@example.com'),
      request: SentryRequest(url: 'https://example.com/private-token'),
      message: SentryMessage('private-chat'),
      tags: {'wallet': 'private-wallet'},
      breadcrumbs: [Breadcrumb(message: 'private-token')],
      contexts: Contexts.fromJson({
        'wallet': {'address': 'private-wallet'},
        'device': {'name': 'private-device', 'model': 'iPhone16,2', 'arch': 'arm64'},
        'os': {'name': 'iOS', 'version': '19.1', 'raw_description': 'private-os'},
        'culture': {'locale': 'zh_CN', 'timezone': 'private-zone'},
      }),
      throwable: StateError('private-token'),
      release: 'vanta@abc',
      environment: 'staging',
      exceptions: [
        SentryException(
          type: 'StateError',
          value: 'private-token',
          mechanism: Mechanism(
            type: 'FlutterError',
            handled: false,
            data: {'payload': 'private-token'},
          ),
          stackTrace: SentryStackTrace(
            frames: [
              SentryStackFrame(
                fileName: 'package:vanta/main.dart',
                absPath: '/private-home/main.dart',
                function: 'main',
                lineNo: 42,
                vars: {'token': 'private-token'},
                contextLine: 'private-source',
              ),
            ],
          ),
        ),
      ],
      debugMeta: DebugMeta()
        ..addDebugImage(
          DebugImage(type: 'elf', debugId: 'debug-id', codeFile: '/private-home/app.so'),
        ),
    );
    final clean = sanitizeErrorEvent(event);
    final json = jsonEncode(clean.toJson());
    expect(json, isNot(contains('private-')));
    expect(json, isNot(contains('private@example.com')));
    expect(clean.throwable, isNull);
    expect(clean.exceptions!.single.type, 'StateError');
    expect(clean.exceptions!.single.mechanism!.handled, isFalse);
    expect(clean.exceptions!.single.stackTrace!.frames.single.lineNo, 42);
    expect(json, contains('package:vanta/main.dart'));
    expect(json, contains('debug-id'));
    expect(clean.eventId, event.eventId);
    expect(clean.release, 'vanta@abc');
    expect(clean.contexts.device!.model, 'iPhone16,2');
    expect(clean.contexts.operatingSystem!.version, '19.1');
    expect(clean.contexts.culture!.locale, 'zh_CN');
    expect(clean.breadcrumbs, isEmpty);
    expect(clean.tags, isNull);
  });

  test('typed API failures keep status, cause, code and fixed endpoint only', () {
    final failure = VantaApiFailure(
      vantaApiRequestFailed,
      code: 'order_rejected',
      details: const ApiErrorDetails(
        message: 'private-server-message',
        status: 503,
        cause: ApiErrorCause.invalidResponse,
        endpoint: '/v1/orders/123456/fills/0xabcdef0123456789abcdef',
      ),
    );
    final clean = sanitizeErrorEvent(
      SentryEvent(
        throwable: failure,
        tags: {
          'vanta.operation': 'journal.reload',
          'wallet': 'private-wallet',
          'vanta.source': 'private token',
        },
        exceptions: [SentryException(type: 'VantaApiFailure', value: 'private-server-message')],
      ),
    );
    final json = jsonEncode(clean.toJson());
    expect(json, isNot(contains('private')));
    expect(clean.tags, {
      'error.status': '503',
      'error.cause': 'invalidResponse',
      'error.endpoint': '/v1/orders/:id/fills/:id',
      'error.key': vantaApiRequestFailed,
      'error.code': 'order_rejected',
      'vanta.operation': 'journal.reload',
    });
    expect(
      clean.exceptions!.single.value,
      'status=503 cause=invalidResponse code=order_rejected key=$vantaApiRequestFailed endpoint=/v1/orders/:id/fills/:id',
    );
    expect(
      safeFailureTags(
        const VantaApiFailure('k', details: ApiErrorDetails(endpoint: '/v1/x?token=private')),
      ),
      {'error.key': 'k'},
    );
  });

  test('breadcrumbs keep allowlisted categories and safe data only', () {
    expect(sanitizeBreadcrumb(Breadcrumb(category: 'http', data: {'url': 'private'})), isNull);
    expect(sanitizeBreadcrumb(Breadcrumb(category: 'navigation', message: 'private')), isNull);
    final lifecycle = sanitizeBreadcrumb(
      Breadcrumb(
        category: 'app.lifecycle',
        message: 'private',
        data: {'state': 'paused', 'extra': 'private'},
      ),
    )!;
    expect(lifecycle.message, isNull);
    expect(lifecycle.data, {'state': 'paused'});
    final failure = sanitizeBreadcrumb(
      Breadcrumb(
        category: 'vanta.failure',
        data: {'error.status': '429', 'error.cause': 'private value'},
      ),
    )!;
    expect(failure.data, {'error.status': '429'});
  });

  test('failure classification reports faults and keeps expected failures as context', () {
    VantaApiFailure api(int? status, [ApiErrorCause? cause]) => VantaApiFailure(
      'k',
      details: ApiErrorDetails(status: status, cause: cause),
    );
    expect(classifyFailure(api(503)), FailureDisposition.report);
    expect(classifyFailure(api(200, ApiErrorCause.invalidResponse)), FailureDisposition.report);
    expect(classifyFailure(api(400)), FailureDisposition.breadcrumb);
    expect(classifyFailure(api(429, ApiErrorCause.rateLimit)), FailureDisposition.breadcrumb);
    expect(classifyFailure(api(null, ApiErrorCause.timeout)), FailureDisposition.breadcrumb);
    expect(classifyFailure(api(null, ApiErrorCause.cancelled)), FailureDisposition.ignore);
    expect(classifyFailure(StateError('bug')), FailureDisposition.report);
    expect(classifyFailure(const FormatException('bad')), FailureDisposition.report);
    expect(classifyFailure(Exception('expected')), FailureDisposition.breadcrumb);
  });

  test('SDK options disable personal data and additional products', () {
    final options = SentryFlutterOptions();
    configureErrorMonitoring(
      options,
      const ErrorMonitoringConfiguration(dsn: 'https://key@example.com/1', environment: 'staging'),
    );
    expect(options.sendDefaultPii, isFalse);
    expect(options.beforeSendLog, isNotNull);
    expect(options.beforeSendMetric, isNotNull);
    expect(options.tracesSampleRate, 0);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
    expect(options.attachScreenshot, isFalse);
    expect(options.attachViewHierarchy, isFalse);
    expect(options.enableNativeCrashHandling, isFalse);
    expect(options.beforeSend, isNotNull);
    expect(options.maxBreadcrumbs, 30);
    expect(options.enableAutoSessionTracking, isTrue);
    expect(options.enableAppLifecycleBreadcrumbs, isTrue);
    expect(options.enableAutoNativeBreadcrumbs, isFalse);
    expect(options.enableUserInteractionBreadcrumbs, isFalse);
  });

  test('disabled monitoring runs startup without a native SDK', () async {
    var ran = false;
    await runWithErrorMonitoring(() {
      ran = true;
    });
    expect(ran, isTrue);
  });

  test('SDK capture applies privacy filter before serializing an envelope', () async {
    final transport = _RecordingTransport();
    await Sentry.init((options) {
      options
        ..dsn = 'https://key@example.com/1'
        ..environment = 'staging'
        ..transport = transport
        ..beforeSend = (event, _) => sanitizeErrorEvent(event);
    });
    try {
      final id = await Sentry.captureException(StateError('private-token'));
      expect(id, isNot(SentryId.empty()));
      expect(transport.envelopes, hasLength(1));
      final event = transport.envelopes.single.items.single.dataFactory();
      final json = utf8.decode(await event);
      expect(json, contains('StateError'));
      expect(json, isNot(contains('private-token')));
    } finally {
      await Sentry.close();
    }
  });

  test('provider observer reports faults once with breadcrumbs of prior failures', () async {
    final transport = _RecordingTransport();
    await Sentry.init((options) {
      options
        ..dsn = 'https://key@example.com/1'
        ..environment = 'staging'
        ..transport = transport
        ..beforeSend = ((event, _) => sanitizeErrorEvent(event));
      options.beforeBreadcrumb = (crumb, _) => crumb == null ? null : sanitizeBreadcrumb(crumb);
    });
    final rejected = FutureProvider<int>(
      (_) => throw const VantaApiFailure(
        'k',
        details: ApiErrorDetails(status: 400, message: 'private-message'),
      ),
    );
    final broken = FutureProvider<int>(
      (_) => throw VantaApiFailure(
        'k',
        details: const ApiErrorDetails(status: 502, endpoint: '/v1/account'),
      ),
    );
    final container = ProviderContainer(
      observers: [ErrorMonitoringObserver()],
      retry: (_, _) => null,
    );
    try {
      await expectLater(container.read(rejected.future), throwsA(isA<VantaApiFailure>()));
      await expectLater(container.read(broken.future), throwsA(isA<VantaApiFailure>()));
      container.invalidate(broken);
      await expectLater(container.read(broken.future), throwsA(isA<VantaApiFailure>()));
      // Observer reports are fire-and-forget; let the SDK finish processing.
      for (var i = 0; i < 50 && transport.envelopes.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(transport.envelopes, hasLength(1));
      final json = utf8.decode(await transport.envelopes.single.items.single.dataFactory());
      expect(json, isNot(contains('private')));
      expect(json, contains('"error.status":"502"'));
      expect(json, contains('"vanta.source":"provider"'));
      expect(json, contains('vanta.failure'));
      expect(json, contains('"error.status":"400"'));
    } finally {
      container.dispose();
      await Sentry.close();
    }
  });
}

class _RecordingTransport implements Transport {
  final envelopes = <SentryEnvelope>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId;
  }
}
