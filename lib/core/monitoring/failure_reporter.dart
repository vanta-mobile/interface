import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/wallet_operation_journal.dart';
import '../errors/api_error_details.dart';
import '../market_failure.dart';
import 'error_event_filter.dart';

enum FailureDisposition { report, breadcrumb, ignore }

/// Programming errors, malformed payloads, server faults and local storage
/// failures are reported. Expected business/4xx/network failures only leave a
/// breadcrumb so a later crash shows what preceded it; cancellation is ignored.
FailureDisposition classifyFailure(Object error) {
  final details = errorDetailsOf(error) ?? (error is MarketFailure ? error.details : null);
  if (error is DetailedApiFailure || error is MarketFailure) {
    if (details?.cause == ApiErrorCause.cancelled) return FailureDisposition.ignore;
    final serverFault = (details?.status ?? 0) >= 500 && details?.cause != ApiErrorCause.rateLimit;
    return serverFault || details?.cause == ApiErrorCause.invalidResponse
        ? FailureDisposition.report
        : FailureDisposition.breadcrumb;
  }
  if (error is Error ||
      error is FormatException ||
      error is FileSystemException ||
      error is WalletOperationStorageFailure) {
    return FailureDisposition.report;
  }
  return FailureDisposition.breadcrumb;
}

/// Reports a failure the app already handled (for example a blocking journal
/// state). [operation] is a fixed dotted identifier such as `journal.reload`.
Future<void> reportHandledFailure(
  Object error,
  StackTrace stackTrace, {
  required String operation,
  String source = 'handled',
  Map<String, String> tags = const {},
}) async {
  if (!Sentry.isEnabled || !_deduplicator.admit(error, stackTrace, operation)) return;
  await Sentry.captureException(
    error,
    stackTrace: stackTrace,
    withScope: (scope) async {
      await scope.setTag('vanta.operation', operation);
      await scope.setTag('vanta.source', source);
      for (final MapEntry(:key, :value) in tags.entries) {
        await scope.setTag(key, value);
      }
    },
  );
}

void recordFailureBreadcrumb(Object error, {String? operation}) {
  if (!Sentry.isEnabled) return;
  Sentry.addBreadcrumb(
    Breadcrumb(
      category: 'vanta.failure',
      type: 'error',
      level: SentryLevel.warning,
      data: {
        'type': '${error.runtimeType}',
        'vanta.operation': ?operation,
        ...safeFailureTags(error),
      },
    ),
  );
}

/// Observes Riverpod provider failures centrally instead of instrumenting each catch.
final class ErrorMonitoringObserver extends ProviderObserver {
  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    switch (classifyFailure(error)) {
      case FailureDisposition.report:
        reportHandledFailure(error, stackTrace, operation: 'provider', source: 'provider');
      case FailureDisposition.breadcrumb:
        recordFailureBreadcrumb(error);
      case FailureDisposition.ignore:
    }
  }
}

/// Polling providers can fail repeatedly; one event per cause per window is enough.
final _deduplicator = _FailureDeduplicator();

class _FailureDeduplicator {
  static const _window = Duration(minutes: 10);
  final _seen = <String, DateTime>{};

  bool admit(Object error, StackTrace stackTrace, String operation) {
    final now = DateTime.now();
    _seen.removeWhere((_, at) => now.difference(at) > _window);
    final tags = safeFailureTags(error);
    // The leading frames distinguish unrelated errors of the same type.
    final origin = stackTrace.toString().split('\n').take(3).join('|');
    final key = '${error.runtimeType}|$operation|${failureSummary(tags)}|$origin';
    if (_seen.containsKey(key) || _seen.length >= 100) return false;
    _seen[key] = now;
    return true;
  }
}
