"""Offline source-boundary checks; no account, location, storage or network access."""
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[1]
ADDRESS = ROOT / "Kairo/Features/PermanentAddress"
REFERENCES = ROOT / "Kairo/Features/References"


class CandidateParityPrivacyTests(unittest.TestCase):
    def test_only_when_in_use_permission(self):
        info = plistlib.loads((ROOT / "Kairo-Info.plist").read_bytes())
        self.assertIn("NSLocationWhenInUseUsageDescription", info)
        self.assertNotIn("NSLocationAlwaysUsageDescription", info)
        self.assertNotIn("NSLocationAlwaysAndWhenInUseUsageDescription", info)
        self.assertNotIn("location", info.get("UIBackgroundModes", []))

    def test_collector_foreground_only_no_cached_or_always_request(self):
        source = (ADDRESS / "AddressLocationCollector.swift").read_text()
        self.assertIn("requestWhenInUseAuthorization()", source)
        self.assertIn("allowsBackgroundLocationUpdates = false", source)
        self.assertIn("willResignActiveNotification", source)
        self.assertIn("stopUpdatingLocation()", source)
        self.assertNotIn("requestAlwaysAuthorization", source)
        self.assertNotIn("startMonitoringSignificantLocationChanges", source)
        self.assertNotIn("= manager.location", source)

    def test_new_private_sources_have_no_log_cache_or_userdefaults(self):
        for folder in (ADDRESS, REFERENCES):
            for file in folder.glob("*.swift"):
                source = file.read_text()
                for forbidden in ("print(", "NSLog(", "Logger(", "UserDefaults", "@AppStorage", ".write(to:"):
                    self.assertNotIn(forbidden, source, str(file))

    def test_no_candidate_invitation_or_admin_endpoint(self):
        source = (REFERENCES / "EmploymentReferences.swift").read_text()
        self.assertIn('/reporting-manager', source)
        for forbidden in ('/invite', '/send', '/admin', '/hr/', '/organization'):
            self.assertNotIn(forbidden, source)

    def test_private_json_and_non_replayed_mutations(self):
        source = (ADDRESS / "PermanentAddressService.swift").read_text()
        self.assertIn('"Cache-Control":"no-store"', source)
        self.assertIn("requiresPrivateJSONTransport: true", source)
        self.assertIn("allowsSessionRefreshOnUnauthorized: method == .get", source)
        self.assertIn('"authorization", "cookie", "proxy-authorization"', source)

    def test_synthetic_fixture_has_no_live_capability(self):
        source = (ADDRESS / "CurrentParityQA.swift").read_text()
        for forbidden in ("CLLocationManager(", "URLSession(", "KeychainTokenStore(", "URLSessionNetworkClient("):
            self.assertNotIn(forbidden, source)
        self.assertIn("configuration.buildConfiguration == .staging", source)
        self.assertIn("arguments.contains(UITestLaunchConfiguration.enabledArgument)", source)

    def test_only_authoritative_status_verifies_and_passport_is_gated(self):
        source = (ADDRESS / "PermanentAddressModels.swift").read_text()
        self.assertIn('var isVerified: Bool { status == "PERMANENT_ADDRESS_VERIFIED" }', source)
        view = (ADDRESS / "PermanentAddressView.swift").read_text()
        self.assertIn("!passport || state.isVerified", view)
        self.assertIn("if !passport", view)

    def test_candidate_models_do_not_add_confidential_fields(self):
        source = (ADDRESS / "PermanentAddressModels.swift").read_text()
        for field in ("let targetLatitude", "let reviewer", "let objectKey", "let risk"):
            self.assertNotIn(field, source)
        references = (REFERENCES / "EmploymentReferences.swift").read_text().split("nonisolated enum ReferenceCopy")[0]
        for field in ("var workEmail", "var phone", "var rating", "var invitationUrl", "var comment"):
            self.assertNotIn(field, references)


if __name__ == "__main__":
    unittest.main()
