import Foundation

enum ManualProfileStep: String, Equatable, Sendable {
    case basicProfile
    case employment
    case education

    var stepLabel: String {
        switch self {
        case .basicProfile:
            "Step 1 of 3"
        case .employment:
            "Step 2 of 3"
        case .education:
            "Step 3 of 3"
        }
    }

    var title: String {
        switch self {
        case .basicProfile:
            "Build your profile"
        case .employment:
            "Employment"
        case .education:
            "Education"
        }
    }

    var subtitle: String {
        switch self {
        case .basicProfile:
            "Let's start with the basics."
        case .employment:
            "Add the roles that help define your professional trust."
        case .education:
            "Add the education that supports your Trust Passport."
        }
    }

    var titleAccessibilityIdentifier: String {
        switch self {
        case .basicProfile:
            KairoAccessibilityID.manualProfileTitle
        case .employment:
            KairoAccessibilityID.manualProfileEmploymentTitle
        case .education:
            KairoAccessibilityID.manualProfileEducationTitle
        }
    }
}

struct ManualProfileBasicDraft: Equatable, Sendable {
    var professionalHeadline = ""
    var currentCity = ""
    var currentCountry = ""
}

struct ManualEmploymentEntry: Equatable, Identifiable, Sendable {
    let id: Int
    var company = ""
    var jobTitle = ""
    var employmentType = ""
    var startMonth = ""
    var startYear = ""
    var endMonth = ""
    var endYear = ""
    var isCurrentlyWorking = false

    static func blank(id: Int) -> ManualEmploymentEntry {
        ManualEmploymentEntry(id: id)
    }
}

struct ManualEducationEntry: Equatable, Identifiable, Sendable {
    let id: Int
    var institution = ""
    var degree = ""
    var fieldOfStudy = ""
    var startYear = ""
    var endYear = ""

    static func blank(id: Int) -> ManualEducationEntry {
        ManualEducationEntry(id: id)
    }
}

struct ManualProfileFlowState: Equatable, Sendable {
    var step: ManualProfileStep
    var basicProfile: ManualProfileBasicDraft
    var employmentEntries: [ManualEmploymentEntry]
    var educationEntries: [ManualEducationEntry]
    private var nextEmploymentID: Int
    private var nextEducationID: Int

    init(
        step: ManualProfileStep = .basicProfile,
        basicProfile: ManualProfileBasicDraft = ManualProfileBasicDraft(),
        employmentEntries: [ManualEmploymentEntry] = [ManualEmploymentEntry.blank(id: 0)],
        educationEntries: [ManualEducationEntry] = [ManualEducationEntry.blank(id: 0)],
        nextEmploymentID: Int = 1,
        nextEducationID: Int = 1
    ) {
        self.step = step
        self.basicProfile = basicProfile
        self.employmentEntries = employmentEntries.isEmpty ? [ManualEmploymentEntry.blank(id: 0)] : employmentEntries
        self.educationEntries = educationEntries.isEmpty ? [ManualEducationEntry.blank(id: 0)] : educationEntries
        self.nextEmploymentID = max(
            nextEmploymentID,
            (self.employmentEntries.map(\.id).max() ?? -1) + 1
        )
        self.nextEducationID = max(
            nextEducationID,
            (self.educationEntries.map(\.id).max() ?? -1) + 1
        )
    }

    var canContinue: Bool {
        switch step {
        case .basicProfile:
            ManualProfileValidation.isBasicProfileValid(basicProfile)
        case .employment:
            ManualProfileValidation.areEmploymentEntriesValid(employmentEntries)
        case .education:
            ManualProfileValidation.areEducationEntriesValid(educationEntries)
        }
    }

    mutating func advance() {
        switch step {
        case .basicProfile where ManualProfileValidation.isBasicProfileValid(basicProfile):
            step = .employment
        case .employment where ManualProfileValidation.areEmploymentEntriesValid(employmentEntries):
            step = .education
        case .education:
            break
        default:
            break
        }
    }

