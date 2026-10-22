"""Deterministic, offline transformation of the approved pinned ODbL snapshot.

Input: upstream countries+states+cities.json and LICENSE from REVISION.
Output: per-country resources, attribution and integrity/coverage manifest.
The derived database remains ODbL; distribute these files and this transformation
with the source snapshot reference when distributing an app that uses them.
"""
import argparse
import hashlib
import json
from pathlib import Path

REVISION = "7795d77d6a801543b9bb90d97a182c885f44c458"
SOURCE_SHA256 = "401f2db487336d00bbfd027b2080a4a393e8443f498ccfc675a67b52e08dd75a"
LICENSE_SHA256 = "6042621cae96bbce3a10739b480a074e25b0ea23025c00d7874582ad2c47b780"
SOURCE = "https://github.com/dr5hn/countries-states-cities-database"

def transform(source, license_file, output):
    raw = source.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("Source does not match the approved pinned snapshot")
    if hashlib.sha256(license_file.read_bytes()).hexdigest() != LICENSE_SHA256:
        raise ValueError("License does not match the approved snapshot")
    countries = json.loads(raw)
    output.mkdir(parents=True, exist_ok=True)
    index, hashes, gaps = {}, {}, {}
    city_count = 0
    def write(name, data):
        content = (json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()
        (output / name).write_bytes(content)
        hashes[name] = hashlib.sha256(content).hexdigest()
    for country in countries:
        code = country["iso2"]
        assert len(code) == 2 and code.isalpha() and code.isupper()
        assert code not in index
        grouped_regions = {}
        for region in country["states"]:
            grouped_regions.setdefault(region["name"], set()).update(city["name"] for city in region["cities"])
        # Backend stores names, not administrative IDs. Preserve all cities for
        # divisions sharing a name instead of dropping one or inventing a label.
        regions = [{"name": name, "cities": sorted(names)} for name, names in grouped_regions.items()]
        city_count += sum(len(region["cities"]) for region in regions)
        direct = sorted({city["name"] for city in country.get("cities", [])})
        index[code] = country["name"]
        write("Geography-" + code + ".json", {"regions": sorted(regions, key=lambda r: r["name"]), "cities": direct})
        empty = [r["name"] for r in regions if not r["cities"]]
        if empty or (not regions and not direct):
            gaps[code] = {"regionsWithoutCities": empty, "noHierarchy": not regions and not direct}
    write("Geography-Countries.json", index)
    (output / "Geography-LICENSE.txt").write_bytes(license_file.read_bytes())
    write("Geography-Attribution.json", {
        "name": "Countries States Cities Database", "author": "dr5hn and contributors",
        "source": SOURCE, "revision": REVISION, "license": "ODbL-1.0",
        "sourceSHA256": hashlib.sha256(raw).hexdigest(),
        "transformation": "Names grouped by country and administrative division name (same-name divisions unioned for the backend string contract); unused metadata removed; sorted and deduplicated.",
        "countryCount": len(index), "cityCountWithinRegions": city_count,
        "coverageGaps": gaps, "resourceSHA256": hashes,
        "notice": "Community-maintained coverage is not exhaustive. Missing places are not fabricated. Existing saved values are preserved."
    })
    print(json.dumps({"countries": len(index), "citiesWithinRegions": city_count, "countriesWithCoverageGaps": len(gaps)}))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("license", type=Path)
    args = parser.parse_args()
    transform(args.source, args.license, Path(__file__).resolve().parents[1] / "Kairo/Resources/Geography")
