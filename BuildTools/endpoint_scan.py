#!/usr/bin/env python3
"""Read-only Production .app/.xcarchive/.ipa packaging gate; never prints contents."""
import argparse
import json
from pathlib import Path, PurePosixPath
import plistlib
import stat
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_API = "https://api.kairoid.com/api/v1"
# Host fragments also catch alternate paths, ports and schemes. Only the packaged
# app is scanned, not source/docs, dSYMs or other non-shipping archive metadata.
PROHIBITED = ("localhost", "127.0.0.1", "staging-api.kairoid.com",
              "d3kpvsn9kfajzc.cloudfront.net")
MOCK_TOKEN_LITERALS = ("demo-access-token", "demo-refresh-token",
                       "ui-test-access-token", "ui-test-refresh-token")
ENCODINGS = ("utf-8", "utf-16-le", "utf-16-be")
PLACES_RESOURCE_PREFIXES = (
    "GooglePlaces_GooglePlacesTarget.bundle/GooglePlaces.bundle/",
    "GooglePlaces_GooglePlacesSwiftTarget.bundle/GooglePlacesSwift.bundle/",
)


class EndpointError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise EndpointError(message)


def app_path(artifact):
    path = Path(artifact)
    require(not path.is_symlink(), "artifact_symlink_rejected")
    if path.suffix == ".xcarchive":
        apps = list((path / "Products/Applications").glob("*.app"))
        require(len(apps) == 1, "archive_app_ambiguous")
        path = apps[0]
    require(path.is_dir() and path.suffix == ".app", "app_missing")
    require(not path.is_symlink(), "app_symlink_rejected")
    return path


def scan(artifact, *, first_party_objects=None, third_party_archive=None, source_root=None):
    path = Path(artifact)
    require(not path.is_symlink(), "artifact_symlink_rejected")
    if path.suffix == ".ipa":
        try:
            with zipfile.ZipFile(path) as archive:
                entries = archive.infolist()
                names = [entry.filename for entry in entries]
                require(len(names) == len(set(names)), "duplicate_ipa_entry")
                for entry in entries:
                    parts = PurePosixPath(entry.filename).parts
                    require(parts and not entry.filename.startswith("/") and ".." not in parts
                            and "\\" not in entry.filename, "invalid_ipa_path")
                    require(not stat.S_ISLNK(entry.external_attr >> 16), "packaged_symlink_rejected")
                    require(not entry.flag_bits & 1, "encrypted_ipa_entry")
                roots = {tuple(PurePosixPath(name).parts[:2]) for name in names
                         if len(PurePosixPath(name).parts) >= 2
                         and PurePosixPath(name).parts[0] == "Payload"
                         and PurePosixPath(name).parts[1].endswith(".app")}
                require(len(roots) == 1, "ipa_app_ambiguous")
                prefix = "/".join(next(iter(roots))) + "/"
                files = {entry.filename[len(prefix):]: (lambda item=entry: archive.open(item))
                         for entry in entries if entry.filename.startswith(prefix) and not entry.is_dir()}
                return scan_files(files, first_party_objects=first_party_objects,
                                  third_party_archive=third_party_archive,
                                  source_root=source_root)
        except (zipfile.BadZipFile, RuntimeError):
            raise EndpointError("invalid_ipa") from None
    app = app_path(artifact)
    files = {}
    for path in sorted(app.rglob("*")):
        require(not path.is_symlink(), "packaged_symlink_rejected")
        require(path.is_file() or path.is_dir(), "unsupported_packaged_entry")
        if path.is_file():
            files[path.relative_to(app).as_posix()] = lambda item=path: item.open("rb")
    return scan_files(files, first_party_objects=first_party_objects,
                      third_party_archive=third_party_archive,
                      source_root=source_root)


def _patterns(values):
    return [(value, value.encode(encoding)) for value in values for encoding in ENCODINGS]


def _stream_findings(stream, patterns):
    overlap = max(len(pattern) for _, pattern in patterns) - 1
    tail = b""
    findings = set()
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        data = tail + chunk
        normalized = data.lower()
        for label, pattern in patterns:
            if pattern in normalized:
                findings.add(label)
        tail = data[-overlap:]
    return findings


