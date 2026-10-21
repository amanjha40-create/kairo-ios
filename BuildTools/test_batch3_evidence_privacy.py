"""Offline guards for the Batch 3 presentation and isolated physical QA boundary."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Batch3EvidencePrivacyTests(unittest.TestCase):
    def test_fixture_reuses_disabled_by_default_development_gate(self):
        app = (ROOT / 'Kairo/App/KairoApp.swift').read_text()
        self.assertIn('LocalBatch1QA.mode("batch3Evidence", configuration: configuration)', app)
        gate = (ROOT / 'Kairo/App/LocalBatch1QA.swift').read_text()
        self.assertIn('#if KAIRO_LOCAL_BATCH1_QA', gate)
        self.assertIn('"get-task-allow"] as? Bool == true', gate)

    def test_fixture_has_no_network_credentials_or_file_access(self):
        fixture = (ROOT / 'Kairo/App/LocalBatch3EvidenceQA.swift').read_text()
        for forbidden in ['URLSession', 'sendAuthenticated', 'SecItem', 'KeychainTokenStore',
                          'contentsOf:', '.write(', 'https://', 'print(', 'Logger(', 'UIApplication.shared.open']:
            self.assertNotIn(forbidden, fixture)

    def test_synthetic_selection_requires_compile_and_runtime_gate(self):
        view = (ROOT / 'Kairo/Features/Career/CareerDocumentsView.swift').read_text()
        self.assertIn('#if KAIRO_LOCAL_BATCH1_QA', view)
        self.assertIn('LocalBatch1QA.mode("batch3Evidence", configuration: .resolve())', view)

    def test_connection_is_unique_and_precedes_secondary_sections(self):
        view = (ROOT / 'Kairo/Features/DigiLocker/DigiLockerViews.swift').read_text()
        hub = view.split('struct DigiLockerHubView: View', 1)[1]
        self.assertEqual(hub.count('accessibilityIdentifier: "candidate.digilocker.connect"'), 1)
        self.assertLess(hub.index('                    connectionSection'), hub.index('                    savedSection'))
        self.assertNotIn('Task { connect()', hub)

    def test_review_does_not_log_urls_or_claim_verification(self):
        view = (ROOT / 'Kairo/DesignSystem/Components/EvidenceTypeSelector.swift').read_text()
        for forbidden in ['print(', 'Logger(', 'uploadUrl', 'downloadUrl', 'UserDefaults']:
            self.assertNotIn(forbidden, view)
        self.assertIn('does not submit verification', view)


if __name__ == '__main__':
    unittest.main()
