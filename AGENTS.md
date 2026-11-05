# Vanta Flutter implementation guidance

Adapted from `/data/dodo/rwa-interface/.specify/memory/constitution.md` v1.1.1 and its `AGENTS.md`. Only rules relevant to this client are included.

## Architecture and state
- Separate presentation, application/domain logic, and data access. Keep widgets responsible for rendering state and collecting intent.
- Application data requests follow `Widget → Riverpod provider/notifier → repository → service`.
- Never construct HTTP/WebSocket clients in widgets. Map transport payloads into validated immutable domain models at the data boundary.
- Keep components within their owning feature; promote shared components only when there are real consumers. Review files beyond 400 lines and build methods beyond 80 lines for cohesive extraction.
- Observe frequently changing state near the widgets that consume it.

## Design and accessibility
- Use centralized semantic theme tokens for colors and typography. No literal colors in feature widgets; third-party chart adaptation is an allowed boundary.
- Base responsive layouts on available constraints; support narrow windows, landscape, safe areas, keyboard, and enlarged text. Never lock orientation.
- Keep user-visible strings in the localization catalog. Provide clear semantic labels and usable touch targets. Financial identifiers and order references must be copyable.
- Handle loading, empty, success, partial/offline data, and recoverable errors. Preserve input after failures and display concrete safe failure reasons.

## Financial integrity
- Use decimal arithmetic for order quantities, notionals, margin, and validation. Chart drawing coordinates may use doubles.
- Preserve units and precision. A UI action is never evidence of an on-chain execution.
- This implementation supports a clearly labeled local demo account. Never represent demo funds, orders, or positions as real wallet activity. Real wallet signing and authenticated order execution require a separately integrated authenticated API.
- Secrets, credentials, raw sensitive payloads, and stack traces must not be shown in UI or committed.

## Verification and dependencies
- Supported application platforms are Android and iOS only. Keep responsive layouts for phones, tablets, and landscape; Web is not a build or acceptance target.
- Record behavior, boundaries, and acceptance checks in `docs/implementation.md`.
- Before completion run formatting, static analysis, relevant unit/widget tests, and an Android build. Verify native layouts visually when device tooling is available. Verify iOS builds when macOS / Xcode is available and record any environment limitation.
- Dependencies need a specific purpose. `k_chart_plus` is required for the candlestick chart; Riverpod owns application state, HTTP/WebSocket clients own public market transport, and decimal owns financial arithmetic.

## Git commit messages
- Follow Conventional Commits: `<type>(<scope>): <summary>`. Scope is optional; use a lowercase feature or module name such as `auth`, `market`, `portfolio`, `android`, or `ios`.
- Use a lowercase type: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore`, `style`, or `revert`. Choose the type that describes the actual change; user-facing features and fixes must not be labeled `chore` or `ci`, because release notes filter these types.
- Write all commit summaries, bodies, and footers in English. Use the imperative mood in the summary, keep the subject within 72 characters, describe the concrete change, and omit a trailing period. Avoid vague subjects such as "update", "fix bugs", or "modify code".
- Keep each commit focused on one cohesive change. If a body is needed, separate it from the subject with a blank line and explain the reason, relevant behavior, and verification actually performed; do not claim checks that were not run.
- Mark breaking changes with `!` before the colon and include a `BREAKING CHANGE:` footer describing the impact and required migration.
- Never include credentials, private keys, tokens, or sensitive payloads in commit messages.
- Examples: `feat(auth): support external wallet login`, `fix(market): clear stale quotes when switching symbols`, `ci(ios): detect signing configuration before building`, `docs: document certificate creation on Linux`.
