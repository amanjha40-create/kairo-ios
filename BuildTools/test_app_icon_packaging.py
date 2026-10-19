"""Icon-only release contract. Master reused unchanged from repository commit
af4f4e93c9387fab78b94e289727a5c292094463; smaller PNGs are sips resamples.
Set KAIRO_ICON_APP_PATH to inspect an actual built/archive app as well.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / "Kairo/Assets.xcassets/AppIcon.appiconset"
MASTER_SHA256 = "049e19841148f5e48d9d668546e8ed977180d033fd1ef66248837cbc418c881f"


class AppIconPackagingTests(unittest.TestCase):
    def setUp(self):
        self.images = json.loads((ICONS / "Contents.json").read_text())["images"]

    def test_canonical_master_is_unchanged_not_badged_or_redesigned(self):
        self.assertEqual(hashlib.sha256((ICONS / "Kairo-AppIcon-1024.png").read_bytes()).hexdigest(), MASTER_SHA256)

    def test_all_required_phone_tablet_and_marketing_slots_exist(self):
        expected = {
            ("iphone", size, scale)
            for size in ("20x20", "29x29", "40x40", "60x60")
            for scale in ("2x", "3x")
        } | {
            ("ipad", size, scale)
            for size in ("20x20", "29x29", "40x40", "76x76")
            for scale in ("1x", "2x")
        } | {("ipad", "83.5x83.5", "2x"), ("ios-marketing", "1024x1024", "1x")}
        self.assertEqual({(i["idiom"], i["size"], i["scale"]) for i in self.images}, expected)
        self.assertEqual(len(self.images), len(expected))

    def test_every_slot_is_an_opaque_png_with_exact_dimensions(self):
        for item in self.images:
            with self.subTest(slot=item):
                data = (ICONS / item["filename"]).read_bytes()
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                width, height, depth, color = struct.unpack(">IIBB", data[16:26])
                expected = int(float(item["size"].split("x")[0]) * int(item["scale"][0]))
                self.assertEqual((width, height), (expected, expected))
                self.assertEqual(depth, 8)
                self.assertEqual(color, 2, "Icons must be opaque RGB, not RGBA")
                offset = 8
                while offset < len(data):
                    length = struct.unpack(">I", data[offset:offset + 4])[0]
                    self.assertNotEqual(data[offset + 4:offset + 8], b"tRNS")
                    offset += length + 12

    def test_target_keeps_appicon_and_release_identity(self):
        raw = subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(ROOT / "Kairo.xcodeproj/project.pbxproj")])
        objects = json.loads(raw)["objects"]
        target = next(v for v in objects.values() if v.get("isa") == "PBXNativeTarget" and v.get("name") == "Kairo")
        for key in objects[target["buildConfigurationList"]]["buildConfigurations"]:
            config = objects[key]
            settings = config["buildSettings"]
            self.assertEqual(settings["ASSETCATALOG_COMPILER_APPICON_NAME"], "AppIcon")
            if config["name"] == "Production":
                self.assertEqual(settings["DEVELOPMENT_TEAM"], "MVT4T97ZGC")
                self.assertEqual(settings["PRODUCT_BUNDLE_IDENTIFIER"], "com.kairoid.Kairo")
                self.assertEqual(str(settings["CURRENT_PROJECT_VERSION"]), "3")
                self.assertEqual(settings["MARKETING_VERSION"], "1.0")
                self.assertEqual(settings["KAIRO_APP_ENVIRONMENT_NAME"], "production")
                self.assertEqual(settings["KAIRO_DEMO_MODE_DEFAULT"], "NO")

    def test_associated_domains_remain_exact(self):
        entitlements = plistlib.loads((ROOT / "Kairo-Production.entitlements").read_bytes())
        self.assertEqual(entitlements, {"com.apple.developer.associated-domains": ["applinks:api.kairoid.com"]})

    @unittest.skipUnless(os.environ.get("KAIRO_ICON_APP_PATH"), "Requires a built app bundle")
    def test_built_bundle_has_compiled_metadata_and_required_device_icons(self):
        app = Path(os.environ["KAIRO_ICON_APP_PATH"])
        info = plistlib.loads((app / "Info.plist").read_bytes())
        self.assertEqual(info["CFBundleIdentifier"], "com.kairoid.Kairo")
        for key in ("CFBundleIcons", "CFBundleIcons~ipad"):
            primary = info[key]["CFBundlePrimaryIcon"]
            self.assertEqual(primary["CFBundleIconName"], "AppIcon")
            self.assertTrue(primary["CFBundleIconFiles"])
        for filename, dimension in (("AppIcon60x60@2x.png", 120), ("AppIcon76x76@2x~ipad.png", 152)):
            output = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(app / filename)], text=True)
            self.assertIn(f"pixelWidth: {dimension}", output)
            self.assertIn(f"pixelHeight: {dimension}", output)
        self.assertTrue((app / "Assets.car").is_file())


if __name__ == "__main__":
    unittest.main()