def _verified_places_dependency(root):
    root = Path(root).resolve()
    project = (root / "Kairo.xcodeproj/project.pbxproj").read_text()
    resolved = json.loads((root / "Kairo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())
    pins = [pin for pin in resolved.get("pins", []) if pin.get("identity") == "ios-places-sdk"]
    return (len(pins) == 1
            and pins[0].get("location") == "https://github.com/googlemaps/ios-places-sdk"
            and pins[0].get("state", {}).get("version") == "11.2.0"
            and 'repositoryURL = "https://github.com/googlemaps/ios-places-sdk";' in project
            and 'requirement = {kind = exactVersion; version = 11.2.0; };' in project
            and "productName = GooglePlacesSwift;" in project)


def _verify_owner_split(first_party_objects, third_party_archive, source_root, patterns):
    require(first_party_objects is not None and third_party_archive is not None,
            "ownership_inputs_incomplete")
    require(source_root is not None and _verified_places_dependency(source_root),
            "third_party_ownership_unverified")
    objects = Path(first_party_objects)
    vendor = Path(third_party_archive)
    require(objects.is_dir() and not objects.is_symlink(), "first_party_objects_missing")
    require(vendor.is_file() and not vendor.is_symlink() and vendor.name == "GooglePlaces.a",
            "third_party_archive_invalid")

    object_files = []
    first_party_findings = set()
    for path in sorted(objects.rglob("*")):
        require(not path.is_symlink(), "first_party_object_symlink_rejected")
        if path.is_file() and path.suffix == ".o":
            object_files.append(path)
            with path.open("rb") as stream:
                first_party_findings.update(_stream_findings(stream, patterns))
    require(object_files, "first_party_objects_empty")
    require(not first_party_findings,
            "prohibited_first_party_object_material:" + json.dumps(sorted(first_party_findings)))

    with vendor.open("rb") as stream:
        vendor_findings = _stream_findings(stream, patterns)
    require(vendor_findings == {"localhost", "127.0.0.1"},
            "unexpected_third_party_endpoint_material:" + json.dumps(sorted(vendor_findings)))
    return len(object_files)


def scan_files(files, *, first_party_objects=None, third_party_archive=None, source_root=None):
    try:
        with files["Info.plist"]() as stream:
            info = plistlib.loads(stream.read())
    except (KeyError, OSError, ValueError, plistlib.InvalidFileException):
        raise EndpointError("invalid_info_plist") from None
    require(info.get("KAIROBuildConfiguration") == "Production", "configuration_not_production")
    require(info.get("KAIROAppEnvironment") == "production", "environment_not_production")
    require(info.get("KAIRODemoMode") == "NO", "demo_not_disabled")
    name = info.get("CFBundleExecutable")
    require(isinstance(name, str) and name not in ("", ".", "..")
            and Path(name).name == name, "invalid_executable_name")
    executable = name
    require(executable in files, "executable_missing")

    patterns = _patterns(PROHIBITED + MOCK_TOKEN_LITERALS)
    ownership_mode = any(value is not None for value in
                         (first_party_objects, third_party_archive, source_root))
    object_count = None
    if ownership_mode:
        object_count = _verify_owner_split(first_party_objects, third_party_archive,
                                           source_root, patterns)
    positive = PRODUCTION_API.encode("utf-8")
    overlap = max(len(pattern) for _, pattern in patterns + [("production", positive)]) - 1
    production_present = False
    findings = set()
    for path, open_stream in sorted(files.items()):
        tail = b""
        with open_stream() as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                data = tail + chunk
                normalized = data.lower()
                excluded_endpoint_path = (ownership_mode and
                                          (path == executable or path.startswith(PLACES_RESOURCE_PREFIXES)))
                for label, pattern in patterns:
                    if excluded_endpoint_path and label in PROHIBITED:
                        continue
                    if pattern in normalized:
                        findings.add((path, label))
                if path == executable and positive in data:
                    production_present = True
                tail = data[-overlap:]
    # Report only known policy labels and relative file names, never matching bytes.
    endpoints = sorted(item for item in findings if item[1] in PROHIBITED)
    mock_tokens = sorted(item for item in findings if item[1] in MOCK_TOKEN_LITERALS)
    require(not endpoints, "prohibited_endpoint_material:" + json.dumps(endpoints))
    require(not mock_tokens, "prohibited_mock_token_material:" + json.dumps(mock_tokens))
    require(production_present, "production_endpoint_missing_from_executable")
    result = {"endpointScan": "PASS", "filesScanned": len(files),
            "configuration": "Production", "environment": "production", "demo": False,
            "productionEndpointPresent": True, "prohibitedEndpointCount": 0,
            "mockTokenLiteralScan": "PASS", "prohibitedMockTokenCount": 0}
    if ownership_mode:
        result.update({"ownershipMode": "verified-static-sdk",
                       "firstPartyObjectCount": object_count,
                       "firstPartyLocalhostFound": False,
                       "thirdPartySDKLocalhostOnly": True})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", help="Actual built .app, .xcarchive or exported .ipa; no network access")
    parser.add_argument("--first-party-objects",
                        help="Kairo target Objects-normal directory from this exact Production build")
    parser.add_argument("--third-party-archive",
                        help="GooglePlaces.a from this exact pinned Production build")
    args = parser.parse_args()
    try:
        ownership = args.first_party_objects is not None or args.third_party_archive is not None
        print(json.dumps(scan(args.artifact,
                              first_party_objects=args.first_party_objects,
                              third_party_archive=args.third_party_archive,
                              source_root=ROOT if ownership else None), sort_keys=True))
    except (EndpointError, OSError) as error:
        # OSError can carry an external path; keep infrastructure errors categorical.
        print(json.dumps({"endpointScan": "FAIL", "reason": str(error) if isinstance(error, EndpointError)
                          else "artifact_read_failed"}, sort_keys=True))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
