# Vanta Flutter implementation guidance

Adapted from `/data/dodo/rwa-interface/.specify/memory/constitution.md` v1.1.1 and its `AGENTS.md`. Only rules relevant to this client are included.

## Architecture and state
- Separate presentation, application/domain logic, and data access. Keep widgets responsible for rendering state and collecting intent.
- Application data requests follow `Widget → Riverpod provider/notifier → repository → service`.
- Never construct HTTP/WebSocket clients in widgets. Map transport payloads into validated immutable domain models at the data boundary.
- Before creating a component, inspect existing components and reuse those that fit the actual behavior and design. Do not force reuse when it introduces unrelated behavior, excessive configuration, or coupling. Keep components within their owning feature; promote shared components only when there are real consumers.
- Check file and build-method size while coding. Review files beyond 400 lines and build methods beyond 80 lines for cohesive extraction to improve token efficiency and reduce maintenance cost. Split along meaningful responsibilities; do not split solely to meet a line count.
- Apply appropriate code design principles to keep implementations robust, maintainable, and performant. Keep abstractions proportional to the actual requirements.
- Observe frequently changing state near the widgets that consume it.

## API integration and transport lifecycle
- Route API intents through Riverpod controllers/providers and feature repositories. Providers compose dependencies and expose domain state; parse and validate HTTP/WebSocket payloads in data-layer mappers/repositories, including public market data. Do not expose mutable transport maps as application state.
- Inject backend-scoped HTTP connection pools and rate-limit budgets through Riverpod. A feature service owns its request lifetime, not an injected shared pool; disposing or cancelling one feature must not close another feature's connections or cancel its requests. Keep credentials, signed query bytes and custom numeric decoders request/service scoped.
- Make in-flight HTTP requests abortable. Timeouts, operation cancellation, account/symbol changes and disposal must stop the applicable transport as well as prevent late state writes. Propagate cancellation through preflight requests, response bodies, retries and backoff; retain identity/revision guards around wallet signing and asynchronous results.
- Cancellation or timeout after a financial write was dispatched means its outcome may be unknown. Preserve existing recovery journals and verify server state before retrying. Never automatically replay orders, transfers, withdrawals or other signed writes.
- Share equivalent public WebSocket subscriptions with reference-counted ownership. Replay current connection state to late subscribers, retain feature-specific freshness/validation rules, and close the underlying subscription when its last consumer leaves. Never share private account streams or credential state across identities.
- Centralize transport mechanics (connection reuse, bounded response reads, cancellation and host rate-limit cooldowns) without coupling unrelated API contracts. Respect Retry-After; restrict automatic retries to explicitly safe reads, and ensure cancellation interrupts queued/backoff work.
- Verify transport changes with tests for cancellation before headers and during response bodies, timeout/disposal, isolation between consumers, shared subscription reconnection/teardown, malformed payloads and financial unknown-outcome recovery. Record scope and actual verification in docs/implementation.md.

## Design and accessibility
- Follow the supplied design and explicit user requirements. Do not invent extra UI, status indicators, state displays, or interactions beyond that scope.
- Use centralized semantic theme tokens for colors and typography. No literal colors in feature widgets; third-party chart adaptation is an allowed boundary.
- Base responsive layouts on available constraints; support narrow windows, landscape, safe areas, keyboard, and enlarged text. Never lock orientation. The single exception is the fullscreen K-line chart, which requests landscape only while it is open and restores the system default when it closes.
- Keep user-visible strings in the localization catalog. Provide clear semantic labels and usable touch targets. Financial identifiers and order references must be copyable.
- Handle loading, empty, success, partial/offline data, and recoverable errors within the agreed design and requirements. Preserve input after failures; follow the feedback rules below without inventing additional status displays.

