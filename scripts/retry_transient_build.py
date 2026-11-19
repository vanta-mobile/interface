"""Rerun a build only when it failed on a transient dependency download.

Maven Central rate-limits shared CI runner addresses (HTTP 429), which aborts
Gradle configuration before any code compiles. Compile errors and other
failures are returned immediately so they are never masked or retried.

Usage: python3 scripts/retry_transient_build.py <command> [args...]
"""

import re
import subprocess
import sys
import time

ATTEMPTS = 3
BACKOFF_SECONDS = (60, 180)
TRANSIENT = re.compile(
    r"Received status code (429|5\d\d) from server|(Connect|Read) timed out|Connection reset")


def is_transient(output):
    return bool(TRANSIENT.search(output))


def run(command, attempts=ATTEMPTS, sleep=time.sleep):
    for attempt in range(1, attempts + 1):
        lines = []
        with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, errors="replace") as process:
            for line in process.stdout:
                sys.stdout.write(line)
                lines.append(line)
            code = process.wait()
        if code == 0 or attempt == attempts or not is_transient("".join(lines)):
            return code
        delay = BACKOFF_SECONDS[min(attempt - 1, len(BACKOFF_SECONDS) - 1)]
        print(f"::warning::Transient dependency download failure; retrying in {delay}s "
              f"(attempt {attempt + 1}/{attempts}).", flush=True)
        sleep(delay)
    return code


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Expected a command to run.")
    sys.exit(run(sys.argv[1:]))
