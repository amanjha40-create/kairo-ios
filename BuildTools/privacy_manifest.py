#!/usr/bin/env python3
"""Offline, fail-closed source/artifact gate. No app/network/signing mutations.

Policy rationale and Apple references: iOS-Privacy-Manifest-Packaging-Fix.md.
This lexical inventory is a regression tripwire, not a Swift semantic analyzer.
New dependencies or API occurrences require a human shipping-path audit.
"""
import argparse
import json
import plistlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = Path('Kairo/PrivacyInfo.xcprivacy')
API_PREFIX = 'NSPrivacyAccessedAPICategory'
DATA_PREFIX = 'NSPrivacyCollectedDataType'
REASONS = {'UserDefaults': ['CA92.1'], 'SystemBootTime': ['35F9.1']}
COLLECTED = {
    'Name', 'EmailAddress', 'PhoneNumber', 'PhysicalAddress', 'OtherUserContactInfo',
    'PaymentInfo', 'OtherFinancialInfo', 'PreciseLocation', 'CoarseLocation', 'PhotosorVideos',
    'CustomerSupport', 'OtherUserContent', 'UserID', 'ProductInteraction', 'DeviceID',
    'OtherDataTypes',
}
ANALYTICS = {'CoarseLocation', 'UserID', 'ProductInteraction', 'DeviceID', 'OtherDataTypes'}
# Exact vendor declarations audited for the pinned Places 11.2.0 and Firebase 13.1.1
# distributions. These declarations are SDK-owned and are checked independently of
# KairoID's account-linked app telemetry policy above.
EMPTY_SDK_MANIFEST = {
    'NSPrivacyAccessedAPITypes': [], 'NSPrivacyCollectedDataTypes': [],
    'NSPrivacyTracking': False, 'NSPrivacyTrackingDomains': [],
}
SDK_MANIFESTS = {
    'GooglePlaces_GooglePlacesTarget.bundle/GooglePlaces.bundle/PrivacyInfo.xcprivacy': {
        'NSPrivacyAccessedAPITypes': [
            {'NSPrivacyAccessedAPIType': API_PREFIX + 'FileTimestamp', 'NSPrivacyAccessedAPITypeReasons': ['C617.1']},
            {'NSPrivacyAccessedAPIType': API_PREFIX + 'UserDefaults', 'NSPrivacyAccessedAPITypeReasons': ['1C8F.1', 'CA92.1']},
        ],
        'NSPrivacyCollectedDataTypes': [{
            DATA_PREFIX: DATA_PREFIX + 'DeviceID', DATA_PREFIX + 'Linked': False,
            DATA_PREFIX + 'Purposes': [DATA_PREFIX + 'PurposeAnalytics', DATA_PREFIX + 'PurposeAppFunctionality'],
            DATA_PREFIX + 'Tracking': False,
        }],
    },
    'GooglePlaces_GooglePlacesSwiftTarget.bundle/GooglePlacesSwift.bundle/PrivacyInfo.xcprivacy': {
        'NSPrivacyAccessedAPITypes': [], 'NSPrivacyCollectedDataTypes': [],
    },
    'Firebase_FirebaseCore.bundle/PrivacyInfo.xcprivacy': {
        'NSPrivacyAccessedAPITypes': [{
            'NSPrivacyAccessedAPIType': API_PREFIX + 'UserDefaults',
            'NSPrivacyAccessedAPITypeReasons': ['CA92.1'],
        }],
        'NSPrivacyCollectedDataTypes': [], 'NSPrivacyTracking': False,
        'NSPrivacyTrackingDomains': [],
    },
    'Firebase_FirebaseCoreInternal.bundle/PrivacyInfo.xcprivacy': {
        'NSPrivacyAccessedAPITypes': [{
            'NSPrivacyAccessedAPIType': API_PREFIX + 'UserDefaults',
            'NSPrivacyAccessedAPITypeReasons': ['1C8F.1'],
        }],
        'NSPrivacyCollectedDataTypes': [], 'NSPrivacyTracking': False,
        'NSPrivacyTrackingDomains': [],
    },
    'Firebase_FirebaseInstallations.bundle/PrivacyInfo.xcprivacy': {
        'NSPrivacyAccessedAPITypes': [],
        'NSPrivacyCollectedDataTypes': [{
            DATA_PREFIX: DATA_PREFIX + 'OtherDiagnosticData', DATA_PREFIX + 'Linked': False,
            DATA_PREFIX + 'Purposes': [DATA_PREFIX + 'PurposeAnalytics'],
            DATA_PREFIX + 'Tracking': False,
        }],
        'NSPrivacyTracking': False, 'NSPrivacyTrackingDomains': [],
    },
    'GoogleUtilities_GoogleUtilities-Environment.bundle/PrivacyInfo.xcprivacy': {
        'NSPrivacyAccessedAPITypes': [{
            'NSPrivacyAccessedAPIType': API_PREFIX + 'UserDefaults',
            'NSPrivacyAccessedAPITypeReasons': ['C56D.1'],
        }],
        'NSPrivacyCollectedDataTypes': [], 'NSPrivacyTracking': False,
        'NSPrivacyTrackingDomains': [],
    },
    'GoogleUtilities_GoogleUtilities-Network.bundle/PrivacyInfo.xcprivacy': {
        'NSPrivacyAccessedAPITypes': [{
            'NSPrivacyAccessedAPIType': API_PREFIX + 'FileTimestamp',
            'NSPrivacyAccessedAPITypeReasons': ['C617.1'],
        }],
        'NSPrivacyCollectedDataTypes': [], 'NSPrivacyTracking': False,
        'NSPrivacyTrackingDomains': [],
    },
    'GoogleUtilities_GoogleUtilities-UserDefaults.bundle/PrivacyInfo.xcprivacy': {
        'NSPrivacyAccessedAPITypes': [{
            'NSPrivacyAccessedAPIType': API_PREFIX + 'UserDefaults',
            'NSPrivacyAccessedAPITypeReasons': ['1C8F.1', 'C56D.1'],
        }],
        'NSPrivacyCollectedDataTypes': [], 'NSPrivacyTracking': False,
        'NSPrivacyTrackingDomains': [],
    },
    **{
        path: EMPTY_SDK_MANIFEST for path in (
            'GoogleUtilities_GoogleUtilities-AppDelegateSwizzler.bundle/PrivacyInfo.xcprivacy',
            'GoogleUtilities_GoogleUtilities-Logger.bundle/PrivacyInfo.xcprivacy',
            'GoogleUtilities_GoogleUtilities-MethodSwizzler.bundle/PrivacyInfo.xcprivacy',
            'GoogleUtilities_GoogleUtilities-NSData.bundle/PrivacyInfo.xcprivacy',
            'GoogleUtilities_GoogleUtilities-Reachability.bundle/PrivacyInfo.xcprivacy',
            'Promises_FBLPromises.bundle/PrivacyInfo.xcprivacy',
            'nanopb_nanopb.bundle/PrivacyInfo.xcprivacy',
        )
    },
}
EMBEDDED_FRAMEWORKS = {
    'FirebaseAnalytics.framework': ('com.google.FirebaseAnalytics', '13.0.1'),
    'GoogleAppMeasurement.framework': ('com.google.GoogleAppMeasurement', '13.0.1'),
}
INVENTORY = {
    'UserDefaults': {
        'App/AppAppearanceStore.swift': 2,
        'App/LocalBatch1QA.swift': 1,  # Compiled, but gated off in ordinary Production.
        'Core/Analytics/AnalyticsConsent.swift': 2,
        'Core/Analytics/KairoAnalytics.swift': 2,
        'Features/GuidedTour/GuidedTourPreferences.swift': 2,
        'Features/Onboarding/ManualProfileDraftStore.swift': 1,
    },
    'SystemBootTime': {'Features/PermanentAddress/AddressLocationCollector.swift': 2},
    'FileTimestamp': {}, 'DiskSpace': {}, 'ActiveKeyboards': {},
}
PATTERNS = {
    'UserDefaults': r'\b(?:NSUserDefaults|UserDefaults|CFPreferences\w*|AppStorage|SceneStorage)\b',
    'SystemBootTime': r'\b(?:systemUptime|mach_absolute_time)\b',
    'FileTimestamp': r'\b(?:creationDate|modificationDate|fileModificationDate|contentModificationDateKey|creationDateKey)\b|\b(?:stat|fstat|fstatat|lstat|getattrlist|getattrlistbulk|fgetattrlist|getattrlistat)\s*\(',
    'DiskSpace': r'\b(?:volumeAvailableCapacity\w*|volumeTotalCapacity\w*|systemFreeSize|systemSize|statfs|statvfs|fstatfs|fstatvfs|attributesOfFileSystem)\b',
    'ActiveKeyboards': r'\bactiveInputModes\b',
}


