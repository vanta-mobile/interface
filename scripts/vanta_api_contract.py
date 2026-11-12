"""Pin the Vanta API OpenAPI contract that the app's data layer is written against.

The app depends only on `docs/openapi.yaml` from vanta-mobile/vanta-api, never on the
backend source. The vendored copy keeps builds and tests offline and reproducible; the
lock records the exact upstream commit and content hash.

  python3 scripts/vanta_api_contract.py check          # verify the vendored copy (offline)
  python3 scripts/vanta_api_contract.py sync [--ref R] # fetch R (default main) with `gh`
"""

import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
CONTRACT_DIR = ROOT / "docs" / "contracts" / "vanta-api"
SPEC = CONTRACT_DIR / "openapi.yaml"
LOCK = CONTRACT_DIR / "contract.lock.json"
REPOSITORY = "vanta-mobile/vanta-api"
UPSTREAM_PATH = "docs/openapi.yaml"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def check(spec=SPEC, lock=LOCK):
    values = json.loads(lock.read_text(encoding="utf-8"))
    if values.get("repository") != REPOSITORY or values.get("path") != UPSTREAM_PATH:
        raise ValueError("Contract lock names an unexpected source.")
    if not re.fullmatch(r"[0-9a-f]{40}", values.get("commit", "")):
        raise ValueError("Contract lock must pin a full commit SHA.")
    if digest(spec.read_bytes()) != values.get("sha256"):
        raise ValueError("Vendored openapi.yaml does not match contract.lock.json; "
                         "run `python3 scripts/vanta_api_contract.py sync`.")
    return values


def _gh(*arguments):
    result = subprocess.run(["gh", "api", *arguments], check=True, capture_output=True, text=True)
    return result.stdout.strip()


def sync(ref="main", fetch=_gh, spec=SPEC, lock=LOCK):
    commit = fetch(f"repos/{REPOSITORY}/commits/{ref}", "--jq", ".sha")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("GitHub did not return a commit SHA.")
    content = fetch(f"repos/{REPOSITORY}/contents/{UPSTREAM_PATH}?ref={commit}", "--jq", ".content")
    data = base64.b64decode(content)
    if not data.lstrip().startswith(b"---") and b"openapi:" not in data[:200]:
        raise ValueError("Fetched file is not an OpenAPI document.")
    spec.write_bytes(data)
    lock.write_text(json.dumps({
        "repository": REPOSITORY,
        "path": UPSTREAM_PATH,
        "commit": commit,
        "sha256": digest(data),
    }, indent=2) + "\n", encoding="utf-8")
    return commit


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check")
    pull = commands.add_parser("sync")
    pull.add_argument("--ref", default="main")
    arguments = parser.parse_args()
    try:
        if arguments.command == "check":
            print(f"Vanta API contract pinned at {check()['commit'][:12]}.")
        else:
            print(f"Vendored Vanta API contract from {sync(arguments.ref)[:12]}; "
                  "run the contract tests before committing.")
    except subprocess.CalledProcessError:
        raise SystemExit("`gh api` failed; authenticate with an account that can read "
                         f"{REPOSITORY}.") from None
    except (OSError, ValueError) as error:
        raise SystemExit(str(error)) from None
