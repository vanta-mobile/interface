# Local changes to reown_core 1.5.1

Source: https://pub.dev/packages/reown_core/versions/1.5.1
Upstream: https://github.com/reown-com/reown_flutter/tree/master/packages/reown_core
The original source license is retained in LICENSE. The library and package
metadata are copied from the published 1.5.1 release.

Runtime changes are limited to `lib/relay_client/relay_client.dart`,
`lib/relay_client/i_relay_client.dart`, `lib/relay_client/relay_client_models.dart`
and the bundled JSON-RPC `src/client.dart` / `src/peer.dart`:

- Claim connection ownership before the first asynchronous cleanup/JWT step.
  All concurrent connection paths share the same future, including AppKit
  resume, signing preparation, connectivity, heartbeat and socket-close
  recovery. A second connection must not close a first connection with a pending
  `irn_subscribe` request.
- Invalidate suspended connection preparation on explicit disconnect. Check
  ownership after each asynchronous preparation step and close sockets that
  finish opening after disconnect.
- Share in-progress disconnect cleanup and await it before a new connection.
  Ignore close callbacks from JSON-RPC peers that are no longer current.
- Release connection ownership on success/failure. Preserve upstream's
  connection-only timeout retry after releasing ownership, unless disconnected.
  Do not replay signing requests or financial writes.
- Return without dispatch when an awaited connection ended disconnected.
- Use the relay protocol's 19-digit timestamp-plus-entropy IDs as decimal
  strings. Small JSON-RPC counters violate that protocol; 19-digit JSON numbers
  lose precision in JavaScript. Keep IDs increasing within this relay client
  to avoid same-millisecond collisions. The bundled JSON-RPC client/peer accept
  integer or string IDs and match exact keys first. The live relay returns JSON
  integers for our decimal-string request IDs; correlate those through the exact
  native integer's decimal representation as well as the legacy reverse echo.
  Never match via floating point rounding. Ignore unknown or malformed IDs.
  Wallet session request IDs, signatures and payloads are unchanged.
  Protocol: https://github.com/WalletConnect/walletconnect-specs/blob/main/docs/specs/servers/relay/relay-server-rpc.md#definitions
- Emit `onRelayClientPublish` only after a successful `irn_publish` acknowledgement,
  with the topic and original correlation ID, excluding message bytes. Rejection,
  disconnect or a non-true result cannot emit acceptance. This event allows
  AppKit to wait for the matching request before opening a wallet. A relay
  acknowledgement does not prove wallet receipt, approval or execution.

Regression coverage lives in
`test/features/auth/reown_relay_connection_test.dart` and
`test/features/auth/reown_signature_request_test.dart`,
`test/features/auth/reown_session_liveness_test.dart` and
`test/features/auth/reown_request_delivery_test.dart`. The original SDK fails
the overlapping reconnect regression cases; the pending-subscribe case reproduces the exact
`The client closed with pending request "irn_subscribe".` error using its real
JSON-RPC implementation and a controlled local socket.

`test/features/auth/reown_json_rpc_response_id_test.dart` covers native integer
echoes for subscribe/publish/proposal, error replies, adjacent 19-digit IDs, exact
type preference, reverse echoes and rejection of rounded doubles. The real relay
test harness echoes 19-digit string requests as integers to match device evidence.

The application also removes its redundant resume reconnect: AppKit already
owns that lifecycle callback. Its signing watchdog still observes resume.

This local override ships the fix without changing the machine's pub cache.
Remove it when an upstream release provides equivalent connection/disconnect
guards and passes these regression tests. The other vendored sources remain
unchanged; the upstream relay file retains its existing responsibilities.
