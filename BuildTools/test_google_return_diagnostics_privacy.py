"""Observability-only release contract; no provider or device calls."""
import json
from pathlib import Path
import plistlib
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GoogleReturnDiagnosticsPrivacyTests(unittest.TestCase):
    def test_logger_has_only_typed_safe_inputs_and_release_visibility(self):
        source = (ROOT / "Kairo/Core/Auth/GoogleReturnDiagnostics.swift").read_text()
        self.assertIn('logger.notice', source)
        self.assertIn('@TaskLocal static var deliveryAttemptID: UUID?', source)
        for forbidden in ('#if DEBUG', 'UserDefaults', 'FileManager', 'URLSession', 'absoluteString', 'localizedDescription', 'handoffCode', 'accessToken', 'refreshToken'):
            self.assertNotIn(forbidden, source)
        for event in ('APP_LAUNCH', 'SCENE_ACTIVE', 'OPENURL_RECEIVED', 'USER_ACTIVITY_RECEIVED', 'LINK_VALIDATED', 'ROUTER_RECEIVED', 'PRESENTATION_CREATED', 'EXCHANGE_STARTED', 'EXCHANGE_RESPONSE', 'BOOTSTRAP_STARTED', 'BOOTSTRAP_SUCCEEDED', 'AUTH_ROOT_CHANGED'):
            self.assertIn('IOS_OAUTH_' + event, source)

    def test_production_plist_changes_only_export_declaration(self):
        base = plistlib.loads((ROOT / 'Kairo-Info.plist').read_bytes())
        prod = plistlib.loads((ROOT / 'Kairo-Production-Info.plist').read_bytes())
        self.assertIs(prod.pop('ITSAppUsesNonExemptEncryption'), False)
        self.assertEqual(prod, base)
        objects = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(ROOT / 'Kairo.xcodeproj/project.pbxproj')]))['objects']
        configs = [v for v in objects.values() if v.get('isa') == 'XCBuildConfiguration' and 'KAIRO_BUILD_CONFIGURATION' in v.get('buildSettings', {})]
        for config in configs:
            settings = config['buildSettings']
            if config['name'] == 'Production':
                self.assertEqual(settings['INFOPLIST_FILE'], 'Kairo-Production-Info.plist')
                self.assertEqual(str(settings['CURRENT_PROJECT_VERSION']), '2')
            else:
                self.assertEqual(settings['INFOPLIST_FILE'], 'Kairo-Info.plist')
                self.assertEqual(str(settings['CURRENT_PROJECT_VERSION']), '1')
            self.assertEqual(settings['MARKETING_VERSION'], '1.0')

    def test_delivery_id_never_added_to_network_request(self):
        source = (ROOT / 'Kairo/Core/Networking/URLSessionNetworkClient.swift').read_text()
        request_builder = source.split('func makeURLRequest')[1]
        self.assertNotIn('deliveryAttemptID', request_builder)
        self.assertNotIn('GoogleReturnDiagnostics', request_builder)
        self.assertIn('UUID.init(uuidString:)', source)

    def test_known_defects_remain_explicit(self):
        evidence = json.loads((ROOT / 'BuildTools/google-return-known-defects.json').read_text())
        self.assertFalse(evidence['behavior_changed'])
        self.assertFalse(evidence['explains_original_zero_exchange_failure'])
        self.assertEqual(len(evidence['gate_exclusions_run_separately_as_red_witnesses']), 2)
