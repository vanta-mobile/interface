# Sentry mobile error monitoring

## Provisioning result (2026-11-18)

Vanta uses Flutter 3.47.4 / Dart 3.13, Riverpod, Android Kotlin Gradle scripts
(minimum SDK 28), and iOS/Xcode (deployment target 17.0). `sentry_flutter` 10.5.0
supports this baseline. No previous Sentry integration was found. Firebase is
used for push messaging, not error monitoring.

Sentry CLI 2.58.2 is available through `nix shell nixpkgs#sentry-cli`, but not on
the default PATH. The existing user-level `.sentryclirc` authenticates. No token
was copied. It has organization/project read, event and alert permissions, but
no project creation permission. No default organization or project is set.
`projects --help` exposes only `list`, not creation. `organizations list` failed
to parse the response (`requireEmailVerification` missing). A read-only API query
found organization `dodo-k4` and Flutter project `rwa`, with no `vanta` project.
This is the token's visible scope, not proof that inaccessible projects do not exist.

### Confirmed connection (2026-11-18 follow-up)

After the user created the project, existing local authorization was used to
enumerate visible organizations and their projects. The sole visible organization
was `dodo-k4`; its project list and project detail confirmed `vanta`, team `dodo`,
platform `flutter`. The global `/projects/` endpoint returned an empty list, so it
must not be used alone to infer absence. No project was created and `rwa` was not
reused. This establishes the target within the existing authorization's visibility.

An active public DSN was read from `projects/dodo-k4/vanta/keys/` directly into
the ignored `.env`, preserving other configuration. `SENTRY_ENVIRONMENT` is
`development`. Neither the DSN nor authentication token is recorded here; the
existing user-level credential was not copied. Local Makefile commands consume
this configuration; commands that omit `--dart-define-from-file` do not.

## Configuration

Use ignored `.env` or `config/*.local.json`, passed by the existing Makefile via
`--dart-define-from-file`. `.env.example` lists the public configuration:

| Key | Meaning |
| --- | --- |
| `SENTRY_DSN` | Public project DSN; empty disables monitoring |
| `SENTRY_ENVIRONMENT` | Explicit `development`, `staging`, or `production`; required with DSN |
| `SENTRY_RELEASE` | Optional release identifier; SDK app metadata is the fallback |
| `SENTRY_DIST` | Optional build/distribution identifier |

Local/CI validators reject secret-bearing DSNs and exclude auth tokens from
app configuration. Runtime skips monitoring for invalid/missing DSN/environment
without blocking startup; there is no implicit production environment.
`lib/main.dart` wraps binding creation, Firebase initialization, recovery and
`runApp` in `runWithErrorMonitoring`. Only Android/iOS initialize the SDK.
Framework and uncaught root Dart errors use SDK integrations; already-handled
API/business failures are not automatically reported. No financial logic or UI changes.

## Privacy and coverage

`lib/core/monitoring/error_event_filter.dart` disables default PII and allowlists
event fields: error type, handled flag, package/Dart code locations, instruction
addresses, debug image IDs/addresses, timestamp, event ID, release/environment
and SDK metadata. It removes arbitrary messages, user/request, extras, threads,
absolute paths, locals, source snippets and debug-image filenames. Do not put
private values in release/dist identifiers or code symbol names.

Diagnostic metadata kept for triage (2026-11-18):

| Data | Kept | Dropped |
| --- | --- | --- |
| Typed failure tags (`error.*`) | HTTP status, `ApiErrorCause`, `VantaApiFailure` key/code, fixed endpoint with numeric/hex segments as `:id` | Server message, query strings, unsafe characters |
| Exception value | Summary built only from those tags, e.g. `status=503 cause=invalidResponse endpoint=/v1/orders/:id`; otherwise `[redacted]` | Original value |
| Report tags | `vanta.operation`, `vanta.source` | Any other tag |
| Contexts | OS name/version/build; device family/model/arch/manufacturer/simulator/orientation/low memory; app version/build/identifier; locale; runtimes | Device name, IDs, memory/storage, time zone, raw descriptions, custom contexts |
| Breadcrumbs (max 30) | `app.lifecycle`, memory pressure, `vanta.failure` with allowlisted data keys | Messages, HTTP/navigation/print/interaction/native breadcrumbs |

Coverage beyond uncaught Flutter/root-Dart errors (`lib/core/monitoring/failure_reporter.dart`):

- `ErrorMonitoringObserver` on the root `ProviderScope` classifies provider failures.
  Reported: Dart `Error`s, `FormatException`, file-system/journal storage failures,
  typed API failures with HTTP ≥500 (not 429) or `invalidResponse`. Breadcrumb only:
  other typed API failures (4xx, business, timeout, connection, rate limit) and other
  exceptions. Ignored: cancellation. Notifiers that catch errors without exposing an
  error state are not observed.
