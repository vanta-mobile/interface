# Local changes to reown_appkit 1.9.0

Source: https://pub.dev/packages/reown_appkit/versions/1.9.0
Upstream: https://github.com/reown-com/reown_flutter/tree/master/packages/reown_appkit
The published library, package metadata and original LICENSE are retained.

Runtime changes are limited to `lib/modal/appkit_modal_impl.dart`,
`lib/modal/services/explorer_service/explorer_service.dart` and the new
`lib/modal/services/explorer_service/wallet_catalog_request.dart`,
`lib/modal/services/uri_service/request_wallet_launcher.dart` and
`lib/modal/services/uri_service/relay_wallet_request.dart`:

- A restored WalletConnect session can have a peer native/universal redirect
  while the explorer's `connectedWallet` cache entry is absent. Use that session
  redirect without requiring a cached explorer entry. Keep the cached mobile
  link as the fallback when the peer supplies neither redirect. Do not infer a
  wallet from its name or hardcode a MetaMask scheme.
- Keep Coinbase, Phantom, Solflare, Magic and Link Mode launch ownership with
  their existing native services / Sign Engine. Dispatch requests through the
  original AppKit request method exactly once.
- Await `openRedirect`, inspect a false result, and bound the OS launch call to
  five seconds. Emit `ErrorOpeningWallet` for missing launch data, OS refusal,
  exceptions or a hanging launch call. Upstream silently returned on missing
  cached data and ignored the launch future, leaving callers waiting for a
  request in a wallet that had never opened.
- Strip the existing `/wc` path before the SDK formats the pending request URI,
  preserving its request ID and session topic. These values never enter app UI
  error messages. The application retains its sanitizer for SDK explanations.
- For standard relay requests, subscribe before dispatch and wait for the relay
  acceptance event matching both the topic and correlation ID before launching
  the wallet. Preserve validation/relay errors such as `Invalid Id`; do not open
  a wallet for a request the relay rejected. Bound publish waiting to ten seconds
  and ignore late acknowledgements. Early replies do not require another launch.
  Link Mode and native service requests keep their existing delivery ownership.
- Carry a request-scoped identity/cancellation guard through asynchronous SDK
  work, so an abandoned signature cannot open a wallet after a late publish.
  Concurrent guards are isolated with a zone rather than shared mutable state.
  Remove publish listeners after acknowledgement, failure or timeout; no wallet
  request or financial write is automatically replayed.
- `init(restoreOnly: true)` restores the session without fetching the wallet
  directory or initializing unrelated native wallet SDKs. Stored native-wallet
  sessions retain their existing service setup. Explicit `init()` prepares the
  directory/services even after local restoration completed; concurrent callers
  share initialization, and failed initialization/catalog preparation can retry
  without duplicate event listeners. Local initialization no longer waits on an
  unbounded relay-ready completer or treats socket readiness as modal readiness.
  Request-time relay and peer checks remain required for signing.
- Bound each explorer GET (headers and body) to five seconds using an abortable
  HTTP request, without closing the shared client. Existing empty/cache fallbacks
  remain in place. Directory timeouts cannot leave the setup future pending
  forever. The caller still bounds preparation and cannot open late wallet UI.

Regression coverage: `test/features/auth/reown_wallet_launch_test.dart` exercises
the extracted SDK launch boundary with restored MetaMask redirect metadata,
cache/universal fallbacks, missing redirects, OS failure and late launch results.
`reown_signing_network_test.dart` and `reown_signature_request_test.dart` cover
propagation to the connection, timeout/invalidations, late request suppression,
relay preparation and explicit 4902-only network addition.
`reown_request_delivery_test.dart` covers matching acknowledgements, `Invalid Id`,
late/cancelled requests, isolated guards and financial unknown outcomes;
`reown_session_liveness_test.dart` covers peer rechecks after app resume.
`reown_initialization_test.dart` exercises the actual patched modal against local
stores and controlled services, including offline restoration, failed initialization
retry, listener ownership and catalog retry. `reown_wallet_catalog_test.dart`
checks actual loopback HTTP abortion before headers/during bodies and isolation
between requests on the same client. The connector and entry-routing suites
cover timeout/retry ownership and preserving the onboarding page during connection.

The application now uses its existing guarded wallet-request dispatcher for
network approval as well as personal/typed signing. This is outside the vendored
patch: it retains raw JSON-RPC codes until network preparation handles 4902 and
maps remaining failures at the connection boundary. No wallet request, signature
or financial write is automatically replayed.

This local override leaves the machine's pub cache unchanged. Remove it when an
upstream release provides equivalent launch behavior and passes the regressions.
