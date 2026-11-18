"""Upload existing mobile symbols only; never build, upload source, or print secrets.

Requires a preinstalled sentry-cli. Release jobs install the pinned CLI through
the official npm package before invoking this helper.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def upload(platform, environment=os.environ):
    if platform not in ("android", "ios"):
        raise ValueError("Expected android or ios.")
    for key in ("SENTRY_AUTH_TOKEN", "SENTRY_ORG", "SENTRY_PROJECT"):
        if not environment.get(key, "").strip():
            raise ValueError(f"Missing {key} for Sentry symbol upload.")
    cli = shutil.which("sentry-cli")
    if not cli:
        raise ValueError("Install the pinned Sentry CLI before uploading symbols.")
    paths = (["build/symbols/android", "build/symbols/android-bundle"]
             if platform == "android" else
             ["build/symbols/ios", "build/ios/archive/Runner.xcarchive/dSYMs"])
    for path in paths:
        if not Path(path).is_dir() or not any(Path(path).rglob("*")):
            raise ValueError(f"Missing symbols: {path}")
    # No --include-sources: source code is deliberately excluded.
    subprocess.run([cli, "debug-files", "upload", "--wait", *paths],
                   env=dict(environment), check=True)
    for mapping, debug_file in symbol_map_pairs(platform):
        upload_symbol_map(cli, mapping, debug_file, environment)


def symbol_map_pairs(platform):
    """Each obfuscation map pairs with the Dart debug files of the same build."""
    if platform == "android":
        builds = [("build/obfuscation/android.json", "build/symbols/android", "app.android-*.symbols"),
                  ("build/obfuscation/android-bundle.json", "build/symbols/android-bundle", "app.android-*.symbols")]
    else:
        builds = [("build/obfuscation/ios.json", "build/ios/archive/Runner.xcarchive/dSYMs",
                   "App.framework.dSYM/Contents/Resources/DWARF/App")]
    pairs = []
    for mapping, root, pattern in builds:
        if not Path(mapping).is_file():
            raise ValueError(f"Missing obfuscation map: {mapping}")
        files = sorted(Path(root).glob(pattern))
        if not files:
            raise ValueError(f"Missing Dart debug files for {mapping}")
        pairs += [(mapping, str(file)) for file in files]
    return pairs


def upload_symbol_map(cli, mapping, debug_file, environment):
    """Lets Sentry restore obfuscated Dart exception type names.

    Sentry rejects maps whose content was already uploaded, so a leading
    marker pair carries the debug ID, as the official sentry_dart_plugin does.
    """
    check = subprocess.run([cli, "debug-files", "check", "--json", debug_file],
                           env=dict(environment), check=True, capture_output=True, text=True)
    debug_id = json.loads(check.stdout)["variants"][0]["debug_id"]
    pairs = json.loads(Path(mapping).read_text())
    marked = Path(f"{mapping}.{debug_id}.json")
    marked.write_text(json.dumps(["SENTRY_DEBUG_ID_MARKER", debug_id, *pairs]))
    try:
        subprocess.run([cli, "dart-symbol-map", "upload", str(marked), debug_file],
                       env=dict(environment), check=True)
    finally:
        marked.unlink()


if __name__ == "__main__":
    try:
        upload(sys.argv[1] if len(sys.argv) == 2 else "")
    except (ValueError, KeyError, IndexError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None
