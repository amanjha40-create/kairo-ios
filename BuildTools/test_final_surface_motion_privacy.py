"""Offline boundaries for the final Android mirror; never contacts a service."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FinalSurfaceMotionPrivacyTests(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text()

    def test_preview_is_explicit_staging_and_uses_no_live_capability(self):
        source = self.read("Kairo/App/FinalMirrorQA.swift")
        for gate in ("configuration.buildConfiguration == .staging", "configuration.environment == .staging",
                     "!configuration.isDemoModeEnabled", "arguments.contains(UITestLaunchConfiguration.enabledArgument)"):
            self.assertIn(gate, source)
        for forbidden in ("URLSession", "KeychainTokenStore(", "CLLocationManager(", "ASWebAuthenticationSession(", ".verify(", ".locate("):
            self.assertNotIn(forbidden, source)

    def test_motion_has_no_network_or_persistent_product_state(self):
        source = self.read("Kairo/DesignSystem/Components/KairoPremiumMotion.swift")
        for forbidden in ("URLSession", "UserDefaults", "@AppStorage", "repeatForever", "Timer.publish", "Keychain"):
            self.assertNotIn(forbidden, source)
        for gate in ("scenePhase", "entry.active", "onDisappear", "accessibilityReduceMotion", ".accessibilityHidden(true)"):
            self.assertIn(gate, source)

    def test_location_is_local_and_old_wire_value_is_preserved(self):
        source = self.read("Kairo/DesignSystem/Components/CandidateLocationFields.swift")
        for forbidden in ("URLSession", "MapKit", "CLLocationManager", "Legacy location", "Legacy Location"):
            self.assertNotIn(forbidden, source)
        self.assertIn("guard selected != country else { return }", source)
        self.assertIn("allowCustom: true", source)
        editor = self.read("Kairo/Features/Profile/ProfileEditors.swift")
        self.assertNotIn('TextField("Legacy', editor)

    def test_authoritative_motion_only_observes_existing_projection(self):
        dl = self.read("Kairo/Features/DigiLocker/DigiLockerViews.swift")
        self.assertIn("previous == false && current == true && !store.summaryError", dl)
        address = self.read("Kairo/Features/PermanentAddress/PermanentAddressView.swift")
        self.assertIn("model.state?.successfulGpsChecks", address)
        self.assertIn("current > previous", address)
        self.assertIn("state.canStartLocation != true", address)


if __name__ == "__main__":
    unittest.main()