    mutating func goBack() {
        switch step {
        case .basicProfile:
            break
        case .employment:
            step = .basicProfile
        case .education:
            step = .employment
        }
    }

    mutating func addEmployment() {
        employmentEntries.append(ManualEmploymentEntry.blank(id: nextEmploymentID))
        nextEmploymentID += 1
    }

    mutating func deleteEmployment(id: Int) {
        if employmentEntries.count == 1 {
            employmentEntries[0] = ManualEmploymentEntry.blank(id: employmentEntries[0].id)
            return
        }

        employmentEntries.removeAll { $0.id == id }
    }

    mutating func updateEmployment(id: Int, mutate: (inout ManualEmploymentEntry) -> Void) {
        guard let index = employmentEntries.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&employmentEntries[index])

        if employmentEntries[index].isCurrentlyWorking {
            employmentEntries[index].endMonth = ""
            employmentEntries[index].endYear = ""
        }
    }

    mutating func addEducation() {
        educationEntries.append(ManualEducationEntry.blank(id: nextEducationID))
        nextEducationID += 1
    }

    mutating func deleteEducation(id: Int) {
        if educationEntries.count == 1 {
            educationEntries[0] = ManualEducationEntry.blank(id: educationEntries[0].id)
            return
        }

        educationEntries.removeAll { $0.id == id }
    }

    mutating func updateEducation(id: Int, mutate: (inout ManualEducationEntry) -> Void) {
        guard let index = educationEntries.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&educationEntries[index])
    }
}

enum ManualProfileBasicField: Hashable, Sendable {
    case currentCity
    case currentCountry
}

enum ManualEmploymentField: Hashable, Sendable {
    case company
    case jobTitle
    case employmentType
    case startMonth
    case startYear
    case endMonth
    case endYear
}

enum ManualEducationField: Hashable, Sendable {
    case institution
    case degree
    case fieldOfStudy
    case startYear
    case endYear
}

enum ManualProfileValidation {
    private nonisolated static var minimumYear: Int { 1950 }
    private nonisolated static var currentYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    nonisolated static func basicProfileError(
        for field: ManualProfileBasicField,
        in draft: ManualProfileBasicDraft
    ) -> String? {
        switch field {
        case .currentCity:
            return normalized(draft.currentCity).isEmpty ? "Enter your current city." : nil
        case .currentCountry:
            return normalized(draft.currentCountry).isEmpty ? "Enter your current country." : nil
        }
    }

    nonisolated static func employmentError(
        for field: ManualEmploymentField,
        in entry: ManualEmploymentEntry
    ) -> String? {
        switch field {
        case .company:
            return normalized(entry.company).isEmpty ? "Enter the company." : nil
        case .jobTitle:
            return normalized(entry.jobTitle).isEmpty ? "Enter the job title." : nil
        case .employmentType:
            return normalized(entry.employmentType).isEmpty ? "Enter the employment type." : nil
        case .startMonth:
            return validatedMonth(entry.startMonth) == nil ? "Enter a valid start month." : nil
        case .startYear:
            return yearValidationMessage(entry.startYear, emptyMessage: "Enter the start year.")
        case .endMonth:
            guard !entry.isCurrentlyWorking else {
                return nil
            }

            return validatedMonth(entry.endMonth) == nil ? "Enter a valid end month." : nil
        case .endYear:
            guard !entry.isCurrentlyWorking else {
                return nil
            }

            if let message = yearValidationMessage(entry.endYear, emptyMessage: "Enter the end year.") {
                return message
            }

            guard let startDate = employmentDate(month: entry.startMonth, year: entry.startYear),
                  let endDate = employmentDate(month: entry.endMonth, year: entry.endYear) else {
                return nil
            }

            return endDate < startDate ? "End date must be after the start date." : nil
        }
    }

