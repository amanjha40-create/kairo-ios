"""Offline mutation tests against packaged bytes, plus actual Swift compile policy."""
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile

import endpoint_scan as policy

ROOT = Path(__file__).resolve().parents[1]


class EndpointScanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="kairoid-endpoint-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / "Kairo.app"
        self.app.mkdir()
        self.info = {"CFBundleExecutable": "Kairo", "KAIROBuildConfiguration": "Production",
                     "KAIROAppEnvironment": "production", "KAIRODemoMode": "NO"}
        self.write_info()
        (self.app / "Kairo").write_bytes(b"binary\0" + policy.PRODUCTION_API.encode() + b"\0")

    def write_info(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))

    def test_clean_app_passes(self):
        self.assertEqual(policy.scan(self.app)["endpointScan"], "PASS")

    def test_archive_scans_only_shipping_payload(self):
        archive = self.root / "Kairo.xcarchive"
        shutil.copytree(self.app, archive / "Products/Applications/Kairo.app")
        (archive / "non-shipping-diagnostic.txt").write_text("localhost")
        self.assertEqual(policy.scan(archive)["endpointScan"], "PASS")

    def test_ambiguous_archive_rejected(self):
        archive = self.root / "Kairo.xcarchive"
        for name in ("First.app", "Second.app"):
            shutil.copytree(self.app, archive / "Products/Applications" / name)
        with self.assertRaises(policy.EndpointError):
            policy.scan(archive)

    def test_every_prohibited_host_and_encoding_rejected(self):
        for value in policy.PROHIBITED:
            for encoding in policy.ENCODINGS:
                with self.subTest(value=value, encoding=encoding):
                    (self.app / "resource.bin").write_bytes(value.upper().encode(encoding))
                    with self.assertRaises(policy.EndpointError):
                        policy.scan(self.app)

    def test_full_original_endpoints_rejected(self):
        for value in ("http://localhost:8000/api/v1", "https://staging-api.kairoid.com/api/v1"):
            (self.app / "resource.bin").write_bytes(value.encode())
            with self.assertRaises(policy.EndpointError):
                policy.scan(self.app)

    def test_nested_framework_and_resource_rejected(self):
        for name in ("Frameworks/Embedded.framework/Embedded", "Nested.bundle/config.json"):
            path = self.app / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"https://staging-api.kairoid.com/another/path")
            with self.assertRaises(policy.EndpointError):
                policy.scan(self.app)
            path.unlink()

    def test_chunk_boundary_rejected(self):
        (self.app / "resource.bin").write_bytes(b"x" * (1024 * 1024 - 3) + b"localhost")
        with self.assertRaises(policy.EndpointError):
            policy.scan(self.app)

    def test_metadata_cannot_claim_positive_without_executable_literal(self):
        (self.app / "Kairo").write_bytes(b"no endpoint")
        self.info["URL"] = policy.PRODUCTION_API
        self.write_info()
        with self.assertRaises(policy.EndpointError):
            policy.scan(self.app)

    def test_wrong_configuration_environment_or_demo_rejected(self):
        for key, value in (("KAIROBuildConfiguration", "Staging"), ("KAIROAppEnvironment", "development"),
                           ("KAIRODemoMode", "YES")):
            original = self.info[key]
            self.info[key] = value
            self.write_info()
            with self.assertRaises(policy.EndpointError):
                policy.scan(self.app)
            self.info[key] = original

    def test_missing_or_traversing_executable_rejected(self):
        for name in ("missing", "../outside", "..", ""):
            self.info["CFBundleExecutable"] = name
            self.write_info()
            with self.assertRaises(policy.EndpointError):
                policy.scan(self.app)

    def test_symlinks_rejected_without_following_external_files(self):
        (self.app / "external").symlink_to(self.root / "not-read")
        with self.assertRaises(policy.EndpointError):
            policy.scan(self.app)

    def test_source_docs_are_not_scanned(self):
        (self.root / "Documentation.md").write_text("localhost staging-api.kairoid.com")
        self.assertEqual(policy.scan(self.app)["endpointScan"], "PASS")

    def make_ipa(self):
        ipa = self.root / "Kairo.ipa"
        with zipfile.ZipFile(ipa, "w") as archive:
            for path in self.app.rglob("*"):
                if path.is_file():
                    archive.write(path, "Payload/Kairo.app/" + path.relative_to(self.app).as_posix())
        return ipa

    def test_clean_exported_ipa_passes_without_extraction(self):
        result = policy.scan(self.make_ipa())
        self.assertEqual(result["mockTokenLiteralScan"], "PASS")
        self.assertEqual(result["prohibitedMockTokenCount"], 0)
        self.assertFalse((self.root / "Payload").exists())

    def test_each_mock_literal_rejected_in_app_archive_and_ipa(self):
        archive = self.root / "Kairo.xcarchive"
        archived_app = archive / "Products/Applications/Kairo.app"
        shutil.copytree(self.app, archived_app)
        for literal in policy.MOCK_TOKEN_LITERALS:
            for encoding in policy.ENCODINGS:
                with self.subTest(literal=literal, encoding=encoding):
                    payload = b"x" * (1024 * 1024 - 3) + literal.encode(encoding)
                    (self.app / "mock.bin").write_bytes(payload)
                    (archived_app / "mock.bin").write_bytes(payload)
                    for artifact in (self.app, archive, self.make_ipa()):
                        with self.assertRaisesRegex(policy.EndpointError, literal):
                            policy.scan(artifact)

    def test_exported_ipa_preserves_endpoint_policy(self):
        for value in policy.PROHIBITED:
            (self.app / "resource.bin").write_bytes(value.encode())
            with self.assertRaises(policy.EndpointError):
                policy.scan(self.make_ipa())

    def test_ipa_rejects_ambiguous_payload_traversal_symlink_and_duplicates(self):
        for name, mode in (("Payload/Second.app/Info.plist", 0),
                           ("Payload/Kairo.app/../outside", 0),
                           ("/outside", 0), ("Payload/Kairo.app/link", 0o120777),
                           ("Payload/Kairo.app/Info.plist", 0)):
            with self.subTest(name=name):
                ipa = self.make_ipa()
                with zipfile.ZipFile(ipa, "a") as archive:
                    entry = zipfile.ZipInfo(name)
                    entry.external_attr = mode << 16
                    archive.writestr(entry, b"unused")
                with self.assertRaises(policy.EndpointError):
                    policy.scan(ipa)

    def test_invalid_ipa_rejected(self):
        ipa = self.root / "Kairo.ipa"
        ipa.write_bytes(b"not a zip")
        with self.assertRaisesRegex(policy.EndpointError, "invalid_ipa"):
            policy.scan(ipa)


