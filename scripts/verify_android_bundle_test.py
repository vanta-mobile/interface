import io
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from verify_android_bundle import (
    verify_apk_set,
    verify_bundle,
    verify_bundle_alignment,
    verify_elf,
    verify_native_libraries,
)


def elf(alignments=(16384,), endian="<", offset=0, address=0):
    data = bytearray(64 + 56 * len(alignments))
    data[:7] = b"\x7fELF\x02" + (b"\x01" if endian == "<" else b"\x02") + b"\x01"
    struct.pack_into(endian + "Q", data, 32, 64)
    struct.pack_into(endian + "HH", data, 54, 56, len(alignments))
    for index, alignment in enumerate(alignments):
        struct.pack_into(
            endian + "IIQQQQQQ", data, 64 + 56 * index,
            1, 5, offset, address, 0, 0, 0, alignment,
        )
    return bytes(data)


def zipped(entries):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as archive:
        for name, data in entries.items():
            archive.writestr(name, data)
    return output.getvalue()


class ElfTests(unittest.TestCase):
    def test_accepts_16k_and_larger_segments_in_both_byte_orders(self):
        for endian in ("<", ">"):
            verify_elf(elf((16384, 65536), endian), "libflutter.so")

    def test_rejects_a_single_4k_segment_among_valid_segments(self):
        with self.assertRaisesRegex(ValueError, r"libvendor.so: PT_LOAD\[1\].*0x1000"):
            verify_elf(elf((16384, 4096, 16384)), "libvendor.so")

    def test_rejects_incongruent_segment_addresses(self):
        with self.assertRaisesRegex(ValueError, "offset/address"):
            verify_elf(elf(offset=0, address=4096), "libvendor.so")

    def test_rejects_invalid_or_truncated_elf(self):
        for data in (b"not ELF", elf()[:70], elf(()), elf((24576,))):
            with self.subTest(data=data[:7]), self.assertRaises(ValueError):
                verify_elf(data, "libvendor.so")

    def test_rejects_a_library_without_loadable_segments(self):
        data = bytearray(elf())
        struct.pack_into("<I", data, 64, 4)  # PT_NOTE instead of PT_LOAD
        with self.assertRaisesRegex(ValueError, "no PT_LOAD"):
            verify_elf(data, "libvendor.so")

    def test_checks_both_64bit_abis_and_feature_modules_but_skips_32bit(self):
        data = zipped({
            "base/lib/arm64-v8a/libflutter.so": elf(),
            "feature/lib/x86_64/libvendor.so": elf((4096,)),
            "base/lib/armeabi-v7a/libold.so": b"32-bit library",
        })
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            with self.assertRaisesRegex(ValueError, "feature/lib/x86_64/libvendor.so"):
                verify_native_libraries(archive, "app.aab")


class BundleTests(unittest.TestCase):
    def test_requires_explicit_16k_packaging(self):
        config = {"optimizations": {"uncompressNativeLibraries": {
            "alignment": "PAGE_ALIGNMENT_4K",
        }}}
        for invalid in ({}, config):
            with self.assertRaisesRegex(ValueError, "PAGE_ALIGNMENT_16K"):
                verify_bundle_alignment(invalid)
        config["optimizations"]["uncompressNativeLibraries"]["alignment"] = "PAGE_ALIGNMENT_16K"
        verify_bundle_alignment(config)

    def test_bundletool_validation_failure_stops_verification(self):
        with patch(
            "verify_android_bundle.subprocess.run",
            side_effect=subprocess.CalledProcessError(1, "validate"),
        ) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                verify_bundle(Path("app.aab"), Path("tool.jar"), Path("zipalign"))
            self.assertEqual(run.call_count, 1)

    def test_checks_actual_native_apks_and_does_not_extract_archive_paths(self):
        apk = zipped({"lib/arm64-v8a/libapp.so": elf()})
        resource_apk = zipped({"resources.arsc": b"resources"})
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            apk_set = directory / "release.apks"
            apk_set.write_bytes(zipped({
                "../../outside.apk": apk,
                "splits/resources.apk": resource_apk,
            }))
            with patch("verify_android_bundle.subprocess.run") as run:
                self.assertEqual(verify_apk_set(apk_set, Path("zipalign"), directory), (1, 1))
                command = run.call_args.args[0]
                self.assertEqual(command[:5], ["zipalign", "-c", "-P", "16", "4"])
                self.assertEqual(Path(command[5]).parent, directory)
            self.assertEqual(list(directory.iterdir()), [apk_set])

    def test_zip_alignment_failure_fails_the_gate(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            apk_set = directory / "release.apks"
            apk_set.write_bytes(zipped({
                "splits/arm64.apk": zipped({"lib/arm64-v8a/libapp.so": elf()}),
            }))
            with patch(
                "verify_android_bundle.subprocess.run",
                side_effect=subprocess.CalledProcessError(1, "zipalign"),
            ):
                with self.assertRaises(subprocess.CalledProcessError):
                    verify_apk_set(apk_set, Path("zipalign"), directory)

    def test_rejects_an_unaligned_library_in_a_generated_apk(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            apk_set = directory / "release.apks"
            apk_set.write_bytes(zipped({
                "splits/x86.apk": zipped({"lib/x86_64/libvendor.so": elf((4096,))}),
            }))
            with self.assertRaisesRegex(ValueError, "splits/x86.apk!lib/x86_64/libvendor.so"):
                verify_apk_set(apk_set, Path("zipalign"), directory)

    def test_empty_or_32bit_only_apk_sets_cannot_pass(self):
        for entries in ({}, {"splits/arm.apk": zipped({"lib/armeabi-v7a/libold.so": b"32-bit"})}):
            with self.subTest(entries=entries), tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                apk_set = directory / "release.apks"
                apk_set.write_bytes(zipped(entries))
                with self.assertRaisesRegex(ValueError, "no 64-bit"):
                    verify_apk_set(apk_set, Path("zipalign"), directory)


if __name__ == "__main__":
    unittest.main()
