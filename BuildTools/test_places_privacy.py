"""Offline Places credential and address-selection boundary checks."""
from pathlib import Path
import plistlib
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
ADDRESS = ROOT / "Kairo/Features/PermanentAddress"


class PlacesPrivacyTests(unittest.TestCase):
    def test_production_substitution_and_staging_isolation(self):
        production = plistlib.loads((ROOT / "Kairo-Production-Info.plist").read_bytes())
        other = plistlib.loads((ROOT / "Kairo-Info.plist").read_bytes())
        self.assertEqual(production["GOOGLE_PLACES_API_KEY"], "$(GOOGLE_PLACES_API_KEY)")
        self.assertNotIn("GOOGLE_PLACES_API_KEY", other)
        project = (ROOT / "Kairo.xcodeproj/project.pbxproj").read_text()
        self.assertEqual(project.count("baseConfigurationReference = AABA0004301796C10044E7FE"), 1)

    def test_secrets_ignored_not_tracked(self):
        path = "Configuration/ProductionSecrets.xcconfig"
        self.assertEqual(subprocess.run(["git", "check-ignore", "-q", path], cwd=ROOT).returncode, 0)
        self.assertFalse(subprocess.check_output(["git", "ls-files", path], cwd=ROOT).strip())

    def test_selection_is_transient_and_coordinate_free(self):
        source = (ADDRESS / "PlacesAddressSelection.swift").read_text()
        view = (ADDRESS / "PermanentAddressView.swift").read_text()
        for forbidden in ("print(", "NSLog(", "Logger(", "UserDefaults", "@AppStorage", "latitude", "longitude"):
            self.assertNotIn(forbidden, source)
        self.assertIn("placeProperties: [.placeID, .formattedAddress, .addressComponents]", view)
        self.assertIn("initialQuery: address.addressLine1", view)
        self.assertIn("selection?.placeID(for: address)", view)
        self.assertIn("fetchTask?.cancel(); fetchTask = nil; selection = nil", view)
        prefill = view.split("private func consumeDigiLockerHandoff()")[1].split("private static func")[0]
        self.assertNotIn("model.save", prefill)
        selection = view.split("private func fetchPlace(")[1].split("struct PermanentAddressEntry")[0]
        self.assertNotIn("model.save", selection)

    def test_single_bootstrap_and_no_maps_sdk(self):
        source = (ROOT / "Kairo/App/KairoApp.swift").read_text()
        self.assertEqual(source.count("PlacesBootstrap.configure("), 1)
        config = (ADDRESS / "PlacesAddressSelection.swift").read_text()
        self.assertIn("guard !attempted", config)
        self.assertIn("configuration.buildConfiguration == .production", config)
        project = (ROOT / "Kairo.xcodeproj/project.pbxproj").read_text()
        self.assertNotIn("ios-maps-sdk", project)


if __name__ == "__main__":
    unittest.main()
