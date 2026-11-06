#!/usr/bin/env python3
"""Prepare temporary Apple signing credentials and verify release artifacts."""

import argparse
import base64
import binascii
from datetime import datetime, timezone
import hashlib
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
from uuid import UUID
import zipfile


BUNDLE_ID = "exchange.vanta.app"
TESTFLIGHT_SECRETS = (
    "APP_STORE_CONNECT_KEY_ID",
    "APP_STORE_CONNECT_ISSUER_ID",
    "APP_STORE_CONNECT_PRIVATE_KEY_BASE64",
)


class ReleaseError(Exception):
    pass


def require_environment(names):
    missing = [name for name in names if not os.environ.get(name, "").strip()]
    if missing:
        raise ReleaseError("Missing GitHub Actions configuration: " + ", ".join(missing))


def decode_secret(name):
    try:
        value = base64.b64decode("".join(os.environ[name].split()), validate=True)
    except (ValueError, binascii.Error):
        raise ReleaseError(f"{name} must contain valid base64.") from None
    if not value:
        raise ReleaseError(f"{name} must not be empty.")
    return value


def write_private(path, data):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.write_bytes(data)
    path.chmod(0o600)


def run(command, *, stdin=None):
    # Do not include command arguments in exceptions: security receives passwords.
    try:
        result = subprocess.run(command, input=stdin, capture_output=True, check=False)
    except FileNotFoundError:
        raise ReleaseError(f"Required Apple tool not found: {command[0]}") from None
    if result.returncode:
        reason = result.stderr.decode(errors="replace").strip()
        raise ReleaseError(f"{command[0]} {command[1]} failed: {reason}")
    return result.stdout


def normalize_pkcs12(certificate_path):
    # macOS Keychain can reject OpenSSL 3's default AES/SHA-256 PKCS#12
    # encoding with the same error as a wrong password. Verify the supplied
    # password with OpenSSL, then re-encode for Keychain using 3DES/SHA-1.
    # Private PEM material stays in a captured pipe, never on disk or in logs.
    password_source = "env:IOS_DISTRIBUTION_CERTIFICATE_PASSWORD"
    try:
        key_material = run([
            "openssl", "pkcs12", "-legacy", "-in", str(certificate_path),
            "-passin", password_source, "-nocerts", "-noenc",
        ])
        certificates = run([
            "openssl", "pkcs12", "-legacy", "-in", str(certificate_path),
            "-passin", password_source, "-nokeys",
        ])
    except ReleaseError as error:
        raise ReleaseError(
            "Cannot decode IOS_DISTRIBUTION_CERTIFICATE_BASE64 using "
            "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD. Check the complete .p12 "
            f"and its Export Password (not the PEM pass phrase). {error}"
        ) from None
    # PKCS#12 export reads the key and certificates independently; supply the
    # public chain as a file so only the private key needs the stdin pipe.
    chain_path = certificate_path.with_suffix(".certificates.pem")
    try:
        write_private(chain_path, certificates)
        normalized = run([
            "openssl", "pkcs12", "-export", "-inkey", "/dev/stdin",
            "-in", str(chain_path), "-passout", password_source,
            "-keypbe", "PBE-SHA1-3DES", "-certpbe", "PBE-SHA1-3DES",
            "-macalg", "sha1",
        ], stdin=key_material)
    finally:
        chain_path.unlink(missing_ok=True)
    write_private(certificate_path, normalized)


def output(name, value):
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
        handle.write(f"{name}={value}\n")


def validate_capabilities(entitlements, team_id):
    if entitlements.get("com.apple.developer.team-identifier") != team_id:
        raise ReleaseError("The signing entitlements do not match APPLE_TEAM_ID.")
    if entitlements.get("get-task-allow", False):
        raise ReleaseError("App Store signing cannot enable get-task-allow.")


def validate_profile(profile, team_id, identities, now=None):
    now = now or datetime.now(timezone.utc).replace(tzinfo=None)
    expiration = profile.get("ExpirationDate")
    if not isinstance(expiration, datetime) or expiration <= now:
        raise ReleaseError("The provisioning profile has expired or has no expiration date.")
    if "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices"):
        raise ReleaseError("Use an App Store Connect distribution profile, not development, Ad Hoc, or enterprise.")
    if team_id not in profile.get("TeamIdentifier", []):
        raise ReleaseError("The provisioning profile does not match APPLE_TEAM_ID.")
    entitlements = profile.get("Entitlements", {})
    prefix, separator, bundle_id = entitlements.get("application-identifier", "").partition(".")
    if not separator or bundle_id != BUNDLE_ID or prefix not in profile.get("ApplicationIdentifierPrefix", []):
        raise ReleaseError(f"The provisioning profile must explicitly authorize {BUNDLE_ID}.")
    validate_capabilities(entitlements, team_id)
    try:
        profile_uuid = profile["UUID"]
        # Validate without rewriting: Xcode matches the profile's original
        # identifier, including its case, against the signing specifier.
        if not isinstance(profile_uuid, str) or not re.fullmatch(
            r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", profile_uuid
        ):
            raise ValueError("Invalid profile UUID")
        UUID(profile_uuid)
    except (KeyError, ValueError, TypeError, AttributeError):
        raise ReleaseError("The provisioning profile has an invalid UUID.") from None
    certificates = {
        hashlib.sha1(certificate).hexdigest().upper()
        for certificate in profile.get("DeveloperCertificates", [])
    }
    matching = certificates.intersection(identities)
    if not matching:
        raise ReleaseError("The profile does not contain a valid signing identity from the .p12; include its private key and matching distribution certificate.")
    return profile_uuid, sorted(matching)[0]


