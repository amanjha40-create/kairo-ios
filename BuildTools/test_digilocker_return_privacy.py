"""Offline build/source contract checks; no provider or account access."""
from pathlib import Path
import json
import plistlib
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DigiLockerReturnPrivacyTests(unittest.TestCase):
    def test_configuration_specific_registration(self):
        info = plistlib.loads((ROOT / 'Kairo-Info.plist').read_bytes())
        self.assertEqual(info['CFBundleURLTypes'][0]['CFBundleURLSchemes'],
                         ['$(KAIRO_DIGILOCKER_RETURN_SCHEME)'])
        objects = json.loads(subprocess.check_output([
            'plutil', '-convert', 'json', '-o', '-',
            str(ROOT / 'Kairo.xcodeproj/project.pbxproj')
        ]))['objects']
        configs = [value for value in objects.values()
                   if value.get('isa') == 'XCBuildConfiguration']
        for configuration, scheme in [('Staging', 'com.kairoid.staging.digilocker'),
                                      ('Production', 'com.kairoid.digilocker')]:
            matches = [value['buildSettings'] for value in configs
                       if value.get('name') == configuration
                       and value.get('buildSettings', {}).get('KAIRO_BUILD_CONFIGURATION') == configuration]
            self.assertEqual(len(matches), 1)
            self.assertEqual(matches[0]['KAIRO_DIGILOCKER_RETURN_SCHEME'], scheme)

    def test_callback_has_no_logging_or_exchange(self):
        source = (ROOT / 'Kairo/Features/DigiLocker/DigiLockerAuthentication.swift').read_text()
        for forbidden in ('print(', 'Logger(', 'NSLog(', 'access_token', 'refresh_token',
                          'client_secret', 'URLSession', 'code_verifier'):
            self.assertNotIn(forbidden, source)
        self.assertIn('callbackURLScheme: scheme', source)
        self.assertIn('callback: .customScheme(scheme)', source)
        self.assertIn('environment: environment', source)

    def test_no_new_global_digilocker_router(self):
        source = (ROOT / 'Kairo/Core/Navigation/AppRouter.swift').read_text()
        self.assertNotIn('DigiLockerReturnParser', source)
        self.assertNotIn('com.kairoid.digilocker', source)

    def test_no_associated_domain_or_team_dependency(self):
        source = (ROOT / 'Kairo/Features/DigiLocker/DigiLockerAuthentication.swift').read_text()
        self.assertNotIn('XN5Y3V3CSV', source)
        self.assertNotIn('applinks:', source)
        self.assertNotIn('prefersEphemeralWebBrowserSession', source)
        self.assertNotRegex(source, r'https://api\.kairoid\.com.*callback')

    def test_production_uses_same_session_flow(self):
        source = (ROOT / 'Kairo/Features/DigiLocker/DigiLockerViews.swift').read_text()
        self.assertIn('if DigiLockerReturnParser.scheme(for: configuration.environment) != nil', source)
        self.assertIn('authentication.connect(environment: configuration.environment', source)
        self.assertIn('store.finishAuthentication(outcome, revision: revision)', source)


if __name__ == '__main__':
    unittest.main()
