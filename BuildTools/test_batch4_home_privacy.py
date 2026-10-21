"""Offline guards for the presentation-only Batch 4 boundary."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Batch4HomePrivacyTests(unittest.TestCase):
    def test_new_fixture_route_requires_validated_test_configuration(self):
        shell = (ROOT / 'Kairo/Features/MainTabs/CandidateTabShellView.swift').read_text()
        self.assertIn('UITestLaunchConfiguration.current().validated(for: appConfiguration).isEnabled,', shell)
        self.assertIn('KAIRO_UI_TEST_BATCH4_HOME', shell)
        gate = (ROOT / 'Kairo/App/LocalBatch1QA.swift').read_text()
        self.assertIn('#if KAIRO_LOCAL_BATCH1_QA', gate)
        self.assertIn('"get-task-allow"] as? Bool == true', gate)

    def test_home_fixtures_have_no_transport_or_persistence(self):
        fixture = (ROOT / 'Kairo/Features/Home/Batch4HomeFixtures.swift').read_text()
        for forbidden in ['URLSession', 'Keychain', 'SecItem', 'UserDefaults', 'https://',
                          'sendAuthenticated', 'print(', 'Logger(', '.write(']:
            self.assertNotIn(forbidden, fixture)

    def test_existing_routes_and_tour_anchors_preserved(self):
        home = (ROOT / 'Kairo/Features/Home/HomeOverviewScreenView.swift').read_text()
        for required in ['router.showNotificationCenter()', 'router.selectTab(.passport)',
                         'router.showPassportActivity()', 'DocumentsHubView()',
                         '.guidedTourTarget(.trustScore)', '.guidedTourTarget(.passport)',
                         'request.authoritativeDestinationID', 'refreshStore.focusVerificationRequest']:
            self.assertIn(required, home)

    def test_home_orders_work_before_optional_destinations_and_history(self):
        home = (ROOT / 'Kairo/Features/Home/HomeOverviewScreenView.swift').read_text()
        dashboard = home.split('private func dashboard(', 1)[1].split('private func trustScoreCard', 1)[0]
        ordered = ['trustScoreCard(', 'verificationRequestsSection(', 'requestGroup(',
                   'careerSection(', 'DigiLockerHomeCard()', 'PermanentAddressEntry()',
                   'recentActivitySection(', 'recentPassportViewsSection(']
        positions = [dashboard.index(item) for item in ordered]
        self.assertEqual(positions, sorted(positions))

    def test_surface_has_no_motion_or_data_semantics(self):
        surface = (ROOT / 'Kairo/DesignSystem/Components/KairoTonalSurface.swift').read_text()
        for forbidden in ['Task {', 'onAppear', 'animation(', 'URLSession', 'UserDefaults']:
            self.assertNotIn(forbidden, surface)

    def test_decorative_icons_fit_columns_without_capping_readable_text(self):
        source = (ROOT / 'Kairo/DesignSystem/Components/KairoProductComponents.swift').read_text()
        row = source.split('struct KairoCompactDestinationRow', 1)[1].split('struct KairoSectionHeading', 1)[0]
        self.assertIn('.scaledToFit()', row)
        self.assertIn('.frame(width: 24, height: 24)', row)
        self.assertNotIn('.dynamicTypeSize(', row)
        self.assertIn('.font(KairoTypography.recordTitle)', row)
        self.assertIn('.font(KairoTypography.metadata)', row)


if __name__ == '__main__':
    unittest.main()
