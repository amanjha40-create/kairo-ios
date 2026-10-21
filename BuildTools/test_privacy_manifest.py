"""Positive and mutation-based negative packaging/privacy regression tests."""
import copy
import plistlib
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import privacy_manifest as policy


class PrivacyManifestTests(unittest.TestCase):
    def setUp(self):
        self.manifest = plistlib.loads((policy.ROOT / policy.MANIFEST).read_bytes())
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.app = Path(self.temp.name) / 'Kairo.app'
        self.app.mkdir()
        self.write(self.app / 'PrivacyInfo.xcprivacy', self.manifest)

    def write(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps(value))

    def rejects(self, value):
        with self.assertRaises(policy.PrivacyError):
            policy.validate(value)

    def test_source_target_and_inventory(self):
        policy.verify_source()

    def test_artifact_recursive_validation(self):
        self.assertEqual(policy.verify_artifact(self.app)['manifestCount'], 1)

    def test_archive_validation(self):
        archive = Path(self.temp.name) / 'Kairo.xcarchive'
        destination = archive / 'Products/Applications/Kairo.app'
        shutil.copytree(self.app, destination)
        self.assertTrue(policy.verify_artifact(archive)['sourcePolicyEquality'])

    def test_missing_source_manifest_fails(self):
        with self.assertRaises(policy.PrivacyError):
            policy.verify_source(Path(self.temp.name))

    def test_missing_artifact_manifest_fails(self):
        (self.app / 'PrivacyInfo.xcprivacy').unlink()
        with self.assertRaises(policy.PrivacyError):
            policy.verify_artifact(self.app)

    def test_nested_manifest_does_not_replace_app_manifest(self):
        (self.app / 'PrivacyInfo.xcprivacy').unlink()
        self.write(self.app / 'Nested.bundle/PrivacyInfo.xcprivacy', self.manifest)
        with self.assertRaises(policy.PrivacyError):
            policy.verify_artifact(self.app)

    def test_new_nested_manifest_requires_audit(self):
        self.write(self.app / 'Nested.bundle/PrivacyInfo.xcprivacy', self.manifest)
        with self.assertRaises(policy.PrivacyError):
            policy.verify_artifact(self.app)

    def test_malformed_plist_fails(self):
        (self.app / 'PrivacyInfo.xcprivacy').write_bytes(b'not a plist')
        with self.assertRaises(policy.PrivacyError):
            policy.verify_artifact(self.app)

    def test_private_values_cannot_hide_in_xml_comments(self):
        data = plistlib.dumps(self.manifest).replace(b'<dict>', b'<!-- synthetic-private-value -->\n<dict>', 1)
        (self.app / 'PrivacyInfo.xcprivacy').write_bytes(data)
        with self.assertRaises(policy.PrivacyError):
            policy.verify_artifact(self.app)

    def test_missing_required_categories_fails(self):
        for index in range(2):
            with self.subTest(index=index):
                value = copy.deepcopy(self.manifest)
                del value['NSPrivacyAccessedAPITypes'][index]
                self.rejects(value)

    def test_wrong_reason_for_category_fails(self):
        self.manifest['NSPrivacyAccessedAPITypes'][0]['NSPrivacyAccessedAPITypeReasons'] = ['35F9.1']
        self.rejects(self.manifest)

    def test_blanket_and_unknown_reasons_fail(self):
        for reasons in [[], ['*'], ['CA92.1', '1C8F.1'], ['unknown']]:
            self.manifest['NSPrivacyAccessedAPITypes'][0]['NSPrivacyAccessedAPITypeReasons'] = reasons
            self.rejects(self.manifest)

    def test_unused_categories_fail(self):
        for category in ['FileTimestamp', 'DiskSpace', 'ActiveKeyboards']:
            value = copy.deepcopy(self.manifest)
            value['NSPrivacyAccessedAPITypes'].append({
                'NSPrivacyAccessedAPIType': policy.API_PREFIX + category,
                'NSPrivacyAccessedAPITypeReasons': ['C617.1']})
            self.rejects(value)

    def test_duplicate_category_fails(self):
        self.manifest['NSPrivacyAccessedAPITypes'].append(self.manifest['NSPrivacyAccessedAPITypes'][0])
        self.rejects(self.manifest)

    def test_tracking_claim_fails(self):
        self.manifest['NSPrivacyTracking'] = True
        self.rejects(self.manifest)

    def test_tracking_domain_fails(self):
        self.manifest['NSPrivacyTrackingDomains'] = ['example.invalid']
        self.rejects(self.manifest)

    def test_every_known_collected_type_is_required(self):
        for index in range(len(self.manifest['NSPrivacyCollectedDataTypes'])):
            value = copy.deepcopy(self.manifest)
            del value['NSPrivacyCollectedDataTypes'][index]
            self.rejects(value)

    def test_linkage_tracking_and_purpose_are_not_weakened(self):
        for key, replacement in [('Linked', False), ('Tracking', True),
                                 ('Purposes', ['NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising'])]:
            value = copy.deepcopy(self.manifest)
            value['NSPrivacyCollectedDataTypes'][0][policy.DATA_PREFIX + key] = replacement
            self.rejects(value)

    def test_extra_or_duplicate_collected_type_fails(self):
        row = copy.deepcopy(self.manifest['NSPrivacyCollectedDataTypes'][0])
        for kind in ['Name', 'DeviceID', 'SensitiveInfo']:
            value = copy.deepcopy(self.manifest)
            row[policy.DATA_PREFIX] = policy.DATA_PREFIX + kind
            value['NSPrivacyCollectedDataTypes'].append(copy.deepcopy(row))
            self.rejects(value)

    def test_secrets_and_environment_values_are_not_valid_schema(self):
        for key in ['token', 'password', 'client_secret', 'environment', 'email', 'path']:
            value = copy.deepcopy(self.manifest)
            value[key] = 'synthetic-forbidden-value'
            self.rejects(value)

    def test_artifact_source_divergence_fails(self):
        self.manifest['NSPrivacyCollectedDataTypes'].pop()
        self.write(self.app / 'PrivacyInfo.xcprivacy', self.manifest)
        with self.assertRaises(policy.PrivacyError):
            policy.verify_artifact(self.app)

    def test_unsigned_app_rejected_when_signature_required(self):
        with self.assertRaises(policy.PrivacyError):
            policy.verify_artifact(self.app, require_signed=True)

    def test_new_framework_requires_audit(self):
        (self.app / 'Frameworks/New.framework').mkdir(parents=True)
        with self.assertRaises(policy.PrivacyError):
            policy.verify_artifact(self.app)

    def test_source_inventory_change_fails(self):
        changed = copy.deepcopy(policy.INVENTORY)
        changed['DiskSpace']['New.swift'] = 1
        with patch.object(policy, 'inventory', return_value=changed):
            with self.assertRaises(policy.PrivacyError):
                policy.verify_source()

    def test_every_category_scanner_catches_representative_new_use(self):
        root = Path(self.temp.name)
        source = root / 'Kairo/New.swift'
        source.parent.mkdir()
        source.write_text('UserDefaults.standard; ProcessInfo.processInfo.systemUptime; '
                          'url.creationDateKey; statfs(); UITextInputMode.activeInputModes')
        self.assertTrue(all(policy.inventory(root).values()))

    def test_missing_target_membership_fails(self):
        original = Path.read_text
        def altered(path, *args, **kwargs):
            text = original(path, *args, **kwargs)
            return text.replace('fileSystemSynchronizedGroups', 'detachedGroups') if path.name == 'project.pbxproj' else text
        with patch.object(Path, 'read_text', altered):
            with self.assertRaises(policy.PrivacyError):
                policy.verify_source()

    def test_size_only_access_does_not_declare_timestamp(self):
        self.assertEqual(policy.inventory(policy.ROOT)['FileTimestamp'], {})
        self.assertNotIn('FileTimestamp', policy.REASONS)


if __name__ == '__main__':
    unittest.main()
