import XCTest
@testable import Kairo

final class ManualProfileFlowStateTests: XCTestCase {
    func test_basicProfileRequiresCityAndCountry() {
        let draft = ManualProfileBasicDraft(
            fullName: "",
            professionalHeadline: "Trust Operations Specialist",
            currentRole: "",
            industry: "",
            yearsOfExperience: "",
            currentCity: "",
            currentCountry: ""
        )

        XCTAssertEqual(
            ManualProfileValidation.basicProfileError(for: .fullName, in: draft),
            "Enter your full name."
        )
        XCTAssertEqual(
            ManualProfileValidation.basicProfileError(for: .currentRole, in: draft),
            "Enter your current role."
        )
        XCTAssertEqual(
            ManualProfileValidation.basicProfileError(for: .industry, in: draft),
            "Enter your industry."
        )
        XCTAssertEqual(
            ManualProfileValidation.basicProfileError(for: .yearsOfExperience, in: draft),
            "Enter your years of experience."
        )
        XCTAssertEqual(
            ManualProfileValidation.basicProfileError(for: .currentCity, in: draft),
            "Enter your current city."
        )
        XCTAssertEqual(
            ManualProfileValidation.basicProfileError(for: .currentCountry, in: draft),
            "Enter your current country."
        )
        XCTAssertFalse(ManualProfileValidation.isBasicProfileValid(draft))
    }

    func test_validBasicProfileAdvancesToEmployment() {
        var state = ManualProfileFlowState()
        state.basicProfile = ManualProfileBasicDraft(
            fullName: "Aman Jha",
            professionalHeadline: "Trust Operations Specialist",
            currentRole: "Trust Operations Specialist",
            industry: "Technology",
            yearsOfExperience: "4",
            currentCity: "Bengaluru",
            currentCountry: "India"
        )

        XCTAssertTrue(state.canContinue)

        state.advance()

        XCTAssertEqual(state.step, .employment)
    }

    func test_addEmploymentAppendsBlankEntry() {
        var state = ManualProfileFlowState(step: .employment)

        state.addEmployment()

        XCTAssertEqual(state.employmentEntries.count, 2)
        XCTAssertEqual(state.employmentEntries[1].company, "")
    }

    func test_deleteEmploymentRemovesAdditionalEntry() {
        var state = ManualProfileFlowState(step: .employment)
        state.addEmployment()
        let addedEntryID = state.employmentEntries[1].id

        state.deleteEmployment(id: addedEntryID)

        XCTAssertEqual(state.employmentEntries.count, 1)
        XCTAssertNotEqual(state.employmentEntries[0].id, addedEntryID)
    }

    func test_deleteSingleEmploymentClearsEntryButKeepsScreenStable() {
        var state = ManualProfileFlowState(step: .employment)
        let originalID = state.employmentEntries[0].id
        state.updateEmployment(id: originalID) { entry in
            entry.company = "Meridian Trust"
            entry.jobTitle = "Trust Operations Specialist"
        }

        state.deleteEmployment(id: originalID)

        XCTAssertEqual(state.employmentEntries.count, 1)
        XCTAssertEqual(state.employmentEntries[0].id, originalID)
        XCTAssertEqual(state.employmentEntries[0].company, "")
        XCTAssertEqual(state.employmentEntries[0].jobTitle, "")
    }

    func test_currentlyWorkingEmploymentClearsEndDateAndValidates() {
        var entry = ManualEmploymentEntry.blank(id: 0)
        entry.company = "Meridian Trust"
        entry.jobTitle = "Trust Operations Specialist"
        entry.employmentType = "Full-time"
        entry.workCountry = "India"
        entry.startDay = "1"
        entry.startMonth = "January"
        entry.startYear = "2022"
        entry.endDay = "31"
        entry.endMonth = "March"
        entry.endYear = "2024"

        var state = ManualProfileFlowState(step: .employment, employmentEntries: [entry])
        state.updateEmployment(id: 0) { currentEntry in
            currentEntry.isCurrentlyWorking = true
        }

        XCTAssertEqual(state.employmentEntries[0].endMonth, "")
        XCTAssertEqual(state.employmentEntries[0].endYear, "")
        XCTAssertTrue(ManualProfileValidation.isEmploymentEntryValid(state.employmentEntries[0]))
    }

    func test_employmentValidationRejectsEndDateBeforeStartDate() {
        let entry = ManualEmploymentEntry(
            id: 0,
            company: "Meridian Trust",
            jobTitle: "Trust Operations Specialist",
            employmentType: "Full-time",
            workCountry: "India",
            startDay: "1",
            startMonth: "January",
            startYear: "2024",
            endDay: "31",
            endMonth: "December",
            endYear: "2023",
            isCurrentlyWorking: false
        )

        XCTAssertEqual(
            ManualProfileValidation.employmentError(for: .endYear, in: entry),
            "End date must be after the start date."
        )
        XCTAssertFalse(ManualProfileValidation.isEmploymentEntryValid(entry))
    }

    func test_addAndDeleteEducationEntries() {
        var state = ManualProfileFlowState(step: .education)

        state.addEducation()
        let secondID = state.educationEntries[1].id

        XCTAssertEqual(state.educationEntries.count, 2)

        state.deleteEducation(id: secondID)

        XCTAssertEqual(state.educationEntries.count, 1)
    }

    func test_validEmploymentAdvancesToEducation() {
        var state = ManualProfileFlowState(step: .employment)
        state.updateEmployment(id: 0) { entry in
            entry.company = "Meridian Trust"
            entry.jobTitle = "Trust Operations Specialist"
            entry.employmentType = "Full-time"
            entry.workCountry = "India"
            entry.startDay = "1"
            entry.startMonth = "January"
            entry.startYear = "2022"
            entry.isCurrentlyWorking = true
        }

        XCTAssertTrue(state.canContinue)

        state.advance()

        XCTAssertEqual(state.step, .education)
    }

