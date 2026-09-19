"""Offline tests. All Git repositories/app bundles are disposable temporary fixtures."""
import argparse
import contextlib
import io
import json
import os
import hashlib
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import provenance as p


SHA_A = "a" * 40
SHA_B = "b" * 40


def settings(configuration="Staging", version="2.3", number="42"):
    return {"CONFIGURATION": configuration, "KAIRO_BUILD_CONFIGURATION": configuration,
            "KAIRO_APP_ENVIRONMENT_NAME": p.CONFIGURATIONS[configuration],
            "MARKETING_VERSION": version, "CURRENT_PROJECT_VERSION": number}


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="kairo-provenance-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.input = self.root / "input.plist"
        self.app = self.root / "Kairo.app"
        self.app.mkdir()
        self.output = self.app / p.RESOURCE
        self.env = {**settings(), "KAIRO_PROVENANCE_REQUIRED": "YES",
                    "KAIRO_PROVENANCE_EXPECTED_SHA": SHA_A,
                    "SCRIPT_INPUT_FILE_0": str(self.input), "SCRIPT_OUTPUT_FILE_0": str(self.output)}

    def write(self, path, data):
        path.write_bytes(plistlib.dumps(data))

    def data(self, sha=SHA_A, configuration="Staging"):
        return p.generate(sha, settings(configuration), configuration)

    def info(self, configuration="Staging"):
        return {"CFBundleShortVersionString": "2.3", "CFBundleVersion": "42",
                "KAIROAppEnvironment": p.CONFIGURATIONS[configuration],
                "KAIROBuildConfiguration": configuration,
                "KAIRODemoMode": "YES" if configuration == "Demo" else "NO"}

    def valid_app(self):
        self.write(self.input, self.data())
        p.package(self.env)
        self.write(self.app / "Info.plist", self.info())

    def repository(self):
        root = self.root / "repo"
        root.mkdir()
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        subprocess.run(["git", "-C", str(root), "config", "user.name", "Test"], check=True)
        subprocess.run(["git", "-C", str(root), "config", "user.email", "test@example.invalid"], check=True)
        (root / "source.txt").write_text("test\n")
        subprocess.run(["git", "-C", str(root), "add", "source.txt"], check=True)
        subprocess.run(["git", "-C", str(root), "commit", "-qm", "fixture", "--no-gpg-sign"], check=True)
        return root

    def test_clean_git_and_detached_head(self):
        root = self.repository()
        sha = p.source_state(root)
        self.assertRegex(sha, r"^[0-9a-f]{40}$")
        subprocess.run(["git", "-C", str(root), "checkout", "--detach", "-q"], check=True)
        self.assertEqual(p.source_state(root), sha)

    def test_worktree_branch_uses_own_head_and_clean_state(self):
        root = self.repository()
        linked = self.root / "linked"
        subprocess.run(["git", "-C", str(root), "worktree", "add", "-qb", "codex/test", str(linked)], check=True)
        (root / "source.txt").write_text("dirty original\n")
        self.assertRegex(p.source_state(linked), r"^[0-9a-f]{40}$")
        with self.assertRaisesRegex(p.ProvenanceError, "source_not_clean"):
            p.source_state(root)

    def test_dirty_tracked_file_rejected(self):
        root = self.repository()
        (root / "source.txt").write_text("changed")
        with self.assertRaisesRegex(p.ProvenanceError, "source_not_clean"):
            p.source_state(root)

    def test_untracked_input_rejected(self):
        root = self.repository()
        (root / "extra.swift").write_text("test")
        with self.assertRaisesRegex(p.ProvenanceError, "source_not_clean"):
            p.source_state(root)

    def test_ignored_build_input_rejected(self):
        root = self.repository()
        (root / ".git" / "info" / "exclude").write_text("*.swift\n")
        (root / "Kairo").mkdir()
        (root / "Kairo" / "secret.swift").write_text("test")
        with self.assertRaisesRegex(p.ProvenanceError, "ignored_build_inputs"):
            p.source_state(root)

    def test_missing_git_rejected(self):
        with patch.object(p.subprocess, "run", side_effect=FileNotFoundError):
            with self.assertRaisesRegex(p.ProvenanceError, "required_tool_unavailable"):
                p.source_state(self.root)

    def test_missing_repository_rejected(self):
        with self.assertRaises(p.ProvenanceError):
            p.source_state(self.root)

    def test_external_git_index_override_rejected(self):
        with patch.dict(os.environ, {"GIT_INDEX_FILE": "external-index"}):
            with self.assertRaisesRegex(p.ProvenanceError, "external_git_override_not_supported"):
                p.source_state(self.root)

    def test_external_xcode_config_rejected(self):
        with patch.dict(os.environ, {"XCODE_XCCONFIG_FILE": "external-config"}):
            with self.assertRaisesRegex(p.ProvenanceError, "external_build_settings_not_supported"):
                p.build(None)

    def test_tracked_source_symlink_rejected(self):
        root = self.repository()
        (root / "link.swift").symlink_to("source.txt")
        subprocess.run(["git", "-C", str(root), "add", "link.swift"], check=True)
        subprocess.run(["git", "-C", str(root), "commit", "-qm", "link", "--no-gpg-sign"], check=True)
        with self.assertRaisesRegex(p.ProvenanceError, "source_symlink_not_supported"):
            p.source_state(root)

    def test_malformed_sha_rejected(self):
        for sha in ("UNKNOWN", "a" * 7, "A" * 40, "/private/source", "https://example.invalid"):
            with self.subTest(sha=sha), self.assertRaises(p.ProvenanceError):
                p.generate(sha, settings(), "Staging")

    def test_all_configurations_and_resolved_versions(self):
        for config, environment in p.CONFIGURATIONS.items():
            with self.subTest(config=config):
                data = p.generate(SHA_A, settings(config, "3.2.1", "905"), config)
                self.assertEqual(data["KAIROBuildVersion"], "3.2.1")
                self.assertEqual(data["KAIROBuildNumber"], "905")
                self.assertEqual(data["KAIROBuildEnvironment"], environment)
                self.assertEqual(data["KAIROBuildConfiguration"], config)
                self.assertIs(data["KAIROBuildSourceClean"], True)

    def test_missing_or_invalid_resolved_values_rejected(self):
        for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION", "CONFIGURATION",
                    "KAIRO_APP_ENVIRONMENT_NAME", "KAIRO_BUILD_CONFIGURATION"):
            data = settings()
            data.pop(key)
            with self.subTest(key=key), self.assertRaises(p.ProvenanceError):
                p.generate(SHA_A, data, "Staging")

    def test_package_and_verify_app(self):
        self.valid_app()
        self.assertEqual(p.verify(self.app, SHA_A, "Staging"), self.data())

    def test_package_replaces_old_sha(self):
        self.write(self.output, self.data(SHA_B))
        self.write(self.input, self.data(SHA_A))
        p.package(self.env)
        self.assertEqual(p.load(self.output)["KAIROBuildGitSHA"], SHA_A)

    def test_stale_input_rejected_and_stale_output_removed(self):
        self.write(self.input, self.data(SHA_B))
        self.write(self.output, self.data(SHA_B))
        with self.assertRaisesRegex(p.ProvenanceError, "stale_git_sha"):
            p.package(self.env)
        self.assertFalse(self.output.exists())

    def test_missing_input_fails_and_removes_old_output(self):
        self.write(self.output, self.data())
        with self.assertRaises(p.ProvenanceError):
            p.package(self.env)
        self.assertFalse(self.output.exists())

    def test_malformed_input_fails(self):
        self.input.write_text("not a plist")
        with self.assertRaises(p.ProvenanceError):
            p.package(self.env)

    def test_configuration_switch_refreshes_resource(self):
        for config in p.CONFIGURATIONS:
            self.env.update(settings(config))
            self.write(self.input, self.data(configuration=config))
            p.package(self.env)
            self.assertEqual(p.load(self.output), self.data(configuration=config))

    def test_packaging_setting_mismatches_fail(self):
        self.write(self.input, self.data())
        for key, value in (("MARKETING_VERSION", "9"), ("CURRENT_PROJECT_VERSION", "99"),
                           ("CONFIGURATION", "Demo"), ("KAIRO_APP_ENVIRONMENT_NAME", "production")):
            with self.subTest(key=key), self.assertRaises(p.ProvenanceError):
                p.package({**self.env, key: value})

    def test_new_version_and_build_propagate(self):
        self.env.update(settings(version="9.2", number="123"))
        self.write(self.input, p.generate(SHA_A, self.env, "Staging"))
        p.package(self.env)
        self.assertEqual(p.load(self.output)["KAIROBuildVersion"], "9.2")
        self.assertEqual(p.load(self.output)["KAIROBuildNumber"], "123")

    def test_developer_build_removes_candidate_stamp(self):
        self.write(self.output, self.data())
        self.write(self.input, p.DISABLED)
        self.assertEqual(p.package({**self.env, "KAIRO_PROVENANCE_REQUIRED": "NO"}), "developer_unattested")
        self.assertFalse(self.output.exists())

    def test_candidate_cannot_use_developer_sentinel(self):
        self.write(self.input, p.DISABLED)
        with self.assertRaises(p.ProvenanceError):
            p.package(self.env)

    def test_archive_cannot_bypass_candidate_metadata(self):
        self.write(self.input, p.DISABLED)
        with self.assertRaisesRegex(p.ProvenanceError, "archive_requires_provenance"):
            p.package({**self.env, "KAIRO_PROVENANCE_REQUIRED": "NO", "ACTION": "install"})

    def test_security_allowlist_rejects_extra_and_sensitive_values(self):
        for key in ("username", "sourcePath", "remoteURL", "accessToken", "signingSecret"):
            with self.subTest(key=key), self.assertRaises(p.ProvenanceError):
                p.validate({**self.data(), key: "forbidden"})
        for key in p.FIELDS - {"KAIROBuildSourceClean"}:
            with self.subTest(key=key), self.assertRaises(p.ProvenanceError):
                p.validate({**self.data(), key: "/Users/private/credential"})

    def test_unclean_or_nonboolean_flag_rejected(self):
        for value in (False, "true", 1):
            with self.subTest(value=value), self.assertRaises(p.ProvenanceError):
                p.validate({**self.data(), "KAIROBuildSourceClean": value})

    def test_verifier_rejects_missing_and_invalid_resource(self):
        self.write(self.app / "Info.plist", self.info())
        with self.assertRaises(p.ProvenanceError):
            p.verify(self.app, SHA_A, "Staging")
        self.output.write_text("bad")
        with self.assertRaises(p.ProvenanceError):
            p.verify(self.app, SHA_A, "Staging")

    def test_verifier_rejects_info_mismatch(self):
        self.valid_app()
        for key, value in (("CFBundleShortVersionString", "9"), ("CFBundleVersion", "99"),
                           ("KAIROAppEnvironment", "production"),
                           ("KAIROBuildConfiguration", "Production"), ("KAIRODemoMode", "YES")):
            self.write(self.app / "Info.plist", {**self.info(), key: value})
            with self.subTest(key=key), self.assertRaises(p.ProvenanceError):
                p.verify(self.app, SHA_A, "Staging")

    def test_verifier_rejects_expected_sha_or_configuration_mismatch(self):
        self.valid_app()
        for sha, config in ((SHA_B, "Staging"), (SHA_A, "Demo")):
            with self.assertRaises(p.ProvenanceError):
                p.verify(self.app, sha, config)

    def test_verifier_archive_and_signature_requirement(self):
        self.valid_app()
        archive = self.root / "Kairo.xcarchive"
        applications = archive / "Products" / "Applications"
        applications.mkdir(parents=True)
        self.app.rename(applications / self.app.name)
        self.assertEqual(p.verify(archive, SHA_A, "Staging"), self.data())
        with self.assertRaisesRegex(p.ProvenanceError, "signature_missing"):
            p.verify(archive, SHA_A, "Staging", signed=True)

    def test_metadata_symlink_rejected(self):
        self.write(self.input, self.data())
        self.output.symlink_to(self.input)
        with self.assertRaises(p.ProvenanceError):
            p.load(self.output)

    def test_digest_changes_with_content_not_directory_location(self):
        self.valid_app()
        first = p.tree_digest(self.app)
        other = self.root / "Other.app"
        self.app.rename(other)
        self.assertEqual(first, p.tree_digest(other))
        (other / "extra.txt").write_text("changed")
        self.assertNotEqual(first, p.tree_digest(other))

    def test_output_cannot_be_source_or_existing(self):
        with self.assertRaises(p.ProvenanceError):
            p.checked_output(self.root / "nested", self.root)
        with self.assertRaises(p.ProvenanceError):
            p.checked_output(self.app, self.root / "unrelated")

    def wrapper_case(self, source_states):
        args = argparse.Namespace(configuration="Staging", sdk="iphonesimulator", action="build",
                                  output=str(self.root / "candidate"), version="2.3",
                                  build_number="42", team=None)
        resolved = {**settings(), "TARGET_BUILD_DIR": str(self.root), "FULL_PRODUCT_NAME": "Kairo.app"}

        def fake_tool(command, cwd=None):
            if "-showBuildSettings" in command:
                return json.dumps([{"target": "Kairo", "buildSettings": resolved}])
            if command == ["xcodebuild", "-version"]:
                return "Xcode 27.0\nBuild version 27A266a"
            raise AssertionError("unexpected command")

        def fake_build(command, **kwargs):
            self.assertIn("KAIRO_PROVENANCE_EXPECTED_SHA=" + SHA_A, command)
            self.assertIn("KAIRO_PROVENANCE_REQUIRED=YES", command)
            self.assertIn("CURRENT_PROJECT_VERSION=42", command)
            data = p.load(Path(args.output) / "Input" / p.RESOURCE)
            self.write(self.output, data)
            self.write(self.app / "Info.plist", self.info())
            return subprocess.CompletedProcess(command, 0)

        with patch.object(p, "source_state", side_effect=source_states), \
                patch.object(p, "run", side_effect=fake_tool), \
                patch.object(p.subprocess, "run", side_effect=fake_build), \
                contextlib.redirect_stdout(io.StringIO()):
            p.build(args)
        return Path(args.output)

    def test_wrapper_sidecar_allowlist_and_final_bundle(self):
        directory = self.wrapper_case([SHA_A, SHA_A, SHA_A])
        records = list(directory.glob("*.json"))
        self.assertEqual(len(records), 1)
        record = json.loads(records[0].read_text())
        self.assertEqual(set(record), {"app", "platform", "gitSHA", "version", "buildNumber",
                                      "environment", "configuration", "sourceClean", "xcodeVersion",
                                      "artifact", "appBundleTreeSHA256", "digestAlgorithm", "signatureVerified"})
        self.assertEqual(record["artifact"], "Kairo.app")
        self.assertEqual(record["gitSHA"], SHA_A)
        self.assertEqual(record["appBundleTreeSHA256"], p.tree_digest(self.app))
        self.assertFalse(record["signatureVerified"])
        self.assertNotIn(str(self.root), records[0].read_text())
        self.assertNotIn("https://", records[0].read_text())

    def test_wrapper_head_change_during_preparation_fails(self):
        with self.assertRaisesRegex(p.ProvenanceError, "source_changed_during_preparation"):
            self.wrapper_case([SHA_A, SHA_B])
        self.assertFalse(list((self.root / "candidate").glob("*.json")))

    def test_wrapper_head_change_during_build_fails_without_sidecar(self):
        with self.assertRaisesRegex(p.ProvenanceError, "source_changed_during_build"):
            self.wrapper_case([SHA_A, SHA_A, SHA_B])
        self.assertFalse(list((self.root / "candidate").glob("*.json")))

    def test_signature_failure_rejected(self):
        self.valid_app()
        signature = self.app / "_CodeSignature"
        signature.mkdir()
        (signature / "CodeResources").write_text("synthetic invalid signature")
        with patch.object(p, "run", side_effect=p.ProvenanceError("tool_failed")):
            with self.assertRaises(p.ProvenanceError):
                p.verify(self.app, SHA_A, "Staging", signed=True)

    def test_signed_resource_requires_exact_sealed_hash(self):
        self.valid_app()
        signature = self.app / "_CodeSignature"
        signature.mkdir()
        actual = hashlib.sha256(self.output.read_bytes()).digest()
        for digest in (b"wrong", actual):
            self.write(signature / "CodeResources", {"files2": {p.RESOURCE: {"hash2": digest}}})
            with patch.object(p, "run", return_value=""), patch.object(p.subprocess, "run", return_value=
                    subprocess.CompletedProcess([], 0, stdout=b"", stderr=b"TeamIdentifier=TESTTEAM01")):
                if digest == actual:
                    self.assertEqual(p.verify(self.app, SHA_A, "Staging", signed=True), self.data())
                else:
                    with self.assertRaisesRegex(p.ProvenanceError, "provenance_not_sealed"):
                        p.verify(self.app, SHA_A, "Staging", signed=True)


if __name__ == "__main__":
    unittest.main()
