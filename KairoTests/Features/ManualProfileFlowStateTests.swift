import XCTest
@testable import Kairo

final class ManualProfileFlowStateTests: XCTestCase {
    func test_basicProfileRequiresCityAndCountry() {
        let draft = ManualProfileBasicDraft(
            professionalHeadline: "Trust Operations Specialist",
            currentCity: "",
            currentCountry: ""
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
            professionalHeadline: "Trust Operations Specialist",
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
        entry.startMonth = "January"
        entry.startYear = "2022"
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
            startMonth: "January",
            startYear: "2024",
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
            entry.startMonth = "January"
            entry.startYear = "2022"
            entry.isCurrentlyWorking = true
        }

        XCTAssertTrue(state.canContinue)

        state.advance()

        XCTAssertEqual(state.step, .education)
    }

    func test_validEducationAllowsFinalContinue() {
        var state = ManualProfileFlowState(step: .education)
        state.updateEducation(id: 0) { entry in
            entry.institution = "Delhi Institute of Technology"
            entry.degree = "B.Tech"
            entry.fieldOfStudy = "Information Technology"
            entry.startYear = "2016"
            entry.endYear = "2020"
        }

        XCTAssertTrue(state.canContinue)
        XCTAssertTrue(ManualProfileValidation.areEducationEntriesValid(state.educationEntries))
    }
}
