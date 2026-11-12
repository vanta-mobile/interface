# Vanta API contract

`openapi.yaml` is a byte-for-byte copy of `docs/openapi.yaml` from the private
`vanta-mobile/vanta-api` repository, pinned in `contract.lock.json` (commit + SHA-256).
The app's data layer is written against this file only, never against the backend code.

- Check (offline, also part of CI's `scripts/*_test.py`): `python3 scripts/vanta_api_contract.py check`
- Update: `python3 scripts/vanta_api_contract.py sync [--ref <branch|tag|sha>]` (uses `gh`, needs read access),
  then run `flutter test test/core/vanta_api_contract_test.dart` and the portfolio/auth tests, and commit both files together.

Do not edit `openapi.yaml` by hand; change the upstream contract instead.
