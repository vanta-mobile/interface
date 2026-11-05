"""Validate a Flutter AAB and the 16 KB compatibility of its generated APKs.

Uses Python's standard library, bundletool, and Android Build Tools.
The generated APKs are only inspected and are never published. The release
bundle's signing certificate is checked separately by the workflow.
"""

import argparse
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile


PAGE_SIZE = 16384
NATIVE_LIBRARY = re.compile(r"(?:^|/)lib/(arm64-v8a|x86_64)/[^/]+\.so$")


def verify_elf(data, name):
    """Check every PT_LOAD segment, including offset/address congruence."""
    if len(data) < 64 or data[:5] != b"\x7fELF\x02" or data[5] not in (1, 2):
        raise ValueError(f"{name}: expected a 64-bit ELF shared library")
    endian = "<" if data[5] == 1 else ">"
    offset = struct.unpack_from(endian + "Q", data, 32)[0]
    entry_size, count = struct.unpack_from(endian + "HH", data, 54)
    if not count or entry_size < 56 or offset + entry_size * count > len(data):
        raise ValueError(f"{name}: invalid ELF program header table")
    loads = 0
    for index in range(count):
        fields = struct.unpack_from(endian + "IIQQQQQQ", data, offset + index * entry_size)
        kind, _, file_offset, address, _, _, _, alignment = fields
        if kind != 1:  # PT_LOAD
            continue
        loads += 1
        if alignment < PAGE_SIZE or alignment & (alignment - 1):
            raise ValueError(
                f"{name}: PT_LOAD[{index}] alignment {alignment:#x} does not support 16 KB pages"
            )
        if file_offset % PAGE_SIZE != address % PAGE_SIZE:
            raise ValueError(f"{name}: PT_LOAD[{index}] offset/address are not 16 KB congruent")
    if not loads:
        raise ValueError(f"{name}: ELF has no PT_LOAD segments")


def verify_native_libraries(archive, label):
    names = [name for name in archive.namelist() if NATIVE_LIBRARY.search(name)]
    for name in names:
        verify_elf(archive.read(name), f"{label}!{name}")
    return len(names)


def verify_bundle_alignment(config):
    settings = config.get("optimizations", {}).get("uncompressNativeLibraries", {})
    if settings.get("alignment") != "PAGE_ALIGNMENT_16K":
        raise ValueError("AAB must request PAGE_ALIGNMENT_16K for native library packaging")


def verify_apk_set(apk_set, zipalign, directory):
    apk_count = library_count = 0
    with zipfile.ZipFile(apk_set) as archive:
        for index, name in enumerate(archive.namelist()):
            if not name.endswith(".apk"):
                continue
            # Use our own file names rather than extracting archive paths.
            apk = directory / f"split-{index}.apk"
            try:
                with archive.open(name) as source, apk.open("wb") as destination:
                    shutil.copyfileobj(source, destination)
                with zipfile.ZipFile(apk) as split:
                    count = verify_native_libraries(split, name)
                if count:
                    print(f"Checking 16 KB ZIP alignment: {name}", flush=True)
                    subprocess.run([str(zipalign), "-c", "-P", "16", "4", str(apk)], check=True)
                    apk_count += 1
                    library_count += count
            finally:
                apk.unlink(missing_ok=True)
    if not library_count:
        raise ValueError("Generated APK set contains no 64-bit native libraries")
    return apk_count, library_count


def verify_bundle(bundle, bundletool, zipalign):
    tool = ["java", "-jar", str(bundletool)]
    subprocess.run([*tool, "validate", f"--bundle={bundle}"], check=True, stdout=subprocess.PIPE)
    print("AAB structure: validated by bundletool", flush=True)
    result = subprocess.run(
        [*tool, "dump", "config", f"--bundle={bundle}"],
        check=True, capture_output=True, text=True,
    )
    verify_bundle_alignment(json.loads(result.stdout))
    with zipfile.ZipFile(bundle) as archive:
        count = verify_native_libraries(archive, bundle.name)
    if not count:
        raise ValueError("AAB contains no 64-bit native libraries")
    print(
        f"AAB: {count} native libraries passed ELF checks; PAGE_ALIGNMENT_16K enabled",
        flush=True,
    )
    with tempfile.TemporaryDirectory(prefix="vanta-bundle-check-") as temporary:
        directory = Path(temporary)
        apk_set = directory / "release.apks"
        subprocess.run(
            [
                *tool, "build-apks", f"--bundle={bundle}", f"--output={apk_set}",
                "--mode=default", "--max-threads=2",
                f"--aapt2={zipalign.with_name('aapt2')}",
            ],
            check=True,
        )
        apks, libraries = verify_apk_set(apk_set, zipalign, directory)
    print(
        f"Generated APKs: {libraries} native libraries in {apks} APKs "
        "passed ELF and zipalign checks"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--bundletool", required=True, type=Path)
    parser.add_argument("--zipalign", required=True, type=Path)
    args = parser.parse_args()
    try:
        verify_bundle(args.bundle.resolve(), args.bundletool.resolve(), args.zipalign.resolve())
    except (ValueError, OSError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print(f"Android bundle verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