class PrivacyError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise PrivacyError(message)


def read_manifest(path):
    try:
        raw = path.read_bytes()
        require(b'<!--' not in raw, 'Manifest comments are not part of certified policy')
        manifest = plistlib.loads(raw)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        raise PrivacyError('Missing or malformed privacy manifest') from error
    validate(manifest)
    return manifest


def validate(manifest):
    require(isinstance(manifest, dict), 'Manifest must be a dictionary')
    require(set(manifest) == {'NSPrivacyTracking', 'NSPrivacyTrackingDomains',
                             'NSPrivacyAccessedAPITypes', 'NSPrivacyCollectedDataTypes'},
            'Unexpected/missing manifest keys')
    require(manifest['NSPrivacyTracking'] is False, 'Tracking is not part of certified policy')
    require(manifest['NSPrivacyTrackingDomains'] == [], 'Tracking domains must be empty')
    rows = manifest['NSPrivacyAccessedAPITypes']
    require(isinstance(rows, list), 'API declarations must be an array')
    actual = {}
    for row in rows:
        require(isinstance(row, dict) and set(row) == {
            'NSPrivacyAccessedAPIType', 'NSPrivacyAccessedAPITypeReasons'}, 'Invalid API row')
        category = row['NSPrivacyAccessedAPIType']
        require(isinstance(category, str) and category not in actual, 'Duplicate/invalid API category')
        actual[category] = row['NSPrivacyAccessedAPITypeReasons']
    require(actual == {API_PREFIX + k: v for k, v in REASONS.items()},
            'Missing/unused API category or non-certified reason')
    data = manifest['NSPrivacyCollectedDataTypes']
    require(isinstance(data, list), 'Data declarations must be an array')
    seen = set()
    for row in data:
        require(isinstance(row, dict) and set(row) == {
            DATA_PREFIX, DATA_PREFIX + 'Linked', DATA_PREFIX + 'Tracking', DATA_PREFIX + 'Purposes'},
            'Invalid data row')
        kind = row[DATA_PREFIX]
        require(isinstance(kind, str) and kind not in seen, 'Duplicate/invalid data type')
        seen.add(kind)
        require(row[DATA_PREFIX + 'Linked'] is True, 'Collected data is account-linked')
        require(row[DATA_PREFIX + 'Tracking'] is False, 'Collected data is not used for tracking')
        short_kind = kind.removeprefix(DATA_PREFIX)
        purposes = ([] if short_kind == 'DeviceID' else [DATA_PREFIX + 'PurposeAppFunctionality'])
        if short_kind in ANALYTICS:
            purposes.append(DATA_PREFIX + 'PurposeAnalytics')
        require(row[DATA_PREFIX + 'Purposes'] == purposes, 'Unexpected collection purpose')
    require(seen == {DATA_PREFIX + k for k in COLLECTED}, 'Known data omitted or unaudited data added')


