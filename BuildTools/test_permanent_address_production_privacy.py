"""Offline production-capability boundaries. Never contacts a service or device."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
ADDRESS = ROOT / "Kairo/Features/PermanentAddress"


class PermanentAddressProductionPrivacyTests(unittest.TestCase):
    def test_production_capability_keeps_demo_and_test_isolation(self):
        source = (ROOT / "Kairo/App/AppDependencies.swift").read_text()
        self.assertIn("permanentAddressService: [.staging, .production].contains(configuration.environment) && !configuration.isDemoModeEnabled && !uiTestConfiguration.isEnabled", source)
        self.assertIn("let uiTestConfiguration = uiTestConfiguration.validated(for: configuration)", source)
        self.assertIn("baseURL: configuration.apiBaseURL", source)

    def test_server_day_not_device_calendar_controls_actions(self):
        source = (ADDRESS / "PermanentAddressStore.swift").read_text()
        self.assertIn("state?.canStartLocation == true", source)
        self.assertIn("guard actionsAvailable", source)
        for forbidden in ("Calendar", "Date()", "successfulGpsChecks +=", "todayComplete =", "UserDefaults"):
            self.assertNotIn(forbidden, source)
        collector = (ADDRESS / "AddressLocationCollector.swift").read_text()
        self.assertIn("nowUptime - uptime >= 60", collector)
        self.assertIn("count < 10", collector)
        self.assertLess(collector.index("challenge = try await service.start"), collector.index("samples = try await collector.collect"))

    def test_stale_backend_state_cannot_authorize_mutation(self):
        source = (ADDRESS / "PermanentAddressStore.swift").read_text()
        self.assertIn("stateIsCurrent && state?.enabled == true && !busy", source)
        self.assertIn("busy = true; error = nil; stateIsCurrent = false", source)
        view = (ADDRESS / "PermanentAddressView.swift").read_text()
        self.assertIn(".disabled(!model.actionsAvailable || state.canStartLocation != true)", view)
        self.assertIn(".disabled(!model.actionsAvailable || !address.isValid)", view)

    def test_review_enum_and_storage_details_never_render_directly(self):
        view = (ADDRESS / "PermanentAddressView.swift").read_text()
        for forbidden in ("Text(state.manualReviewStatus", "Text(state.targetSource", "uploadUrl", "objectKey", "reviewerId"):
            self.assertNotIn(forbidden, view)
        self.assertIn("state.reviewMessage", view)
        self.assertIn("state.firstCheckMessage", view)
        self.assertIn("This does not change your Trust Score", view)


if __name__ == "__main__":
    unittest.main()
