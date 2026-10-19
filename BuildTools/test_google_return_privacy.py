"""Offline configuration/routing invariants; no provider or account access."""
import json
from pathlib import Path
import plistlib
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GoogleReturnPrivacyTests(unittest.TestCase):
    def test_entitlement_is_only_the_production_applink_domain(self):
        with (ROOT / 'Kairo-Production.entitlements').open('rb') as handle:
            self.assertEqual(plistlib.load(handle), {
                'com.apple.developer.associated-domains': ['applinks:api.kairoid.com']})

    def test_only_app_production_configuration_uses_entitlement(self):
        project = json.loads(subprocess.check_output([
            '/usr/bin/plutil', '-convert', 'json', '-o', '-',
            str(ROOT / 'Kairo.xcodeproj/project.pbxproj')]))
        objects = project['objects']
        target = next(obj for obj in objects.values()
                      if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'Kairo')
        configs = objects[target['buildConfigurationList']]['buildConfigurations']
        for key in configs:
            config = objects[key]
            settings = config['buildSettings']
            self.assertEqual(settings['PRODUCT_BUNDLE_IDENTIFIER'], 'com.kairoid.Kairo')
            if config['name'] == 'Production':
                self.assertEqual(settings['CODE_SIGN_ENTITLEMENTS'], 'Kairo-Production.entitlements')
                self.assertEqual(settings['DEVELOPMENT_TEAM'], 'MVT4T97ZGC')
            else:
                self.assertNotIn('CODE_SIGN_ENTITLEMENTS', settings)
                self.assertNotIn('DEVELOPMENT_TEAM', settings)

    def test_aasa_only_authorizes_verified_app_and_exact_handoff_path(self):
        payload = json.loads((ROOT / 'BuildTools/AssociatedDomains/api.kairoid.com/apple-app-site-association').read_text())
        self.assertEqual(payload, {'applinks': {'details': [{
            'appIDs': ['MVT4T97ZGC.com.kairoid.Kairo'],
            'components': [{'/': '/auth/google/complete'}]}]}})

    def test_native_universal_link_dispatch_and_existing_exchange_are_retained(self):
        root = (ROOT / 'Kairo/App/AppRootView.swift').read_text()
        self.assertIn('.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)', root)
        self.assertIn('routeIncomingURL(url, entry: .openURLReceived)', root)
        self.assertIn('routeIncomingURL(url, entry: .userActivityReceived)', root)
        self.assertIn('guard let url = activity.webpageURL else {', root)
        self.assertIn('router.handleIncomingURL(url, configuration: appConfiguration, diagnosticDeliveryID: deliveryID)', root)
        flow = (ROOT / 'Kairo/Features/Onboarding/GoogleAuthenticationFlow.swift').read_text()
        self.assertIn('authService.exchangeGoogleHandoff(', flow)
        self.assertIn('sessionStore.completeAuthenticationAndRoute()', flow)
        self.assertIn('guard !hasStarted, router.beginGoogleHandoffExchange(presentation) else { return }', flow)
        for forbidden in ('print(', 'debugPrint(', 'NSLog(', 'Logger(', 'client_id='):
            self.assertNotIn(forbidden, flow)

    def test_handoff_descriptions_redact_codes_and_parser_rejects_extra_queries(self):
        source = (ROOT / 'Kairo/Core/Navigation/AppLinkRouting.swift').read_text()
        self.assertIn('code: <redacted>', source)
        self.assertIn('handoffCode: <redacted>', source)
        self.assertIn('queryItems.count == 1', source)
        self.assertIn('url.fragment == nil', source)


if __name__ == '__main__':
    unittest.main()
