#!/usr/bin/env python3
"""Prepare optional Google Play credentials outside the workspace; never log them."""

import argparse
import json
import os
from pathlib import Path
import sys


SECRET = "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"


def credentials_path():
    return Path(os.environ["RUNNER_TEMP"]) / "vanta-google-play" / "service-account.json"


def validate_credentials(raw):
    try:
        credentials = json.loads(raw)
    except ValueError:
        raise ValueError(f"{SECRET} must contain the original service account JSON, not Base64.") from None
    if not isinstance(credentials, dict) or credentials.get("type") != "service_account":
        raise ValueError(f"{SECRET} must be a service account JSON object.")
    for field in ("project_id", "client_email", "private_key", "token_uri"):
        if not isinstance(credentials.get(field), str) or not credentials[field].strip():
            raise ValueError(f"{SECRET} is missing a non-empty {field} field.")
    if credentials["token_uri"] != "https://oauth2.googleapis.com/token":
        raise ValueError(f"{SECRET} must use Google's OAuth token endpoint.")
    key = credentials["private_key"].strip()
    if not key.startswith("-----BEGIN PRIVATE KEY-----\n") or not key.endswith("\n-----END PRIVATE KEY-----"):
        raise ValueError(f"{SECRET} must include the original PEM private_key.")


def configure():
    raw = os.environ.get(SECRET, "").strip()
    if not raw:
        values = "enabled=false\n"
    else:
        validate_credentials(raw)
        path = credentials_path()
        path.parent.mkdir(mode=0o700)
        # Exclusive creation prevents accidentally overwriting an existing file.
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(raw)
        values = f"enabled=true\ncredentials_path={path}\n"
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
        handle.write(values)


def cleanup():
    path = credentials_path()
    path.unlink(missing_ok=True)
    if path.parent.exists():
        path.parent.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("configure", "cleanup"))
    args = parser.parse_args()
    try:
        if args.command == "configure":
            configure()
        else:
            cleanup()
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, KeyError):
        print("Cannot prepare or clean Google Play credentials; check runner temporary storage and Actions outputs.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