## Errors, loading, and refresh
- Prefer the actual API-provided error message when displaying failures. If none is available, show the concrete known cause; use generic fallback copy only when the cause is genuinely unknown. Keep useful diagnostic detail while excluding secrets, credentials, raw sensitive payloads, and stack traces.
- Carry typed error details (safe server message, HTTP status, known transport cause and existing business code) from the data boundary through Riverpod state to the existing error UI. Keep stable localization/recovery keys for behavior; never infer financial success or retry safety from display text. Treat explicit business failure envelopes as errors even on HTTP 200. A temporary HTTP 429 is not evidence that a daily quota is exhausted.
- Prefer skeleton placeholders scoped to the section that is loading, without blocking or disturbing other content. Unless the feature has exceptionally strict real-time requirements, show loading placeholders only when that section has no data; preserve existing data during refreshes.
- Every page that displays API data must support pull-to-refresh. Refresh all API-backed data the page depends on, and keep the refresh indicator active until all requests triggered by that refresh have settled, including failures. Await the complete refresh operation rather than ending the indicator after dispatching requests.
- While a button-triggered operation is pending, disable the button and show a spinning loading indicator in it to prevent duplicate submissions. Consider a shared loading-button component when there are real reuse opportunities.

## Numeric display
- Consider `AnimatedNumberText` from `lib/core/motion/animated_number_text.dart` for all changing numeric displays, following the design and user requirements.
- For every numeric display, consider the existing helpers in `lib/core/formatters/` and select the method appropriate to the value's units, precision, and context. Reuse suitable formatters instead of duplicating formatting logic in widgets.

## Illustration and icon assets
- Prefer downloading SVG illustrations and icons directly from the design source.
- If the design has no vector asset, export a 3x PNG with `contentsOnly: true` and preserve the transparent background. Convert that PNG to lossless WebP using ImageMagick and use the resulting WebP asset in the app.

## Financial integrity
- Use decimal arithmetic for order quantities, notionals, margin, and validation. Chart drawing coordinates may use doubles.
- Preserve units and precision. A UI action is never evidence of an on-chain execution.
- This implementation supports a clearly labeled local demo account. Never represent demo funds, orders, or positions as real wallet activity. Real wallet signing and authenticated order execution require a separately integrated authenticated API.
- Secrets, credentials, raw sensitive payloads, and stack traces must not be shown in UI or committed.

## Verification and dependencies
- Supported application platforms are Android and iOS only. Keep responsive layouts for phones, tablets, and landscape; Web is not a build or acceptance target.
- Record behavior, boundaries, and acceptance checks in `docs/implementation.md`.
- Before completion run formatting, static analysis, and relevant unit/widget tests.
- Unless the user explicitly requests it, do not launch, hot reload, hot restart, or package/build the app for testing, and do not test on physical devices or emulators. Run native visual checks and Android/iOS builds only when explicitly requested; record actual verification and any environment limitations.
- Dependencies need a specific purpose. `k_chart_plus` is required for the candlestick chart; Riverpod owns application state, HTTP/WebSocket clients own public market transport, and decimal owns financial arithmetic.

## Git commit messages
- Follow Conventional Commits: `<type>(<scope>): <summary>`. Scope is optional; use a lowercase feature or module name such as `auth`, `market`, `portfolio`, `android`, or `ios`.
- Use a lowercase type: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore`, `style`, or `revert`. Choose the type that describes the actual change; user-facing features and fixes must not be labeled `chore` or `ci`, because release notes filter these types.
- Write all commit summaries, bodies, and footers in English. Use the imperative mood in the summary, keep the subject within 72 characters, describe the concrete change, and omit a trailing period. Avoid vague subjects such as "update", "fix bugs", or "modify code".
- Keep each commit focused on one cohesive change. If a body is needed, separate it from the subject with a blank line and explain the reason, relevant behavior, and verification actually performed; do not claim checks that were not run.
- Mark breaking changes with `!` before the colon and include a `BREAKING CHANGE:` footer describing the impact and required migration.
- Never include credentials, private keys, tokens, or sensitive payloads in commit messages.
- Examples: `feat(auth): support external wallet login`, `fix(market): clear stale quotes when switching symbols`, `ci(ios): detect signing configuration before building`, `docs: document certificate creation on Linux`.