def export_options(team_id, profile_uuid, identity):
    return {
        "method": "app-store-connect",
        "destination": "export",
        "signingStyle": "manual",
        "teamID": team_id,
        "signingCertificate": identity,
        "provisioningProfiles": {BUNDLE_ID: profile_uuid},
        "manageAppVersionAndBuildNumber": False,
    }


def prepare_signing(directory):
    require_environment([
        "APPLE_TEAM_ID", "IOS_DISTRIBUTION_CERTIFICATE_BASE64",
        "IOS_DISTRIBUTION_CERTIFICATE_PASSWORD", "IOS_PROVISIONING_PROFILE_BASE64",
    ])
    team_id = os.environ["APPLE_TEAM_ID"].strip()
    if not re.fullmatch(r"[A-Z0-9]{10}", team_id):
        raise ReleaseError("APPLE_TEAM_ID must contain 10 uppercase letters/digits.")
    certificate_path = directory / "distribution.p12"
    profile_path = directory / "distribution.mobileprovision"
    keychain_path = directory / "signing.keychain-db"
    write_private(certificate_path, decode_secret("IOS_DISTRIBUTION_CERTIFICATE_BASE64"))
    write_private(profile_path, decode_secret("IOS_PROVISIONING_PROFILE_BASE64"))
    normalize_pkcs12(certificate_path)
    original = run(["security", "list-keychains", "-d", "user"])
    write_private(directory / "original-keychains.txt", original)
    keychain_password = secrets.token_hex(32)
    run(["security", "create-keychain", "-p", keychain_password, str(keychain_path)])
    run(["security", "set-keychain-settings", "-lut", "21600", str(keychain_path)])
    run(["security", "unlock-keychain", "-p", keychain_password, str(keychain_path)])
    run(["security", "import", str(certificate_path), "-P",
         os.environ["IOS_DISTRIBUTION_CERTIFICATE_PASSWORD"], "-T", "/usr/bin/codesign",
         "-T", "/usr/bin/security", "-k", str(keychain_path)])
    run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
         "-s", "-k", keychain_password, str(keychain_path)])
    run(["security", "list-keychains", "-d", "user", "-s", str(keychain_path),
         *shlex.split(original.decode())])
    profile = plistlib.loads(run(["security", "cms", "-D", "-i", str(profile_path)]))
    identity_text = run(["security", "find-identity", "-v", "-p", "codesigning", str(keychain_path)]).decode()
    identities = {value.upper() for value in re.findall(r"^\s*\d+\)\s+([0-9A-Fa-f]{40})\b", identity_text, re.MULTILINE)}
    profile_uuid, identity = validate_profile(profile, team_id, identities)
    installed_profile = Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles" / f"{profile_uuid}.mobileprovision"
    write_private(installed_profile, profile_path.read_bytes())
    write_private(directory / "installed-profile-path.txt", str(installed_profile).encode())
    export_path = directory / "ExportOptions.plist"
    write_private(export_path, plistlib.dumps(export_options(team_id, profile_uuid, identity)))
    # Include this only in Runner's Release.xcconfig, so provisioning settings
    # are not applied globally to Swift package/resource bundle targets.
    signing_config = directory / "RunnerSigning.xcconfig"
    write_private(signing_config, (
        f"DEVELOPMENT_TEAM = {team_id}\n"
        "CODE_SIGN_STYLE = Manual\n"
        f"CODE_SIGN_IDENTITY = {identity}\n"
        f"PROVISIONING_PROFILE_SPECIFIER = {profile_uuid}\n"
    ).encode())
    for name, value in {"export_options": export_path, "signing_config": signing_config}.items():
        output(name, value)
    certificate_path.unlink()
    print(f"Prepared App Store Connect signing for {BUNDLE_ID}.")


