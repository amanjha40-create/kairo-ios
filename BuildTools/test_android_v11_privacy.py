"""Source/asset boundary regressions; no device or external service access."""
import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent


class AndroidV11PrivacyTests(unittest.TestCase):
    def test_external_logo_is_byte_identical_to_supplied_package(self):
        image = ROOT / "Kairo/Assets.xcassets/DigiLockerOfficial.imageset/compact.png"
        self.assertEqual(hashlib.sha256(image.read_bytes()).hexdigest(),
                         "f772ef83dabc983cb023dbcdc4b1b85f9c6b86ff43150d6cc9513a429aa23145")

    def test_master_retains_original_tm_artwork(self):
        image = ROOT / "Kairo/Assets.xcassets/KairoIDMaster.imageset/master.jpeg"
        self.assertEqual(hashlib.sha256(image.read_bytes()).hexdigest(),
                         "5edc1f81163eece67e93a0f65484b5791bea556d88e1e83b4466f63ad2a64138")

    def test_invitation_capability_uses_private_transport_no_storage_or_logging(self):
        source = (ROOT / "Kairo/Features/Notifications/TrustInvitationView.swift").read_text()
        self.assertEqual(source.count("requiresPrivateJSONTransport: true"), 2)
        for forbidden in ["print(", "Logger(", "UserDefaults", "Keychain", "UIPasteboard", "openURL"]:
            self.assertNotIn(forbidden, source)
        self.assertIn("<redacted>", source)

    def test_fixture_entry_requires_staging_and_validated_test_mode(self):
        source = (ROOT / "Kairo/App/AppRootView.swift").read_text()
        guard = source.split('KAIRO_UI_TEST_TRUST_INVITATION')[0][-300:]
        self.assertIn("buildConfiguration == .staging", guard)
        self.assertIn("environment == .staging", guard)
        self.assertIn("validated(for: appConfiguration).isEnabled", guard)


if __name__ == "__main__":
    unittest.main()
