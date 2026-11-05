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
    origin = environment.get("WALLET_LOGIN_ORIGIN", "https://app.vanta.exchange").strip()
    url = urlparse(origin)
    if (url.scheme != "https" or not url.hostname or url.username or url.password
            or url.path not in ("", "/") or url.query or url.fragment):
        raise ValueError("WALLET_LOGIN_ORIGIN must be an HTTPS origin without credentials.")
    values["WALLET_LOGIN_ORIGIN"] = origin.rstrip("/")
    return values


if __name__ == "__main__":
    try:
        values = configuration(os.environ)
        destination = Path("config/ci.local.json")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(values, indent=2) + "\n")
        print("Created public Flutter configuration (values omitted).")
    except ValueError as error:
        raise SystemExit(str(error)) from None
