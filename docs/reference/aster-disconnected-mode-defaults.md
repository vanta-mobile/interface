# Aster disconnected mode defaults (2026-11-10)

Read-only inspection of the official public frontend modules:

- https://static2.asterdexfx.com/assets/useMarginMode-DX329N_3.js
  - Store initializer: `marginMode: CROSS`.
  - Provides `updateMarginMode` for subsequent state updates.
- https://static2.asterdexfx.com/assets/usePreference-Bk2e39gr.js
  - Export `r` maps to `Pn`, used by the trade form for asset mode.
  - `Pn` queries `assetmode-request` only when logged in.
  - When logged out it returns `true`; when logged in it returns a successful account response's `data.joinMargin`, otherwise `false`.
- https://static2.asterdexfx.com/assets/_-_locale_.trade.pro._tradeType._symbol-DTV_Ceud.js
  - Order form imports the asset-mode hook and renders `M` when true, `S` otherwise.
  - Margin-mode control renders the current margin store value.

Conclusion: cross and multi-assets are local disconnected previews, not facts obtained from a per-market capability API. This evidence establishes initialization behavior only, not eligibility of every market/account combination. Vanta shows the disconnected defaults, keeps actual signed account facts authoritative, and does not automatically submit settings to the exchange. Logged-in but unread accounts keep unknown values rather than inheriting disconnected presets.