def inventory(root):
    found = {category: {} for category in PATTERNS}
    # Include compiled fixture files conservatively; do not hide new API uses by filename.
    for path in (root / 'Kairo').rglob('*'):
        if path.suffix not in {'.swift', '.m', '.mm', '.c', '.h', '.cpp'}:
            continue
        source = path.read_text()
        for category, pattern in PATTERNS.items():
            count = len(re.findall(pattern, source))
            if count:
                found[category][path.relative_to(root / 'Kairo').as_posix()] = count
    return found


def verify_source(root=ROOT):
    manifest = read_manifest(root / MANIFEST)
    project = (root / 'Kairo.xcodeproj/project.pbxproj').read_text()
    target = project.split('/* Begin PBXNativeTarget section */', 1)[1].split(
        '0738F9D8301796C10044E7FE /* KairoTests */', 1)[0]
    require('fileSystemSynchronizedGroups = (\n\t\t\t\t0738F9CF301796C00044E7FE /* Kairo */,' in target,
            'Kairo synchronized resource root is not attached to app target')
    require('PBXFileSystemSynchronizedRootGroup' in project and 'path = Kairo;' in project,
            'Missing app synchronized root')
    require('membershipExceptions' not in project and 'PrivacyInfo.xcprivacy' not in project,
            'Resource exceptions/explicit membership need re-audit')
    objects = json.loads(subprocess.check_output([
        'plutil', '-convert', 'json', '-o', '-', str(root / 'Kairo.xcodeproj/project.pbxproj')
    ]))['objects']
    app_targets = [value for value in objects.values()
                   if value.get('isa') == 'PBXNativeTarget' and value.get('name') == 'Kairo']
    require(len(app_targets) == 1, 'Kairo target dependency inventory changed')
    product_ids = set(app_targets[0].get('packageProductDependencies', []))
    require(product_ids == {'AABA0002301796C10044E7FE', 'FBAN0002301796C10044E7FE'},
            'New package dependency needs privacy audit')
    require({objects[identifier].get('productName') for identifier in product_ids} ==
            {'GooglePlacesSwift', 'FirebaseAnalyticsCore'}, 'Unaudited SDK product')
    packages = {value.get('repositoryURL'): value.get('requirement') for value in objects.values()
                if value.get('isa') == 'XCRemoteSwiftPackageReference'}
    require(packages == {
        'https://github.com/googlemaps/ios-places-sdk': {'kind': 'exactVersion', 'version': '11.2.0'},
        'https://github.com/firebase/firebase-ios-sdk': {'kind': 'exactVersion', 'version': '13.1.1'},
    }, 'Unaudited package repository or version')
    build_products = {value.get('productRef') for value in objects.values()
                      if value.get('isa') == 'PBXBuildFile'}
    require(build_products == product_ids, 'New explicit dependency needs audit')
    require(inventory(root) == INVENTORY, 'Required-reason API inventory changed; re-audit before certification')
    metadata = (root / 'Kairo/Features/Onboarding/ResumeImportState.swift').read_text()
    block = metadata.split('private static func resolvedByteSize', 1)[1].split('\n}\n', 1)[0]
    require(re.findall(r'attributes\[\.(\w+)\]', block) == ['size', 'size'],
            'File metadata no longer size-only')
    require('resourceValues(forKeys: [.fileSizeKey])' in block, 'File resource keys need re-audit')
    return manifest


