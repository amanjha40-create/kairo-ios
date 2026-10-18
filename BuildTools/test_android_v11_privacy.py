"""Source/asset boundary regressions; no device or external service access."""
import hashlib
import struct
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent


class AndroidV11PrivacyTests(unittest.TestCase):
    def test_external_logo_is_byte_identical_to_supplied_package(self):
        image = ROOT / "Kairo/Assets.xcassets/DigiLockerOfficial.imageset/compact.png"
        self.assertEqual(hashlib.sha256(image.read_bytes()).hexdigest(),
                         "f772ef83dabc983cb023dbcdc4b1b85f9c6b86ff43150d6cc9513a429aa23145")

    def test_master_retains_full_color_tm_with_true_alpha(self):
        # Deterministic alpha extraction from founder JPEG, not generated artwork.
        image = ROOT / "Kairo/Assets.xcassets/KairoIDMaster.imageset/master.png"
        self.assertEqual(hashlib.sha256(image.read_bytes()).hexdigest(),
                         "8ca157afcb154c6dfdea71392d3b21b254c1cfe60f0ce3d42d29f818731e02b1")
        png = image.read_bytes()
        self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", png[16:24]), (1280, 428))
        self.assertEqual(png[24:26], bytes([8, 6]))  # 8-bit true-color RGBA

    def test_shared_master_presentation_has_no_backplate_or_tint(self):
        source = (ROOT / "Kairo/Core/Presentation/ProductBrandViews.swift").read_text()
        master = source.split("struct KairoIDBrandView: View {")[1].split("struct DigiLockerBrandView")[0]
        self.assertIn('.renderingMode(.original)', master)
        self.assertIn('.accessibilityHidden(true)', master)
        self.assertNotIn('.background(', master)
        self.assertNotIn('.foregroundStyle(', master)
        self.assertNotIn('.shadow(', master)
        self.assertNotIn('.overlay(', master)
        self.assertIn('.adaptive(dark: colorScheme == .dark)', master)
        home = (ROOT / "Kairo/Features/Home/HomeOverviewScreenView.swift").read_text()
        self.assertIn('KairoIDBrandView(width: 108)', home)
        welcome = (ROOT / "Kairo/Features/Onboarding/WelcomeScreenView.swift").read_text()
        self.assertIn('KairoIDBrandView(width: 174, variant: .primary)', welcome)
        self.assertIn('KairoIDBrandView(width: 186 * scale, variant: .primary)', welcome)

    def test_white_master_is_exact_certified_rgba_asset(self):
        image = ROOT / "Kairo/Assets.xcassets/KairoIDMasterWhite.imageset/master-white.png"
        png = image.read_bytes()
        self.assertEqual(hashlib.sha256(png).hexdigest(),
                         "8df76eadd4bf8116274092e406086167d0ad80ab1875c713dd9e6692245bd2a7")
        self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", png[16:24]), (1280, 428))
        self.assertEqual(png[24:26], bytes([8, 6]))

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