- `reportHandledFailure(error, stack, operation: ...)` reports failures the app already
  handled; startup journal reloads use `journal.<name>.reload`. Use fixed dotted
  identifiers only. Reports are de-duplicated per type/operation/summary/origin for
  10 minutes (Riverpod retries a failing provider repeatedly).

- Firebase push initialization failure (push unavailable) reports `push.initialize`.

Release health: automatic sessions are enabled. The native SDKs (started by the
plugin) record sessions with release/environment/status and a random installation
ID, without user identity or IP (`sendDefaultPii = false`). Use them for adoption
and errored/unhandled-session rates per release. Because native crash handling is
off, the crash-free rate does not include native crashes.

No user identity or HTTP/navigation/logging integration is added; routes are
unnamed, so navigation breadcrumbs were deliberately not added.
Screenshots, view hierarchy, replay and tracing are disabled. Log/metric
callbacks drop all payloads. No paid product or plan is enabled.
Error events still consume the existing event quota. The server receives the
network connection; administrators must review server-side IP scrubbing and
retention before production activation.

**Native Java/Kotlin/Swift/Objective-C/NDK crashes, ANRs, app hangs and watchdog
terminations are disabled:** their envelopes bypass Dart's `beforeSend` filter.
Enable them only with equivalent native privacy filters and native acceptance
checks. Native SDK linkage remains for Flutter transport/symbolication. Native init
would need to move from the plugin to app code (`autoInitializeNativeSdk = false`)
to install those filters before cached crash reports are sent; deferred until the
iOS side can be compiled and accepted on devices.

The Firebase background message isolate is not instrumented: its handler only calls
`Firebase.initializeApp`, and initializing Sentry there would re-initialize the
shared native SDK. Do not assume coverage for background/custom isolates.

## Release integration

GitHub repository variables `SENTRY_DSN` (verified public DSN), `SENTRY_ENVIRONMENT`,
`SENTRY_ORG=dodo-k4`, and `SENTRY_PROJECT=vanta` are set (org/project added
2026-11-19 after the first release failed without them); local `.env`
configuration does not configure Actions.
The release workflow uses `vanta@<pubspec version>` (for example `vanta@1.4.0+52`)
as release and the source SHA as dist.
Set `SENTRY_AUTH_TOKEN` as an Actions **Secret** with debug-file upload permissions;
it is injected only into the upload step, never the generated Flutter JSON.
The existing token's debug-upload permissions have not been tested.

With a DSN, release jobs install pinned `@sentry/cli@2.58.2` and run
`python3 scripts/upload_sentry_symbols.py android` or `ios`. The helper fails on
missing credentials, CLI or symbols, and awaits processing via `--wait`.
It uploads both Android APK/AAB Dart symbol sets, or iOS Dart symbols and archive
dSYMs. Builds also save `build/obfuscation/{android,android-bundle,ios}.json`; the
helper pairs each map with its build's `app.android-*.symbols` or
`App.framework.dSYM/.../App` and runs `dart-symbol-map upload` (with the same
debug-ID marker the official plugin adds), so obfuscated exception types are
readable in Sentry. A missing map fails the job. It does not upload source or build anything. Without a DSN, these steps
are skipped. Flutter plugin registration supplies Android/iOS SDK linkage;
no separate native DSN/token is added. If R8/ProGuard is enabled later, add its
mapping upload; this change does not enable shrinking or add a Gradle plugin.

## Acceptance boundaries

See `implementation.md` for actual check results. Pending: device execution on
both platforms, release jobs,
debug-file upload/processing and actual obfuscated-stack symbolication.
No mobile app was launched/built/packaged/deployed. A single controlled envelope
with a static message and no account, request, device or financial data was sent
to the confirmed project, using `development` and release
`vanta-sentry-ingestion-check`. Ingestion returned HTTP 200; subsequent project
event lookup confirmed event `3cf27a9ff93042b3a1ebfccee519eaab` after two initial
404 responses during processing. This verifies server ingestion, not mobile SDK
hooks, privacy filtering on a device, native crash coverage or symbolication.
A separate recording-transport test verifies SDK filtering locally.

After target confirmation, use temporary staging test code to capture
`Sentry.captureException(StateError('Vanta controlled smoke test'))`, then await
`Sentry.flush(timeout: const Duration(seconds: 10))`. No account/request data
should be included. Verify the returned event ID in the confirmed project's
Issues/API, with environment/release, redacted value and readable frames, then
remove temporary code. Do not add a permanent startup event or UI button.
Returned event IDs, successful flushes and successful builds do not prove reception.
A CLI event alone would verify ingestion, not mobile error hooks or symbolication.
