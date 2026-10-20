"""Offline checks for the Batch 2 form-only boundary and local QA isolation."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Batch2FormPrivacyTests(unittest.TestCase):
    def test_form_fixture_is_behind_existing_development_gate(self):
        source = (ROOT / 'Kairo/App/KairoApp.swift').read_text()
        self.assertIn('LocalBatch1QA.mode("batch2Forms", configuration: configuration)', source)
        gate = (ROOT / 'Kairo/App/LocalBatch1QA.swift').read_text()
        self.assertIn('#if KAIRO_LOCAL_BATCH1_QA', gate)
        self.assertIn('"get-task-allow"] as? Bool == true', gate)

    def test_fixture_has_no_service_or_account_access(self):
        source = (ROOT / 'Kairo/App/LocalBatch2FormQA.swift').read_text()
        for forbidden in ['URLSession', 'Keychain', 'SecItem', 'sessionStore', 'UserDefaults',
                          'print(', 'Logger(', 'https://', 'TokenStore', 'Service(']:
            self.assertNotIn(forbidden, source)

    def test_pickers_are_local_and_do_not_log(self):
        for name in ['CandidateDateField', 'CandidateLocationFields']:
            source = (ROOT / f'Kairo/DesignSystem/Components/{name}.swift').read_text()
            for forbidden in ['URLSession', 'https://', 'print(', 'Logger(', 'UserDefaults']:
                self.assertNotIn(forbidden, source)

    def test_date_confirmation_is_explicit(self):
        source = (ROOT / 'Kairo/DesignSystem/Components/CandidateDateField.swift').read_text()
        self.assertIn('draft = selection ?? Date()', source)
        self.assertIn('Button("Cancel") { presented = false }', source)
        self.assertIn('Button("Use date")', source)
        self.assertNotIn('.onAppear', source)


if __name__ == '__main__':
    unittest.main()
