"""Validate a local Flutter dotenv file without executing it or printing values."""

from pathlib import Path
import re
import shlex
import sys

from ci_config import configuration


PUBLIC_KEYS = {"PRIVY_APP_ID", "PRIVY_CLIENT_ID", "REOWN_PROJECT_ID", "WALLET_LOGIN_ORIGIN"}


def check_environment(path):
    values = {}
    for number, raw in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        key = key.strip()
        if not separator or not re.fullmatch(r"[A-Z][A-Z0-9_]*", key):
            raise ValueError(f"Invalid KEY=value assignment on line {number}.")
        if key not in PUBLIC_KEYS:
            raise ValueError(f"Unsupported app configuration key on line {number}: {key}. "
                             "Keep signing credentials and API secrets outside the app dotenv file.")
        if key in values:
            raise ValueError(f"Duplicate app configuration key on line {number}: {key}.")
        try:
            tokens = shlex.split(value, comments=True, posix=True)
        except ValueError:
            raise ValueError(f"Invalid quoted value on line {number}.") from None
        if len(tokens) > 1:
            raise ValueError(f"Quote values containing spaces on line {number}.")
        values[key] = tokens[0] if tokens else ""
    return configuration(values)


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) == 2 else ".env"
    try:
        check_environment(path)
        print("App environment configuration is valid (values omitted).")
    except (OSError, UnicodeError, ValueError) as error:
        if isinstance(error, OSError):
            raise SystemExit("Cannot read environment file; copy .env.example to .env "
                             "or select an existing file with ENV_FILE=...") from None
        if isinstance(error, UnicodeError):
            raise SystemExit("The environment file must use UTF-8 encoding.") from None
        raise SystemExit(str(error)) from None
