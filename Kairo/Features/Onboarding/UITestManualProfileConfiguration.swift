import Foundation

struct UITestManualProfileConfiguration {
    enum EnvironmentKey {
        static let phase = "KAIRO_UI_TEST_MANUAL_PROFILE_PHASE"
        static let prefill = "KAIRO_UI_TEST_MANUAL_PROFILE_PREFILL"
        static let extraEmploymentEntries = "KAIRO_UI_TEST_MANUAL_PROFILE_EXTRA_EMPLOYMENT"
        static let extraEducationEntries = "KAIRO_UI_TEST_MANUAL_PROFILE_EXTRA_EDUCATION"
    }

    let isActive: Bool
    let state: ManualProfileFlowState

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestManualProfileConfiguration {
        let launchConfiguration = UITestLaunchConfiguration.current(
            arguments: arguments,
            environment: environment
        )

        guard launchConfiguration.isEnabled,
              let phase = ManualProfileStep(rawValue: environment[EnvironmentKey.phase] ?? "") else {
            return UITestManualProfileConfiguration(
                isActive: false,
                state: ManualProfileFlowState()
            )
        }

        let prefill = parseBool(environment[EnvironmentKey.prefill]) ?? true
        let extraEmploymentEntries = max(Int(environment[EnvironmentKey.extraEmploymentEntries] ?? "0") ?? 0, 0)
        let extraEducationEntries = max(Int(environment[EnvironmentKey.extraEducationEntries] ?? "0") ?? 0, 0)

        return UITestManualProfileConfiguration(
            isActive: true,
            state: seededState(
                phase: phase,
                prefill: prefill,
                extraEmploymentEntries: extraEmploymentEntries,
                extraEducationEntries: extraEducationEntries
            )
        )
    }

    private static func seededState(
        phase: ManualProfileStep,
        prefill: Bool,
        extraEmploymentEntries: Int,
        extraEducationEntries: Int
    ) -> ManualProfileFlowState {
        let basicProfile = ManualProfileBasicDraft(
            professionalHeadline: prefill ? "Trust Operations Specialist" : "",
            currentCity: prefill ? "Bengaluru" : "",
            currentCountry: prefill ? "India" : ""
        )

        let primaryEmployment = ManualEmploymentEntry(
            id: 0,
            company: prefill ? "Meridian Trust" : "",
            jobTitle: prefill ? "Trust Operations Specialist" : "",
            employmentType: prefill ? "Full-time" : "",
            startMonth: prefill ? "January" : "",
            startYear: prefill ? "2022" : "",
            endMonth: "",
            endYear: "",
            isCurrentlyWorking: prefill
        )

        let primaryEducation = ManualEducationEntry(
            id: 0,
            institution: prefill ? "Delhi Institute of Technology" : "",
            degree: prefill ? "B.Tech" : "",
            fieldOfStudy: prefill ? "Information Technology" : "",
            startYear: prefill ? "2016" : "",
            endYear: prefill ? "2020" : ""
        )

        var state = ManualProfileFlowState(
            step: phase,
            basicProfile: basicProfile,
            employmentEntries: [primaryEmployment],
            educationEntries: [primaryEducation],
            nextEmploymentID: 1,
            nextEducationID: 1
        )

        for _ in 0..<extraEmploymentEntries {
            state.addEmployment()
        }

        for _ in 0..<extraEducationEntries {
            state.addEducation()
        }

        if !prefill {
            switch phase {
            case .basicProfile:
                break
            case .employment:
                state.basicProfile = ManualProfileBasicDraft(
                    professionalHeadline: "Trust Operations Specialist",
                    currentCity: "Bengaluru",
                    currentCountry: "India"
                )
            case .education:
                state.basicProfile = ManualProfileBasicDraft(
                    professionalHeadline: "Trust Operations Specialist",
                    currentCity: "Bengaluru",
                    currentCountry: "India"
                )
                state.updateEmployment(id: 0) { entry in
                    entry.company = "Meridian Trust"
                    entry.jobTitle = "Trust Operations Specialist"
                    entry.employmentType = "Full-time"
                    entry.startMonth = "January"
                    entry.startYear = "2022"
                    entry.isCurrentlyWorking = true
                }
            }
        }

        return state
    }

    private static func parseBool(_ rawValue: String?) -> Bool? {
        guard let rawValue else {
            return nil
        }

        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }
}