def configure_testflight(directory):
    if not any(os.environ.get(name, "").strip() for name in TESTFLIGHT_SECRETS):
        output("enabled", "false")
        print("App Store Connect API Key is not configured; skipping TestFlight upload.")
        return
    require_environment(TESTFLIGHT_SECRETS)
    key_id = os.environ["APP_STORE_CONNECT_KEY_ID"]
    if not re.fullmatch(r"[A-Z0-9]{10}", key_id):
        raise ReleaseError("APP_STORE_CONNECT_KEY_ID must contain 10 uppercase letters/digits.")
    try:
        UUID(os.environ["APP_STORE_CONNECT_ISSUER_ID"])
    except ValueError:
        raise ReleaseError("APP_STORE_CONNECT_ISSUER_ID must be a UUID from a team API Key.") from None
    private_key = decode_secret("APP_STORE_CONNECT_PRIVATE_KEY_BASE64")
    if not private_key.strip().startswith(b"-----BEGIN PRIVATE KEY-----") or not private_key.strip().endswith(b"-----END PRIVATE KEY-----"):
        raise ReleaseError("APP_STORE_CONNECT_PRIVATE_KEY_BASE64 must encode the downloaded .p8 private key.")
    write_private(directory / "private_keys" / f"AuthKey_{key_id}.p8", private_key)
    output("enabled", "true")
    print("App Store Connect API Key configured; TestFlight upload is enabled.")


def verify_ipa(ipa_path, directory):
    require_environment(["APPLE_TEAM_ID"])
    with tempfile.TemporaryDirectory(prefix="verify-", dir=directory) as temporary:
        temporary = Path(temporary)
        with zipfile.ZipFile(ipa_path) as archive:
            for name in archive.namelist():
                path = PurePosixPath(name)
                if path.is_absolute() or ".." in path.parts:
                    raise ReleaseError("The exported IPA contains an unsafe archive path.")
        # ditto preserves executable permissions and framework symlinks.
        run(["ditto", "-x", "-k", str(ipa_path.resolve()), str(temporary)])
        apps = list((temporary / "Payload").glob("*.app"))
        if len(apps) != 1:
            raise ReleaseError("The exported IPA must contain exactly one application.")
        app = apps[0]
        info = plistlib.loads((app / "Info.plist").read_bytes())
        if info.get("CFBundleIdentifier") != BUNDLE_ID:
            raise ReleaseError("The exported IPA has the wrong Bundle ID.")
        run(["codesign", "--verify", "--deep", "--strict", str(app)])
        signed = plistlib.loads(run(["codesign", "--display", "--entitlements", ":-", str(app)]))
        team_id = os.environ["APPLE_TEAM_ID"].strip()
        validate_capabilities(signed, team_id)
        run(["codesign", "--display", f"--extract-certificates={temporary / 'certificate'}", str(app)])
        identity = hashlib.sha1((temporary / "certificate0").read_bytes()).hexdigest().upper()
        profile = plistlib.loads(run(["security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")]))
        validate_profile(profile, team_id, {identity})
        if signed.get("application-identifier") != profile["Entitlements"]["application-identifier"]:
            raise ReleaseError("The signed App ID does not match its embedded provisioning profile.")
    print("Verified Vanta IPA signature, Bundle ID, distribution profile, and signing identity.")


def cleanup(directory):
    # Hosted runners are ephemeral. Still restore their keychain list and remove
    # the imported signing material even if an earlier build/upload step failed.
    failures = []
    original = directory / "original-keychains.txt"
    keychain = directory / "signing.keychain-db"
    profile_marker = directory / "installed-profile-path.txt"
    for command in (
        ["security", "list-keychains", "-d", "user", "-s", *shlex.split(original.read_text())] if original.exists() else None,
        ["security", "delete-keychain", str(keychain)] if keychain.exists() else None,
    ):
        if command:
            try:
                run(command)
            except ReleaseError as error:
                failures.append(str(error))
    if profile_marker.exists():
        Path(profile_marker.read_text()).unlink(missing_ok=True)
    if directory.exists():
        shutil.rmtree(directory)
    if failures:
        raise ReleaseError("; ".join(failures))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare-signing", "configure-testflight", "verify-ipa", "cleanup"])
    parser.add_argument("--ipa", type=Path)
    args = parser.parse_args()
    try:
        require_environment(["RUNNER_TEMP"])
        directory = Path(os.environ["RUNNER_TEMP"]) / "vanta-ios-release"
        if args.command == "prepare-signing":
            prepare_signing(directory)
        elif args.command == "configure-testflight":
            configure_testflight(directory)
        elif args.command == "verify-ipa":
            if not args.ipa:
                raise ReleaseError("verify-ipa requires --ipa.")
            verify_ipa(args.ipa, directory)
        else:
            cleanup(directory)
    except (ReleaseError, OSError, ValueError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        print(f"iOS release configuration error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
