import 'package:sentry_flutter/sentry_flutter.dart';

import '../errors/api_error_details.dart';
import '../market_failure.dart';
import '../vanta_api/vanta_api_failure.dart';

/// Tags produced from typed failures or explicit reports. Everything else is dropped.
const _safeTagKeys = {
  'error.status',
  'error.cause',
  'error.endpoint',
  'error.key',
  'error.code',
  'vanta.operation',
  'vanta.source',
  // Wallet app launch failures: failure kind, wallet name and link scheme/host.
  'wallet.launch',
  'wallet.name',
  'wallet.scheme',
  'wallet.host',
};

/// Breadcrumbs from SDK lifecycle/memory hooks and [recordFailureBreadcrumb].
const _safeBreadcrumbCategories = {'app.lifecycle', 'device.event', 'vanta.failure'};
const _safeBreadcrumbData = {'state', 'action', 'type', ..._safeTagKeys};

final _safeValue = RegExp(r'^[A-Za-z0-9_.:/{}-]{1,160}$');
final _identifierSegment = RegExp(r'^(\d+|(0x)?[0-9a-fA-F]{16,})$');

/// Allowlist rather than regex-redacting arbitrary wallet/API/chat payloads.
/// Keep error types, code locations, typed failure metadata and coarse device
/// information, never exception values, user data or request payloads.
SentryEvent sanitizeErrorEvent(SentryEvent event) {
  final tags = {...safeFailureTags(event.throwable), ..._tags(event.tags)};
  final summary = failureSummary(tags);
  return SentryEvent(
    eventId: event.eventId,
    timestamp: event.timestamp,
    platform: event.platform,
    sdk: event.sdk,
    release: event.release,
    dist: event.dist,
    environment: event.environment,
    level: event.level,
    tags: tags.isEmpty ? null : tags,
    contexts: _contexts(event.contexts),
    breadcrumbs: event.breadcrumbs?.map(sanitizeBreadcrumb).nonNulls.toList(),
    debugMeta: _debugMeta(event.debugMeta),
    exceptions: event.exceptions
        ?.map(
          (exception) => SentryException(
            type: _safeType(exception.type),
            value: summary ?? '[redacted]',
            stackTrace: exception.stackTrace == null
                ? null
                : SentryStackTrace(
                    frames: exception.stackTrace!.frames
                        .map(
                          (frame) => SentryStackFrame(
                            fileName: _sourcePath(frame.fileName),
                            function: frame.function,
                            lineNo: frame.lineNo,
                            colNo: frame.colNo,
                            inApp: frame.inApp,
                            platform: frame.platform,
                            instructionAddr: frame.instructionAddr,
                            imageAddr: frame.imageAddr,
                            symbolAddr: frame.symbolAddr,
                          ),
                        )
                        .toList(),
                  ),
            mechanism: exception.mechanism == null
                ? null
                : Mechanism(
                    type: _safeType(exception.mechanism!.type),
                    handled: exception.mechanism!.handled,
                  ),
          ),
        )
        .toList(),
    message: event.exceptions?.isNotEmpty == true
        ? null
        : SentryMessage('Vanta error (details redacted)'),
  );
}

Breadcrumb? sanitizeBreadcrumb(Breadcrumb crumb) {
  if (!_safeBreadcrumbCategories.contains(crumb.category)) return null;
  final data = <String, String>{
    for (final MapEntry(:key, :value) in (crumb.data ?? const {}).entries)
      if (_safeBreadcrumbData.contains(key) && value is String && _safeValue.hasMatch(value))
        key: value,
  };
  return Breadcrumb(
    category: crumb.category,
    type: crumb.type,
    level: crumb.level,
    timestamp: crumb.timestamp,
    data: data.isEmpty ? null : data,
  );
}

/// Structured, non-secret metadata carried by typed data-boundary failures.
/// The human-readable server message is deliberately excluded.
Map<String, String> safeFailureTags(Object? error) {
  final details =
      errorDetailsOf(error ?? const Object()) ?? (error is MarketFailure ? error.details : null);
  final endpoint = _endpoint(details?.endpoint);
  return {
    if (details?.status case final status?) 'error.status': '$status',
    if (details?.cause case final cause?) 'error.cause': cause.name,
    'error.endpoint': ?endpoint,
    if (error is VantaApiFailure) ...{
      if (_safeValue.hasMatch(error.key)) 'error.key': error.key,
      if (error.code case final code? when _safeValue.hasMatch(code)) 'error.code': code,
    },
  };
}

String? failureSummary(Map<String, String> tags) {
  final parts = [
    for (final key in const [
      'error.status',
      'error.cause',
      'error.code',
      'error.key',
      'error.endpoint',
    ])
      if (tags[key] case final value?) '${key.substring(6)}=$value',
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

Map<String, String> _tags(Map<String, String>? tags) => {
  for (final MapEntry(:key, :value) in (tags ?? const {}).entries)
    if (_safeTagKeys.contains(key) && _safeValue.hasMatch(value)) key: value,
};

/// Fixed API paths only; identifier-like segments are collapsed.
String? _endpoint(String? path) {
  if (path == null || !path.startsWith('/') || path.contains(RegExp(r'[?#]'))) return null;
  final segments = path
      .substring(1)
      .split('/')
      .map((segment) => _identifierSegment.hasMatch(segment) ? ':id' : segment);
  final result = '/${segments.join('/')}';
  return _safeValue.hasMatch(result) ? result : null;
}

/// Hardware/OS/app build information only; user-assigned device names,
/// identifiers, storage/memory figures and time zone are dropped.
Contexts _contexts(Contexts source) {
  final os = source.operatingSystem;
  final device = source.device;
  final app = source.app;
  final culture = source.culture;
  return Contexts(
    operatingSystem: os == null
        ? null
        : SentryOperatingSystem(name: os.name, version: os.version, build: os.build),
    device: device == null
        ? null
        : SentryDevice(
            family: device.family,
            model: device.model,
            modelId: device.modelId,
            arch: device.arch,
            manufacturer: device.manufacturer,
            brand: device.brand,
            simulator: device.simulator,
            orientation: device.orientation,
            lowMemory: device.lowMemory,
          ),
    app: app == null
        ? null
        : SentryApp(
            name: app.name,
            version: app.version,
            identifier: app.identifier,
            build: app.build,
            buildType: app.buildType,
            inForeground: app.inForeground,
          ),
    culture: culture == null ? null : SentryCulture(locale: culture.locale),
    runtimes: [
      for (final runtime in source.runtimes)
        SentryRuntime(name: runtime.name, version: runtime.version),
    ],
  );
}

String _safeType(String? type) =>
    type != null && RegExp(r'^[A-Za-z_][A-Za-z0-9_.<>? ,]{0,120}$').hasMatch(type) ? type : 'Error';

String? _sourcePath(String? path) {
  if (path == null) return null;
  // Retain only package-relative paths, never filesystem paths or URL queries.
  return RegExp(r'^(package|dart):[A-Za-z0-9_./-]+$').hasMatch(path) ? path : null;
}

DebugMeta? _debugMeta(DebugMeta? meta) {
  if (meta == null) return null;
  final result = DebugMeta();
  for (final image in meta.images) {
    result.addDebugImage(
      DebugImage(
        type: image.type,
        debugId: image.debugId,
        codeId: image.codeId,
        imageAddr: image.imageAddr,
        imageVmAddr: image.imageVmAddr,
        imageSize: image.imageSize,
        arch: image.arch,
      ),
    );
  }
  return result;
}
