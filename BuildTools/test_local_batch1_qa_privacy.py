"""Offline guardrails for the explicitly approved local development QA harness."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LocalBatch1QAPrivacyTests(unittest.TestCase):
    def test_opt_in_compile_condition_is_not_a_project_or_release_setting(self):
        for path in [ROOT / 'Kairo.xcodeproj/project.pbxproj', *ROOT.rglob('*.xcconfig')]:
            self.assertNotIn('KAIRO_LOCAL_BATCH1_QA', path.read_text())
        source = (ROOT / 'Kairo/App/LocalBatch1QA.swift').read_text()
        self.assertIn('#if KAIRO_LOCAL_BATCH1_QA', source)
        self.assertIn('#else\n        return false\n#endif', source)
        self.assertIn('arguments.contains(argument)', source)
        self.assertIn('arguments.contains(UITestLaunchConfiguration.enabledArgument)', source)

    def test_device_gate_requires_development_profile_and_exact_identity(self):
        source = (ROOT / 'Kairo/App/LocalBatch1QA.swift').read_text()
        for required in ['"get-task-allow"] as? Bool == true', 'MVT4T97ZGC.com.kairoid.Kairo',
                         '"ProvisionedDevices"', 'expiry > now', 'permitsDevelopmentProfile(profile)']:
            self.assertIn(required, source)

    def test_harness_has_no_live_network_keychain_or_credential_logging(self):
        source = (ROOT / 'Kairo/App/LocalBatch1QA.swift').read_text()
        for forbidden in ['URLSession', 'Keychain', 'SecItem', 'print(', 'NSLog(', 'Logger(', 'https://']:
            self.assertNotIn(forbidden, source)
        dependencies = (ROOT / 'Kairo/App/AppDependencies.swift').read_text()
        self.assertIn('? InMemoryTokenStore()', dependencies)
        self.assertIn('? DemoNetworkClient()', dependencies)
        self.assertIn('uiTestConfiguration.validated(for: configuration)', dependencies)

    def test_fixture_preferences_and_drafts_are_isolated_and_cache_preserved(self):
        app = (ROOT / 'Kairo/App/KairoApp.swift').read_text()
        self.assertEqual(app.count('qaEnabled ? LocalBatch1QA.preferences : .standard'), 2)
        self.assertIn('if qaEnabled, let appearance = MoreAppearanceOption(', app)
        self.assertIn('appearanceStore.select(appearance)', app)
        draft = (ROOT / 'Kairo/Features/Onboarding/ManualProfileDraftStore.swift').read_text()
        self.assertIn('? LocalBatch1QA.preferences : .standard', draft)
        self.assertNotIn('UserDefaults.standard.', draft)
        session = (ROOT / 'Kairo/App/AppSessionStore.swift').read_text()
        self.assertIn('!LocalBatch1QA.isEnabled(configuration: configuration)', session)

    def test_postbuild8_persistence_is_disposable_local_qa_only(self):
        source = (ROOT / 'Kairo/App/LocalBatch2FormQA.swift').read_text()
        self.assertIn('UUID(uuidString: run) != nil', source)
        self.assertIn('#if KAIRO_LOCAL_BATCH1_QA\n/// Disposable local canonical store', source)
        self.assertIn('appendingPathComponent("PostBuild8SyntheticPersistence"', source)
        self.assertIn('if let change = patch[key] { canonical[key] = change }', source)
        self.assertIn('APIJSONCoder.makeEncoder().encode(request)', source)
        self.assertIn('try refetch()', source)
        for forbidden in ['URLSession', 'Keychain', 'SecItem', 'UserDefaults.standard', 'https://']:
            self.assertNotIn(forbidden, source)
        tests = (ROOT / 'KairoUITests/LocalBatch2FormUITests.swift').read_text()
        self.assertIn('app.terminate()', tests)
        self.assertIn('Wire: null; refetch: cleared', tests)
        self.assertIn('Refetched: cleared', tests)


if __name__ == '__main__':
    unittest.main()
