import Foundation

nonisolated enum ManualProfileStep: String, Equatable, Codable, Sendable {
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

nonisolated struct ManualProfileBasicDraft: Equatable, Codable, Sendable {
    var fullName = ""
    var professionalHeadline = ""
    var currentRole = ""
    var industry = ""
    var yearsOfExperience = ""
    var currentCity = ""
    var currentCountry = ""

    mutating func prefillFullNameIfNeeded(
        backendFullName: String?,
        signupDraftFullName: String?
    ) {
        guard ManualProfileNormalization.normalized(fullName).isEmpty else {
            return
        }

        if let normalizedBackendFullName = backendFullName
            .map(ManualProfileNormalization.normalized)?
            .nonEmpty {
            fullName = normalizedBackendFullName
            return
        }

        if let normalizedSignupFullName = signupDraftFullName
            .map(ManualProfileNormalization.normalized)?
            .nonEmpty {
            fullName = normalizedSignupFullName
        }
    }
}

nonisolated struct ManualEmploymentEntry: Equatable, Identifiable, Codable, Sendable {
    let id: Int
    var company = ""
    var jobTitle = ""
    var employmentType = ""
    var workCountry = ""
    var startDay = ""
    var startMonth = ""
    var startYear = ""
    var endDay = ""
    var endMonth = ""
    var endYear = ""
    var isCurrentlyWorking = false

    static func blank(id: Int) -> ManualEmploymentEntry {
        ManualEmploymentEntry(id: id)
    }
}

nonisolated struct ManualEducationEntry: Equatable, Identifiable, Codable, Sendable {
    let id: Int
    var institution = ""
    var degree = ""
    var educationLevel = ""
    var fieldOfStudy = ""
    var startYear = ""
    var endYear = ""

    static func blank(id: Int) -> ManualEducationEntry {
        ManualEducationEntry(id: id)
    }
}

nonisolated struct ManualProfileFlowState: Equatable, Codable, Sendable {
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
            employmentEntries[index].endDay = ""
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

    mutating func reconcileBasicProfilePrefill(
        backendFullName: String?,
        signupDraftFullName: String?
    ) {
        basicProfile.prefillFullNameIfNeeded(
            backendFullName: backendFullName,
            signupDraftFullName: signupDraftFullName
        )
    }
}

nonisolated enum ManualProfileBasicField: Hashable, Sendable {
    case fullName
    case professionalHeadline
    case currentRole
    case industry
    case yearsOfExperience
    case currentCity
    case currentCountry
}

nonisolated enum ManualEmploymentField: Hashable, Sendable {
    case company
    case jobTitle
    case employmentType
    case workCountry
    case startDay
    case startMonth
    case startYear
    case endDay
    case endMonth
    case endYear
}

nonisolated enum ManualEducationField: Hashable, Sendable {
    case institution
    case degree
    case educationLevel
    case fieldOfStudy
    case startYear
    case endYear
}

nonisolated enum ManualProfileNormalization {
    private nonisolated static let englishLocale = Locale(identifier: "en_US_POSIX")

    private nonisolated static let countryLookup: [String: String] = {
        var map: [String: String] = [
            "india": "IN",
            "bharat": "IN",
            "usa": "US",
            "unitedstates": "US",
            "unitedstatesofamerica": "US",
            "uk": "GB",
            "unitedkingdom": "GB",
            "uae": "AE"
        ]

        for region in Locale.Region.isoRegions {
            let code = region.identifier
            map[simplified(code)] = code
            if let localizedName = englishLocale.localizedString(forRegionCode: code) {
                map[simplified(localizedName)] = code
            }
        }

        return map
    }()

    private nonisolated static let employmentTypeLookup: [String: String] = [
        "fulltime": "full_time",
        "fulltimeemployment": "full_time",
        "parttime": "part_time",
        "parttimeemployment": "part_time",
        "contract": "contract",
        "contractor": "contract",
        "intern": "intern",
        "internship": "intern",
        "gig": "gig",
        "freelance": "freelance",
        "other": "other"
    ]

    private nonisolated static let educationLevelLookup: [String: String] = [
        "highschool": "high_school",
        "secondaryschool": "high_school",
        "diploma": "diploma",
        "bachelor": "bachelors",
        "bachelors": "bachelors",
        "btech": "bachelors",
        "be": "bachelors",
        "ba": "bachelors",
        "bsc": "bachelors",
        "bba": "bachelors",
        "master": "masters",
        "masters": "masters",
        "mtech": "masters",
        "me": "masters",
        "msc": "masters",
        "mba": "masters",
        "doctorate": "doctorate",
        "phd": "doctorate",
        "certification": "certification",
        "certificate": "certification",
        "other": "other"
    ]

    nonisolated static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func normalizedCountryCode(_ value: String) -> String? {
        let normalizedValue = simplified(value)
        guard !normalizedValue.isEmpty else {
            return nil
        }

        return countryLookup[normalizedValue]
    }

    nonisolated static func normalizedEmploymentType(_ value: String) -> String? {
        let normalizedValue = simplified(value)
        guard !normalizedValue.isEmpty else {
            return nil
        }

        return employmentTypeLookup[normalizedValue]
    }

    nonisolated static func normalizedEducationLevel(_ value: String) -> String? {
        let normalizedValue = simplified(value)
        guard !normalizedValue.isEmpty else {
            return nil
        }

        return educationLevelLookup[normalizedValue]
    }

    nonisolated static func normalizedMonthNumber(_ value: String) -> Int? {
        let normalizedValue = simplified(value)
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

        for (index, aliases) in supportedMonths.enumerated() where aliases.contains(normalizedValue) {
            return index + 1
        }

        return nil
    }

    private nonisolated static func simplified(_ value: String) -> String {
        normalized(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: englishLocale)
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
            .lowercased()
    }
}

nonisolated enum ManualProfileValidation {
    private nonisolated static var minimumYear: Int { 1950 }
    private nonisolated static var currentYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    nonisolated static func basicProfileError(
        for field: ManualProfileBasicField,
        in draft: ManualProfileBasicDraft
    ) -> String? {
        switch field {
        case .fullName:
            return ManualProfileNormalization.normalized(draft.fullName).isEmpty
                ? "Enter your full name."
                : nil
        case .professionalHeadline:
            return ManualProfileNormalization.normalized(draft.professionalHeadline).isEmpty
                ? "Enter your professional headline."
                : nil
        case .currentRole:
            return ManualProfileNormalization.normalized(draft.currentRole).isEmpty
                ? "Enter your current role."
                : nil
        case .industry:
            return ManualProfileNormalization.normalized(draft.industry).isEmpty
                ? "Enter your industry."
                : nil
        case .yearsOfExperience:
            return yearsOfExperienceValidationMessage(draft.yearsOfExperience)
        case .currentCity:
            return ManualProfileNormalization.normalized(draft.currentCity).isEmpty
                ? "Enter your current city."
                : nil
        case .currentCountry:
            return ManualProfileNormalization.normalized(draft.currentCountry).isEmpty
                ? "Enter your current country."
                : nil
        }
    }

    nonisolated static func employmentError(
        for field: ManualEmploymentField,
        in entry: ManualEmploymentEntry
    ) -> String? {
        switch field {
        case .company:
            return ManualProfileNormalization.normalized(entry.company).isEmpty ? "Enter the company." : nil
        case .jobTitle:
            return ManualProfileNormalization.normalized(entry.jobTitle).isEmpty ? "Enter the job title." : nil
        case .employmentType:
            guard !ManualProfileNormalization.normalized(entry.employmentType).isEmpty else {
                return "Enter the employment type."
            }

            return ManualProfileNormalization.normalizedEmploymentType(entry.employmentType) == nil
                ? "Choose a supported employment type."
                : nil
        case .workCountry:
            guard !ManualProfileNormalization.normalized(entry.workCountry).isEmpty else {
                return "Enter the work country."
            }

            return ManualProfileNormalization.normalizedCountryCode(entry.workCountry) == nil
                ? "Enter a valid country."
                : nil
        case .startDay:
            return validatedDay(entry.startDay) == nil ? "Enter a valid start day." : nil
        case .startMonth:
            return validatedMonth(entry.startMonth) == nil ? "Enter a valid start month." : nil
        case .startYear:
            return yearValidationMessage(entry.startYear, emptyMessage: "Enter the start year.")
        case .endDay:
            guard !entry.isCurrentlyWorking else {
                return nil
            }

            return validatedDay(entry.endDay) == nil ? "Enter a valid end day." : nil
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

            guard let startDate = employmentDate(
                day: entry.startDay,
                month: entry.startMonth,
                year: entry.startYear
            ), let endDate = employmentDate(
                day: entry.endDay,
                month: entry.endMonth,
                year: entry.endYear
            ) else {
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
            return ManualProfileNormalization.normalized(entry.institution).isEmpty ? "Enter the institution." : nil
        case .degree:
            return ManualProfileNormalization.normalized(entry.degree).isEmpty ? "Enter the degree." : nil
        case .educationLevel:
            guard !ManualProfileNormalization.normalized(entry.educationLevel).isEmpty else {
                return "Enter the education level."
            }

            return ManualProfileNormalization.normalizedEducationLevel(entry.educationLevel) == nil
                ? "Choose a supported education level."
                : nil
        case .fieldOfStudy:
            return ManualProfileNormalization.normalized(entry.fieldOfStudy).isEmpty
                ? "Enter the field of study."
                : nil
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
        [
            ManualProfileBasicField.fullName,
            .professionalHeadline,
            .currentRole,
            .industry,
            .yearsOfExperience,
            .currentCity,
            .currentCountry
        ].allSatisfy { basicProfileError(for: $0, in: draft) == nil }
    }

    nonisolated static func areEmploymentEntriesValid(_ entries: [ManualEmploymentEntry]) -> Bool {
        !entries.isEmpty && entries.allSatisfy(isEmploymentEntryValid)
    }

    nonisolated static func isEmploymentEntryValid(_ entry: ManualEmploymentEntry) -> Bool {
        [
            ManualEmploymentField.company,
            .jobTitle,
            .employmentType,
            .workCountry,
            .startDay,
            .startMonth,
            .startYear,
            .endDay,
            .endMonth,
            .endYear
        ].allSatisfy { employmentError(for: $0, in: entry) == nil }
    }

    nonisolated static func areEducationEntriesValid(_ entries: [ManualEducationEntry]) -> Bool {
        !entries.isEmpty && entries.allSatisfy(isEducationEntryValid)
    }

    nonisolated static func isEducationEntryValid(_ entry: ManualEducationEntry) -> Bool {
        [
            ManualEducationField.institution,
            .degree,
            .educationLevel,
            .fieldOfStudy,
            .startYear,
            .endYear
        ].allSatisfy { educationError(for: $0, in: entry) == nil }
    }

    nonisolated static func normalizedYearsOfExperience(_ value: String) -> Int? {
        let normalizedValue = ManualProfileNormalization.normalized(value)
        guard !normalizedValue.isEmpty,
              normalizedValue.allSatisfy(\.isNumber),
              let years = Int(normalizedValue),
              (0 ... 80).contains(years) else {
            return nil
        }

        return years
    }

    private nonisolated static func yearsOfExperienceValidationMessage(_ value: String) -> String? {
        let normalizedValue = ManualProfileNormalization.normalized(value)
        guard !normalizedValue.isEmpty else {
            return "Enter your years of experience."
        }

        return normalizedYearsOfExperience(normalizedValue) == nil
            ? "Enter valid whole years of experience."
            : nil
    }

    private nonisolated static func yearValidationMessage(_ value: String, emptyMessage: String) -> String? {
        let normalizedYear = ManualProfileNormalization.normalized(value)
        guard !normalizedYear.isEmpty else {
            return emptyMessage
        }

        return validatedYear(normalizedYear) == nil ? "Enter a valid 4-digit year." : nil
    }

    private nonisolated static func validatedYear(_ value: String) -> Int? {
        let normalizedYear = ManualProfileNormalization.normalized(value)
        guard normalizedYear.count == 4,
              normalizedYear.allSatisfy(\.isNumber),
              let year = Int(normalizedYear),
              year >= minimumYear,
              year <= currentYear + 1 else {
            return nil
        }

        return year
    }

    private nonisolated static func validatedDay(_ value: String) -> Int? {
        let normalizedDay = ManualProfileNormalization.normalized(value)
        guard !normalizedDay.isEmpty,
              normalizedDay.allSatisfy(\.isNumber),
              let day = Int(normalizedDay),
              (1 ... 31).contains(day) else {
            return nil
        }

        return day
    }

    private nonisolated static func validatedMonth(_ value: String) -> Int? {
        ManualProfileNormalization.normalizedMonthNumber(value)
    }

    private nonisolated static func employmentDate(
        day: String,
        month: String,
        year: String
    ) -> Date? {
        guard let validatedDay = validatedDay(day),
              let validatedMonth = validatedMonth(month),
              let validatedYear = validatedYear(year) else {
            return nil
        }

        let components = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: validatedYear,
            month: validatedMonth,
            day: validatedDay
        )
        return components.date
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
