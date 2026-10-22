import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "Kairo/Resources/Geography"


class GeographyTests(unittest.TestCase):
    def test_every_resource_matches_pinned_manifest(self):
        manifest = json.loads((DATA / "Geography-Attribution.json").read_text())
        self.assertEqual(manifest["revision"], "7795d77d6a801543b9bb90d97a182c885f44c458")
        self.assertEqual(manifest["license"], "ODbL-1.0")
        for name, digest in manifest["resourceSHA256"].items():
            self.assertEqual(hashlib.sha256((DATA / name).read_bytes()).hexdigest(), digest, name)
        self.assertEqual(len(manifest["resourceSHA256"]), 251)

    def test_country_files_have_sorted_unique_names_and_record_gaps(self):
        countries = json.loads((DATA / "Geography-Countries.json").read_text())
        manifest = json.loads((DATA / "Geography-Attribution.json").read_text())
        self.assertEqual(len(countries), 250)
        count = 0
        for code in countries:
            country = json.loads((DATA / f"Geography-{code}.json").read_text())
            regions = country["regions"]
            names = [r["name"] for r in regions]
            self.assertEqual(names, sorted(set(names)), code)
            for region in regions:
                self.assertEqual(region["cities"], sorted(set(region["cities"])), code)
                count += len(region["cities"])
                if not region["cities"]:
                    self.assertIn(region["name"], manifest["coverageGaps"][code]["regionsWithoutCities"])
            if not regions and not country["cities"]:
                self.assertTrue(manifest["coverageGaps"][code]["noHierarchy"])
        self.assertEqual(count, manifest["cityCountWithinRegions"])

    def test_license_and_distribution_notice_retained(self):
        licence = (DATA / "Geography-LICENSE.txt").read_bytes()
        self.assertEqual(hashlib.sha256(licence).hexdigest(), "6042621cae96bbce3a10739b480a074e25b0ea23025c00d7874582ad2c47b780")
        self.assertIn("accessible download/source offer", (DATA / "README.md").read_text())


if __name__ == "__main__":
    unittest.main()
