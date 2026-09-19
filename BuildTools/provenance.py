#!/usr/bin/env python3
"""Offline, metadata-only candidate build/packaging/verification. Standard library only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile


CONFIGURATIONS = {"Development": "development", "Staging": "staging",
                  "Demo": "development", "Production": "production"}
RESOURCE = "KairoBuildProvenance.plist"
FIELDS = {"KAIROBuildGitSHA", "KAIROBuildVersion", "KAIROBuildNumber",
          "KAIROBuildEnvironment", "KAIROBuildConfiguration", "KAIROBuildSourceClean"}
DISABLED = {"KAIROProvenanceMode": "developer-unattested"}


class ProvenanceError(Exception):
    """Only static, non-sensitive failure codes reach command output."""


def require(condition, code):
    if not condition:
        raise ProvenanceError(code)


def run(args, cwd=None):
    try:
        result = subprocess.run(args, cwd=cwd, capture_output=True, check=False)
    except OSError:
        raise ProvenanceError("required_tool_unavailable") from None
    require(result.returncode == 0, "tool_failed")
    return result.stdout.decode("utf-8", errors="strict").strip()


def git(root, *args):
    # --no-optional-locks avoids refreshing any worktree index during audits.
    return run(["git", "--no-optional-locks", "-C", str(root), *args])


def source_state(root):
    require(not any(os.environ.get(key) for key in
                    ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR",
                     "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_CONFIG_COUNT")),
            "external_git_override_not_supported")
    root = Path(root).resolve()
    require(Path(git(root, "rev-parse", "--show-toplevel")).resolve() == root,
            "not_repository_root")
    sha = git(root, "rev-parse", "--verify", "HEAD^{commit}")
    require(re.fullmatch(r"[0-9a-f]{40}", sha) is not None, "invalid_git_sha")
    require(not git(root, "status", "--porcelain=v1", "--untracked-files=all"),
            "source_not_clean")
    # Ignored files under compiler/resource input roots are also ambiguous inputs.
    ignored = git(root, "ls-files", "--others", "--ignored", "--exclude-standard", "--",
                  "Kairo", "KairoTests", "KairoUITests", "Kairo.xcodeproj", "BuildTools")
    require(not ignored, "ignored_build_inputs")
    # Gitlinks need their own recursive attestations; do not silently accept them.
    indexed = git(root, "ls-files", "--stage").splitlines()
    require(not any(line.startswith("160000 ") for line in indexed), "submodule_not_supported")
    require(not any(line.startswith("120000 ") for line in indexed), "source_symlink_not_supported")
    return sha


def validate(data):
    require(isinstance(data, dict) and set(data) == FIELDS, "invalid_provenance_fields")
    require(type(data["KAIROBuildSourceClean"]) is bool and data["KAIROBuildSourceClean"],
            "source_not_clean")
    for key in FIELDS - {"KAIROBuildSourceClean"}:
        require(type(data[key]) is str, "invalid_provenance_type")
    require(re.fullmatch(r"[0-9a-f]{40}", data["KAIROBuildGitSHA"]) is not None,
            "invalid_git_sha")
    for key in ("KAIROBuildVersion", "KAIROBuildNumber"):
        require(re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", data[key]) is not None,
                "invalid_numeric_version")
    require(CONFIGURATIONS.get(data["KAIROBuildConfiguration"]) == data["KAIROBuildEnvironment"],
            "configuration_environment_mismatch")
    return data


def load(path):
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), "metadata_missing_or_symlink")
    try:
        with path.open("rb") as handle:
            return plistlib.load(handle)
    except (ValueError, plistlib.InvalidFileException, OSError):
        raise ProvenanceError("malformed_metadata") from None


def atomic_plist(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    # Unique temporary file is in the declared output's parent, never the source tree.
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".provenance-", delete=False) as handle:
        temporary = Path(handle.name)
        plistlib.dump(data, handle, sort_keys=True)
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def generate(sha, settings, configuration):
    require(settings.get("CONFIGURATION") == configuration, "resolved_configuration_mismatch")
    require(settings.get("KAIRO_BUILD_CONFIGURATION") == configuration, "embedded_configuration_mismatch")
    return validate({
        "KAIROBuildGitSHA": sha,
        "KAIROBuildVersion": settings.get("MARKETING_VERSION"),
        "KAIROBuildNumber": settings.get("CURRENT_PROJECT_VERSION"),
        "KAIROBuildEnvironment": settings.get("KAIRO_APP_ENVIRONMENT_NAME"),
        "KAIROBuildConfiguration": configuration,
        "KAIROBuildSourceClean": True,
    })


def package(environment):
    required = environment.get("KAIRO_PROVENANCE_REQUIRED", "NO")
    require(required in ("YES", "NO"), "invalid_provenance_mode")
    output = Path(environment["SCRIPT_OUTPUT_FILE_0"])
    # Invalidate any previously stamped output BEFORE parsing current input.
    require(output.name == RESOURCE and not output.is_symlink(), "invalid_output")
    output.unlink(missing_ok=True)
    data = load(environment["SCRIPT_INPUT_FILE_0"])
    if required == "NO":
        require(environment.get("ACTION") != "install", "archive_requires_provenance")
        require(data == DISABLED, "developer_input_not_disabled")
        return "developer_unattested"
    data = validate(data)
    require(data["KAIROBuildGitSHA"] == environment.get("KAIRO_PROVENANCE_EXPECTED_SHA"),
            "stale_git_sha")
    current = generate(data["KAIROBuildGitSHA"], environment, environment["CONFIGURATION"])
    require(current == data, "resolved_metadata_mismatch")
    # Only this exact output is writable in the sandbox; no undeclared temp file.
    with output.open("wb") as handle:
        plistlib.dump(data, handle, sort_keys=True)
    return "candidate_packaged"


def app_path(artifact):
    artifact = Path(artifact).resolve()
    if artifact.suffix == ".xcarchive":
        apps = list((artifact / "Products" / "Applications").glob("*.app"))
        require(len(apps) == 1, "archive_app_ambiguous")
        artifact = apps[0]
    require(artifact.is_dir() and artifact.suffix == ".app", "app_missing")
    return artifact


def verify(artifact, expected_sha, configuration, signed=False):
    app = app_path(artifact)
    data = validate(load(app / RESOURCE))
    require(data["KAIROBuildGitSHA"] == expected_sha, "artifact_sha_mismatch")
    require(data["KAIROBuildConfiguration"] == configuration, "artifact_configuration_mismatch")
    info = load(app / "Info.plist")
    mapping = {"KAIROBuildVersion": "CFBundleShortVersionString",
               "KAIROBuildNumber": "CFBundleVersion",
               "KAIROBuildEnvironment": "KAIROAppEnvironment",
               "KAIROBuildConfiguration": "KAIROBuildConfiguration"}
    for provenance_key, info_key in mapping.items():
        require(data[provenance_key] == info.get(info_key), "bundle_metadata_mismatch")
    require(info.get("KAIRODemoMode") == ("YES" if configuration == "Demo" else "NO"),
            "bundle_demo_mismatch")
    if signed:
        require((app / "_CodeSignature" / "CodeResources").is_file(), "signature_missing")
        run(["/usr/bin/codesign", "--verify", "--strict", str(app)])
        details = subprocess.run(["/usr/bin/codesign", "-d", "--verbose=4", str(app)],
                                 capture_output=True, check=False)
        require(details.returncode == 0 and b"Signature=adhoc" not in details.stderr
                and b"TeamIdentifier=" in details.stderr
                and b"TeamIdentifier=not set" not in details.stderr, "device_signature_required")
        seal = load(app / "_CodeSignature" / "CodeResources")
        entry = seal.get("files2", {}).get(RESOURCE, {})
        require(isinstance(entry, dict) and entry.get("hash2") ==
                hashlib.sha256((app / RESOURCE).read_bytes()).digest(), "provenance_not_sealed")
    return data


def tree_digest(app):
    """Deterministic path+content SHA256; explicitly NOT an IPA/file checksum."""
    digest = hashlib.sha256()
    for path in sorted(Path(app).rglob("*")):
        require(not path.is_symlink(), "artifact_symlink_not_supported")
        if path.is_file():
            relative = path.relative_to(app).as_posix().encode()
            digest.update(len(relative).to_bytes(8, "big"))
            digest.update(relative)
            digest.update(path.stat().st_size.to_bytes(8, "big"))
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
    return digest.hexdigest()


def checked_output(path, root):
    root = Path(root).resolve()
    path = Path(path).resolve()
    require(path != root and root not in path.parents, "output_inside_source")
    require(not path.exists(), "output_must_be_new")
    path.mkdir(parents=True, mode=0o700)
    return path


def build(args):
    require(not os.environ.get("XCODE_XCCONFIG_FILE"), "external_build_settings_not_supported")
    root = Path(__file__).resolve().parent.parent
    sha = source_state(root)
    output = checked_output(args.output, root)
    require(not (args.action == "archive" and args.sdk != "iphoneos"), "archive_requires_device_sdk")
    require(not (args.team and args.sdk != "iphoneos"), "team_requires_device_sdk")
    # Signing is opt-in. No automatic provisioning updates or account credentials.
    overrides = []
    for key, value in (("MARKETING_VERSION", args.version), ("CURRENT_PROJECT_VERSION", args.build_number)):
        if value is not None:
            require(re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", value) is not None, "invalid_numeric_version")
            overrides.append(key + "=" + value)
    if args.team:
        require(re.fullmatch(r"[A-Z0-9]{10}", args.team) is not None, "invalid_team")
        overrides.append("DEVELOPMENT_TEAM=" + args.team)
    else:
        overrides.append("CODE_SIGNING_ALLOWED=NO")
    base = ["xcodebuild", "-project", str(root / "Kairo.xcodeproj"), "-scheme", "Kairo",
            "-configuration", args.configuration, "-sdk", args.sdk,
            "-destination", "generic/platform=" + ("iOS" if args.sdk == "iphoneos" else "iOS Simulator"),
            "-derivedDataPath", str(output / "DerivedData")]
    resolved = json.loads(run(base + overrides + ["-showBuildSettings", "-json"], cwd=root))
    targets = [item["buildSettings"] for item in resolved if item.get("target") == "Kairo"]
    require(len(targets) == 1, "app_settings_ambiguous")
    data = generate(sha, targets[0], args.configuration)
    require(source_state(root) == sha, "source_changed_during_preparation")
    input_path = output / "Input" / RESOURCE
    atomic_plist(input_path, data)
    candidate_settings = ["KAIRO_PROVENANCE_REQUIRED=YES", "KAIRO_PROVENANCE_INPUT=" + str(input_path),
                          "KAIRO_PROVENANCE_EXPECTED_SHA=" + sha]
    archive = output / "KairoID.xcarchive"
    command = base + overrides + candidate_settings + [args.action]
    if args.action == "archive":
        command += ["-archivePath", str(archive)]
    with (output / "xcodebuild.log").open("wb") as log:
        result = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=False)
    require(result.returncode == 0, "xcode_build_failed")
    require(source_state(root) == sha, "source_changed_during_build")
    artifact = archive if args.action == "archive" else Path(targets[0]["TARGET_BUILD_DIR"]) / targets[0]["FULL_PRODUCT_NAME"]
    require(verify(artifact, sha, args.configuration, signed=bool(args.team)) == data,
            "artifact_does_not_match_generated_input")
    xcode = run(["xcodebuild", "-version"]).splitlines()
    require(len(xcode) == 2 and re.fullmatch(r"Xcode [0-9.]+", xcode[0]) and
            re.fullmatch(r"Build version [A-Za-z0-9]+", xcode[1]), "unexpected_toolchain_version")
    app = app_path(artifact)
    record = {"app": "KairoID", "platform": "iOS", "gitSHA": sha,
              "version": data["KAIROBuildVersion"], "buildNumber": data["KAIROBuildNumber"],
              "environment": data["KAIROBuildEnvironment"], "configuration": args.configuration,
              "sourceClean": True, "xcodeVersion": " / ".join(xcode),
              "artifact": artifact.name, "appBundleTreeSHA256": tree_digest(app),
              "digestAlgorithm": "sha256-length-prefixed-relative-path-size-content-v1",
              "signatureVerified": bool(args.team)}
    name = "KairoID-iOS-{}-{}-{}-{}.json".format(record["environment"], record["version"],
                                               record["buildNumber"], sha[:12])
    (output / name).write_text(json.dumps(record, sort_keys=True, indent=2) + "\n")
    print(json.dumps({"candidate_verified": True, "gitSHA": sha,
                      "signature_verified": bool(args.team), "sidecar": name}, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("package", help="Xcode phase only; reads declared environment inputs")
    command = commands.add_parser("build", help="Strict clean-source controlled candidate build")
    command.add_argument("--configuration", choices=CONFIGURATIONS, required=True)
    command.add_argument("--sdk", choices=("iphoneos", "iphonesimulator"), required=True)
    command.add_argument("--action", choices=("build", "archive"), default="build")
    command.add_argument("--output", required=True, help="New output directory outside source")
    command.add_argument("--version")
    command.add_argument("--build-number")
    command.add_argument("--team", help="Opt-in existing signing team; no provisioning updates")
    command = commands.add_parser("verify", help="Inspect .app or .xcarchive without modifying it")
    command.add_argument("artifact")
    command.add_argument("--expected-sha", required=True)
    command.add_argument("--configuration", choices=CONFIGURATIONS, required=True)
    command.add_argument("--require-signed", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "package":
            print("provenance=" + package(os.environ))
        elif args.command == "verify":
            data = verify(args.artifact, args.expected_sha, args.configuration, args.require_signed)
            print(json.dumps({"verified": True, **data}, sort_keys=True))
        else:
            build(args)
    except ProvenanceError as error:
        print(json.dumps({"success": False, "failure": str(error)}), file=sys.stderr)
        return 1
    except Exception:
        # Never leak subprocess output, paths, environment or signing diagnostics.
        print(json.dumps({"success": False, "failure": "unexpected_provenance_failure"}), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