    func test_persistedEmploymentEntriesCanContinueWithoutReentry() {
        let state = ManualProfileFlowState(
            step: .employment,
            employmentEntries: [
                ManualEmploymentEntry(
                    id: 0,
                    isPersisted: true,
                    company: "Northstar Analytics Private Limited",
                    jobTitle: "Product Operations Manager",
                    employmentType: "Other",
                    workCountry: "",
                    startDay: "",
                    startMonth: "",
                    startYear: "",
                    endDay: "",
                    endMonth: "",
                    endYear: "",
                    isCurrentlyWorking: true
                )
            ]
        )

        XCTAssertTrue(state.canContinue)
        XCTAssertTrue(ManualProfileValidation.areEmploymentEntriesValid(state.employmentEntries))
    }

    func test_employmentValidationAcceptsMonthWithInvisibleSeparatorCharacters() {
        let entry = ManualEmploymentEntry(
            id: 0,
            company: "Meridian Trust",
            jobTitle: "Trust Operations Specialist",
            employmentType: "Full-time",
            workCountry: "India",
            startDay: "1",
            startMonth: "Ja\u{200B}nuary",
            startYear: "2022",
            endDay: "",
            endMonth: "",
            endYear: "",
            isCurrentlyWorking: true
        )

        XCTAssertNil(ManualProfileValidation.employmentError(for: .startMonth, in: entry))
        XCTAssertTrue(ManualProfileValidation.isEmploymentEntryValid(entry))
    }

    func test_validEducationAllowsFinalContinue() {
        var state = ManualProfileFlowState(step: .education)
        state.updateEducation(id: 0) { entry in
            entry.institution = "Delhi Institute of Technology"
            entry.degree = "B.Tech"
            entry.educationLevel = "Bachelor's"
            entry.fieldOfStudy = "Information Technology"
            entry.startYear = "2016"
            entry.endYear = "2020"
        }

        XCTAssertTrue(state.canContinue)
        XCTAssertTrue(ManualProfileValidation.areEducationEntriesValid(state.educationEntries))
    }

    func test_persistedEducationEntriesCanContinueWithoutReentry() {
        let state = ManualProfileFlowState(
            step: .education,
            educationEntries: [
                ManualEducationEntry(
                    id: 0,
                    isPersisted: true,
                    institution: "Riverdale Institute of Technology",
                    degree: "Bachelor of Technology (B.Tech)",
                    educationLevel: "Bachelor's",
                    fieldOfStudy: "Information Technology",
                    startYear: "",
                    endYear: ""
                )
            ]
        )

        XCTAssertTrue(state.canContinue)
        XCTAssertTrue(ManualProfileValidation.areEducationEntriesValid(state.educationEntries))
    }

    func test_reconcileBasicProfilePrefillUsesBackendNameWhenDraftEmpty() {
        var state = ManualProfileFlowState()

        state.reconcileBasicProfilePrefill(
            backendFullName: "Aman Jha",
            signupDraftFullName: "Ignored Signup Name"
        )

        XCTAssertEqual(state.basicProfile.fullName, "Aman Jha")
    }

    func test_reconcileBasicProfilePrefillUsesSignupNameWhenBackendMissing() {
        var state = ManualProfileFlowState()

        state.reconcileBasicProfilePrefill(
            backendFullName: nil,
            signupDraftFullName: "Aman Jha"
        )

        XCTAssertEqual(state.basicProfile.fullName, "Aman Jha")
    }

    func test_reconcileBasicProfilePrefillPreservesExistingDraftName() {
        var state = ManualProfileFlowState()
        state.basicProfile.fullName = "Local Draft Name"

        state.reconcileBasicProfilePrefill(
            backendFullName: "Backend Name",
            signupDraftFullName: "Signup Name"
        )

        XCTAssertEqual(state.basicProfile.fullName, "Local Draft Name")
    }

    func test_manualProfileDraftCodingRoundTripPreservesFullName() throws {
        let state = ManualProfileFlowState(
            basicProfile: ManualProfileBasicDraft(
                fullName: "Aman Jha",
                professionalHeadline: "Trust Operations Specialist",
                currentRole: "Trust Operations Specialist",
                industry: "Technology",
                yearsOfExperience: "4",
                currentCity: "Bengaluru",
                currentCountry: "India"
            )
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ManualProfileFlowState.self, from: data)

        XCTAssertEqual(decoded.basicProfile.fullName, "Aman Jha")
    }

    func test_completedResumeImportHandoffSwitchesBranchAndClearsResumeImportState() {
        var onboardingState = OnboardingFlowState(
            chooseStartState: ChooseStartState(selection: .importResume),
            resumeImportState: ResumeImportState(
                phase: .readyForReview,
                selectedFile: try? ResumeImportFile.make(
                    from: URL(fileURLWithPath: "resume.pdf"),
                    fileSizeOverride: 240_000
                ),
                restorationAttempted: true
            )
        )
        let manualProfileState = ManualProfileFlowState(
            basicProfile: ManualProfileBasicDraft(
                fullName: "Resume QA",
                professionalHeadline: "Product Operations Manager",
                currentRole: "",
                industry: "",
                yearsOfExperience: "",
                currentCity: "Bengaluru",
                currentCountry: "India"
            )
        )

        onboardingState.applyCompletedResumeImportHandoff(manualProfileState: manualProfileState)

        XCTAssertEqual(onboardingState.chooseStartState.selection, .buildProfileManually)
        XCTAssertEqual(onboardingState.manualProfileState, manualProfileState)
        XCTAssertEqual(onboardingState.resumeImportState, ResumeImportState())
    }
}