    nonisolated static func educationError(
        for field: ManualEducationField,
        in entry: ManualEducationEntry
    ) -> String? {
        switch field {
        case .institution:
            return normalized(entry.institution).isEmpty ? "Enter the institution." : nil
        case .degree:
            return normalized(entry.degree).isEmpty ? "Enter the degree." : nil
        case .fieldOfStudy:
            return normalized(entry.fieldOfStudy).isEmpty ? "Enter the field of study." : nil
        case .startYear:
            return yearValidationMessage(entry.startYear, emptyMessage: "Enter the start year.")
        case .endYear:
            if let message = yearValidationMessage(entry.endYear, emptyMessage: "Enter the end year.") {
                return message
            }

            guard let startYear = validatedYear(entry.startYear),
                  let endYear = validatedYear(entry.endYear) else {
                return nil
            }

            return endYear < startYear ? "End year must be after the start year." : nil
        }
    }

    nonisolated static func isBasicProfileValid(_ draft: ManualProfileBasicDraft) -> Bool {
        basicProfileError(for: .currentCity, in: draft) == nil
            && basicProfileError(for: .currentCountry, in: draft) == nil
    }

    nonisolated static func areEmploymentEntriesValid(_ entries: [ManualEmploymentEntry]) -> Bool {
        !entries.isEmpty && entries.allSatisfy(isEmploymentEntryValid)
    }

    nonisolated static func isEmploymentEntryValid(_ entry: ManualEmploymentEntry) -> Bool {
        employmentError(for: .company, in: entry) == nil
            && employmentError(for: .jobTitle, in: entry) == nil
            && employmentError(for: .employmentType, in: entry) == nil
            && employmentError(for: .startMonth, in: entry) == nil
            && employmentError(for: .startYear, in: entry) == nil
            && employmentError(for: .endMonth, in: entry) == nil
            && employmentError(for: .endYear, in: entry) == nil
    }

    nonisolated static func areEducationEntriesValid(_ entries: [ManualEducationEntry]) -> Bool {
        !entries.isEmpty && entries.allSatisfy(isEducationEntryValid)
    }

    nonisolated static func isEducationEntryValid(_ entry: ManualEducationEntry) -> Bool {
        educationError(for: .institution, in: entry) == nil
            && educationError(for: .degree, in: entry) == nil
            && educationError(for: .fieldOfStudy, in: entry) == nil
            && educationError(for: .startYear, in: entry) == nil
            && educationError(for: .endYear, in: entry) == nil
    }

    nonisolated static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func yearValidationMessage(_ value: String, emptyMessage: String) -> String? {
        let normalizedYear = normalized(value)
        guard !normalizedYear.isEmpty else {
            return emptyMessage
        }

        return validatedYear(normalizedYear) == nil ? "Enter a valid 4-digit year." : nil
    }

    private nonisolated static func validatedYear(_ value: String) -> Int? {
        let normalizedYear = normalized(value)
        guard normalizedYear.count == 4,
              normalizedYear.allSatisfy(\.isNumber),
              let year = Int(normalizedYear),
              year >= minimumYear,
              year <= currentYear + 1 else {
            return nil
        }

        return year
    }

    private nonisolated static func validatedMonth(_ value: String) -> Int? {
        let normalizedMonth = normalized(value).lowercased()
        guard !normalizedMonth.isEmpty else {
            return nil
        }

        let supportedMonths: [[String]] = [
            ["january", "jan"],
            ["february", "feb"],
            ["march", "mar"],
            ["april", "apr"],
            ["may"],
            ["june", "jun"],
            ["july", "jul"],
            ["august", "aug"],
            ["september", "sep", "sept"],
            ["october", "oct"],
            ["november", "nov"],
            ["december", "dec"]
        ]

        for (index, aliases) in supportedMonths.enumerated() where aliases.contains(normalizedMonth) {
            return index + 1
        }

        return nil
    }

    private nonisolated static func employmentDate(month: String, year: String) -> Int? {
        guard let validatedMonth = validatedMonth(month),
              let validatedYear = validatedYear(year) else {
            return nil
        }

        return validatedYear * 100 + validatedMonth
    }
}
