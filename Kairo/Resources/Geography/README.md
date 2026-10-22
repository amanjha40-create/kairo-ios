# Offline location database

Derived from **Countries States Cities Database**, dr5hn and contributors,
https://github.com/dr5hn/countries-states-cities-database at revision
`7795d77d6a801543b9bb90d97a182c885f44c458`.

This derived database is licensed under ODbL 1.0. See `Geography-LICENSE.txt`.
`Geography-Attribution.json` records the source hash, transformation, resource
hashes, and explicit coverage gaps. The app displays attribution beside the
location selectors. No network lookup or location permission is used.

Reproduce with `BuildTools/import_geography.py` using the pinned upstream
`json/countries+states+cities.json` and `LICENSE`. Both inputs must match the
approved SHA-256 values enforced by that script. Country resources retain only
names; cities in same-named administrative divisions are unioned because the
existing API stores names, not geographic IDs. No cities are invented.

Before distributing a build containing this database, provide recipients with
the derived JSON database, this notice, licence, attribution manifest, and
transformation script/source reference in an accessible download/source offer.
The private repository alone is not a public distribution offer. This remains a
Build 9 packaging prerequisite; no new build has been distributed by this task.

Coverage is community-maintained, not an assertion of every settlement worldwide.
Countries/regions without choices show an explicit gap. Existing saved custom
values remain available; new city values must come from the selected hierarchy.