class EndpointCompilationTests(unittest.TestCase):
    def test_mock_credential_implementations_and_factory_share_compile_boundary(self):
        boundary = "#if !KAIRO_PRODUCTION || KAIRO_LOCAL_BATCH1_QA"
        auth = (ROOT / "Kairo/Core/Auth/AuthService.swift").read_text()
        real, mock = auth.split(boundary, 1)
        mock, remainder = mock.split("#endif", 1)
        self.assertIn("actor AuthService: AuthServiceProtocol", real)
        self.assertIn("actor DemoAuthService: AuthServiceProtocol", mock)
        self.assertIn("actor UITestAuthService: AuthServiceProtocol", mock)
        for literal in policy.MOCK_TOKEN_LITERALS:
            self.assertIn('"' + literal + '"', mock)
            self.assertNotIn(literal, real + remainder)
        dependencies = (ROOT / "Kairo/App/AppDependencies.swift").read_text()
        selected = dependencies.split(boundary, 1)[1].split("#endif", 1)[0]
        ordinary = selected.split("#else", 1)[1]
        self.assertIn("authService = AuthService(", ordinary)
        self.assertNotIn("DemoAuthService(", ordinary)
        self.assertNotIn("UITestAuthService(", ordinary)
        fixture = (ROOT / "Kairo/App/SessionRecoveryQA.swift").read_text()
        self.assertIn(boundary + "\nactor SessionRecoveryQANetwork", fixture)
        stub = fixture.rsplit("#else", 1)[1]
        self.assertIn("EmptyView()", stub)
        self.assertNotIn("UITestAuthService", stub)

    def test_only_production_project_configuration_sets_flag(self):
        project = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-", str(ROOT / "Kairo.xcodeproj/project.pbxproj")]))
        matches = []
        for item in project["objects"].values():
            flags = item.get("buildSettings", {}).get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "")
            if "KAIRO_PRODUCTION" in flags:
                matches.append(item["name"])
        self.assertEqual(matches, ["Production"])

    def compile_and_run(self, production):
        with tempfile.TemporaryDirectory(prefix="kairoid-endpoint-swift-") as directory:
            path = Path(directory)
            main = path / "main.swift"
            main.write_text('''import Foundation
enum OnboardingStep: String { case welcome }
enum ProductBrand { static let supportEmailAddress = "unused@example.invalid" }
enum LocalBatch1QA { static func isEnabled(configuration: AppConfiguration) -> Bool { false } }
if CommandLine.arguments[1] == "resolve-production" {
    let resolved = AppConfiguration.resolve(bundleValues: [
        "KAIROBuildConfiguration": "Production", "KAIROAppEnvironment": "production", "KAIRODemoMode": "NO"
    ], environmentVariables: ["KAIRO_BUILD_CONFIGURATION": "Development",
        "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "YES"])
    print(resolved.apiBaseURL.absoluteString)
    print(resolved.environment.rawValue)
    print(resolved.isDemoModeEnabled)
    exit(0)
}
let environment = AppEnvironment(rawValue: CommandLine.arguments[1])!
print(BuildEndpointPolicy.baseURL(for: environment).absoluteString)
print(BuildEndpointPolicy.diagnosticHosts.sorted().joined(separator: ","))
print(BuildEndpointPolicy.developmentShareHosts.sorted().joined(separator: ","))
print(BuildEndpointPolicy.stagingShareHosts.sorted().joined(separator: ","))
print("default=" + BuildEndpointPolicy.defaultEnvironment.rawValue)
if let base = BuildEndpointPolicy.stagingAPIBaseURL { print(base.absoluteString) }
''')
            executable = path / "policy"
            command = ["xcrun", "swiftc", "-O", str(ROOT / "Kairo/Core/API/APIConfiguration.swift"),
                       str(ROOT / "Kairo/Core/Environment/AppConfiguration.swift"),
                       str(main), "-o", str(executable)]
            if production:
                command += ["-D", "KAIRO_PRODUCTION"]
            subprocess.run(command, check=True, capture_output=True)
            resolved = subprocess.check_output([str(executable), "resolve-production"], text=True)
            self.assertEqual(resolved.splitlines(), [policy.PRODUCTION_API, "production", "false"])
            expected = {"production": policy.PRODUCTION_API}
            if not production:
                expected.update(development="http://localhost:8000/api/v1",
                                staging="https://staging-api.kairoid.com/api/v1")
            for environment, url in expected.items():
                output = subprocess.check_output([str(executable), environment], text=True)
                self.assertEqual(output.splitlines()[0], url)
                self.assertIn("default=" + ("production" if production else "development"), output)
                if production:
                    for forbidden in policy.PROHIBITED:
                        self.assertNotIn(forbidden, output)
                else:
                    self.assertIn("staging-api.kairoid.com", output)
                    self.assertIn("localhost", output)
            if production:
                for forbidden in policy.PROHIBITED:
                    self.assertNotIn(forbidden.encode(), executable.read_bytes())
                for invalid in ("development", "staging"):
                    result = subprocess.run([str(executable), invalid], capture_output=True)
                    self.assertNotEqual(result.returncode, 0, "must fail closed, never fall back")

    def test_nonproduction_compilation_preserves_environment_endpoints(self):
        self.compile_and_run(False)

    def test_production_compilation_excludes_hosts_and_fails_closed(self):
        self.compile_and_run(True)

    def test_swiftui_default_uses_compiled_environment(self):
        source = (ROOT / "Kairo/Core/Environment/AppEnvironmentValues.swift").read_text()
        default = source.split("private struct AppConfigurationKey: EnvironmentKey {", 1)[1].split("\n}", 1)[0]
        self.assertIn("environment: BuildEndpointPolicy.defaultEnvironment", default)
        self.assertIn("APIConfiguration.make(for: BuildEndpointPolicy.defaultEnvironment)", default)
        self.assertNotIn("make(for: .development)", default)
