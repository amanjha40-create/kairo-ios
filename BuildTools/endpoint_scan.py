#!/usr/bin/env python3
"""Read-only Production .app/.xcarchive endpoint gate; never prints file contents."""
import argparse
import json
from pathlib import Path
import plistlib


PRODUCTION_API = "https://api.kairoid.com/api/v1"
# Host fragments also catch alternate paths, ports and schemes. Only the packaged
# app is scanned, not source/docs, dSYMs or other non-shipping archive metadata.
PROHIBITED = ("localhost", "127.0.0.1", "staging-api.kairoid.com",
              "d3kpvsn9kfajzc.cloudfront.net")
ENCODINGS = ("utf-8", "utf-16-le", "utf-16-be")


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


def scan(artifact):
    app = app_path(artifact)
    files = []
    for path in sorted(app.rglob("*")):
        require(not path.is_symlink(), "packaged_symlink_rejected")
        require(path.is_file() or path.is_dir(), "unsupported_packaged_entry")
        if path.is_file():
            files.append(path)
    try:
        info = plistlib.loads((app / "Info.plist").read_bytes())
    except (OSError, ValueError, plistlib.InvalidFileException):
        raise EndpointError("invalid_info_plist") from None
    require(info.get("KAIROBuildConfiguration") == "Production", "configuration_not_production")
    require(info.get("KAIROAppEnvironment") == "production", "environment_not_production")
    require(info.get("KAIRODemoMode") == "NO", "demo_not_disabled")
    name = info.get("CFBundleExecutable")
    require(isinstance(name, str) and name not in ("", ".", "..")
            and Path(name).name == name, "invalid_executable_name")
    executable = app / name
    require(executable in files, "executable_missing")

    patterns = [(value, value.encode(encoding)) for value in PROHIBITED for encoding in ENCODINGS]
    positive = PRODUCTION_API.encode("utf-8")
    overlap = max(len(pattern) for _, pattern in patterns + [("production", positive)]) - 1
    production_present = False
    findings = set()
    for path in files:
        tail = b""
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                data = tail + chunk
                normalized = data.lower()
                for label, pattern in patterns:
                    if pattern in normalized:
                        findings.add((path.relative_to(app).as_posix(), label))
                if path == executable and positive in data:
                    production_present = True
                tail = data[-overlap:]
    # Report only known policy labels and relative file names, never matching bytes.
    require(not findings, "prohibited_endpoint_material:" + json.dumps(sorted(findings)))
    require(production_present, "production_endpoint_missing_from_executable")
    return {"endpointScan": "PASS", "filesScanned": len(files),
            "configuration": "Production", "environment": "production", "demo": False,
            "productionEndpointPresent": True, "prohibitedEndpointCount": 0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", help="Actual built .app or .xcarchive; no network access")
    args = parser.parse_args()
    try:
        print(json.dumps(scan(args.artifact), sort_keys=True))
    except (EndpointError, OSError) as error:
        # OSError can carry an external path; keep infrastructure errors categorical.
        print(json.dumps({"endpointScan": "FAIL", "reason": str(error) if isinstance(error, EndpointError)
                          else "artifact_read_failed"}, sort_keys=True))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
