"""Write Vanta's public compile-time configuration from Actions variables."""

import json
import os
from pathlib import Path
from urllib.parse import urlparse


def configuration(environment):
    keys = ("PRIVY_APP_ID", "PRIVY_CLIENT_ID", "REOWN_PROJECT_ID")
    missing = [key for key in keys if not environment.get(key, "").strip()]
    if missing:
        raise ValueError("Missing or empty required app configuration: " + ", ".join(missing))
    values = {key: environment[key].strip() for key in keys}
    values["WALLET_LOGIN_ORIGIN"] = _origin(
        "WALLET_LOGIN_ORIGIN", environment.get("WALLET_LOGIN_ORIGIN", "https://app.vanta.exchange"))
    # Optional until the backend is deployed; empty disables Vanta API portfolio statistics.
    api = environment.get("VANTA_API_ORIGIN", "").strip()
    values["VANTA_API_ORIGIN"] = _origin("VANTA_API_ORIGIN", api) if api else ""
    return values


def _origin(key, value):
    origin = value.strip()
    url = urlparse(origin)
    if (url.scheme != "https" or not url.hostname or url.username or url.password
            or url.path not in ("", "/") or url.query or url.fragment):
        raise ValueError(f"{key} must be an HTTPS origin without credentials.")
    return origin.rstrip("/")


if __name__ == "__main__":
    try:
        values = configuration(os.environ)
        destination = Path("config/ci.local.json")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(values, indent=2) + "\n")
        print("Created public Flutter configuration (values omitted).")
    except ValueError as error:
        raise SystemExit(str(error)) from None