def verify_artifact(artifact, root=ROOT, require_signed=False):
    expected = verify_source(root)
    app = artifact / 'Products/Applications/Kairo.app' if artifact.suffix == '.xcarchive' else artifact
    require(app.is_dir() and app.suffix == '.app', 'Expected .app or .xcarchive')
    manifests = sorted(app.rglob('*.xcprivacy'))
    require(set(manifests) == {app / 'PrivacyInfo.xcprivacy', *(app / path for path in SDK_MANIFESTS)},
            'Missing or unaudited app/SDK privacy manifest')
    require(read_manifest(app / 'PrivacyInfo.xcprivacy') == expected, 'Artifact manifest differs from source policy')
    for path, declaration in SDK_MANIFESTS.items():
        require(plistlib.loads((app / path).read_bytes()) == declaration, 'SDK privacy declaration changed; re-audit')
    frameworks = sorted((app / 'Frameworks').glob('*.framework'))
    require({framework.name for framework in frameworks} == set(EMBEDDED_FRAMEWORKS),
            'Embedded framework added/removed; re-audit privacy')
    for framework in frameworks:
        info = plistlib.loads((framework / 'Info.plist').read_bytes())
        identifier, version = EMBEDDED_FRAMEWORKS[framework.name]
        require((info.get('CFBundleIdentifier'), info.get('CFBundleShortVersionString')) ==
                (identifier, version), 'Embedded framework identity/version changed; re-audit privacy')
    if require_signed:
        result = subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)],
                                capture_output=True, text=True)
        require(result.returncode == 0, 'Strict code signature verification failed')
        details = subprocess.run(['/usr/bin/codesign', '-d', '--verbose=4', str(app)],
                                 capture_output=True, text=True)
        require(details.returncode == 0 and 'TeamIdentifier=MVT4T97ZGC' in details.stderr,
                'Official team signature required')
        seal = plistlib.loads((app / '_CodeSignature/CodeResources').read_bytes())
        require('PrivacyInfo.xcprivacy' in seal.get('files2', {}), 'Manifest absent from signed resource seal')
    return {'privacyManifest': 'PASS', 'manifestCount': len(manifests),
            'sourcePolicyEquality': True, 'signedVerification': require_signed}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=Path)
    parser.add_argument('--require-signed', action='store_true')
    args = parser.parse_args()
    try:
        if args.artifact:
            print(json.dumps(verify_artifact(args.artifact, require_signed=args.require_signed)))
        else:
            require(not args.require_signed, '--require-signed requires --artifact')
            verify_source()
            print('Privacy source policy and required-reason inventory: PASS')
    except (PrivacyError, OSError, KeyError, IndexError) as error:
        parser.exit(1, 'Privacy verification failed: ' + str(error) + '\n')


if __name__ == '__main__':
    main()
