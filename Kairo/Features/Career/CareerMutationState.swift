import Foundation

nonisolated enum CareerMutationMode: String, Equatable, Sendable {
    case create
    case edit

    var actionTitle: String {
        switch self {
        case .create:
            "Add"
        case .edit:
            "Save"
        }
    }
}

nonisolated enum CareerDatePrecisionOption: String, CaseIterable, Identifiable, Sendable {
    case day
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            "Exact day"
        case .month:
            "Month"
        case .year:
            "Year"
        }
    }

    nonisolated init(rawValue: String?) {
        self = CareerDatePrecisionOption(rawValue: rawValue ?? "") ?? .month
    }
}

nonisolated enum CareerEmploymentTypeOption: String, CaseIterable, Identifiable, Sendable {
    case fullTime = "full_time"
    case partTime = "part_time"
    case contract
    case intern
    case gig
    case freelance
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullTime:
            "Full-time"
        case .partTime:
            "Part-time"
        case .contract:
            "Contract"
        case .intern:
            "Internship"
        case .gig:
            "Gig"
        case .freelance:
            "Freelance"
        case .other:
            "Other"
        }
    }

    nonisolated init(rawValue: String?) {
        self = CareerEmploymentTypeOption(rawValue: rawValue ?? "") ?? .fullTime
    }
}

nonisolated enum CareerWorkArrangementOption: String, CaseIterable, Identifiable, Sendable {
    case onsite
    case hybrid
    case remote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onsite: "On-site"
        case .hybrid: "Hybrid"
        case .remote: "Remote"
        }
    }

    nonisolated init(rawValue: String?) {
        self = CareerWorkArrangementOption(rawValue: rawValue ?? "") ?? .onsite
    }
}

nonisolated enum CareerEducationLevelOption: String, CaseIterable, Identifiable, Sendable {
    case highSchool = "high_school"
    case diploma
    case bachelors
    case masters
    case doctorate
    case certification
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highSchool:
            "High school"
        case .diploma:
            "Diploma"
        case .bachelors:
            "Bachelor's"
        case .masters:
            "Master's"
        case .doctorate:
            "Doctorate"
        case .certification:
            "Certification"
        case .other:
            "Other"
        }
    }

    nonisolated init(rawValue: String?) {
        self = CareerEducationLevelOption(rawValue: rawValue ?? "")
            ?? ManualProfileNormalization
                .normalizedEducationLevel(rawValue ?? "")
                .flatMap(CareerEducationLevelOption.init(rawValue:))
            ?? .other
    }
}

nonisolated struct CareerEmploymentDraft: Equatable, Sendable {
    var employerLegalName = ""
    var employerTradeName = ""
    var jobTitle = ""
    var employmentType: CareerEmploymentTypeOption = .fullTime
    var startDate = Date()
    var includesStartDate = true
    var endDate = Date()
    var includesEndDate = true
    var isCurrentlyWorking = true
    var workArrangement: CareerWorkArrangementOption = .onsite
    var workLocationCity = ""
    var workLocationCountry = ""
    var workLocationRegion = ""

    init() {}

    init(record: CareerEmploymentRecord) {
        employerLegalName = record.employerLegalName
        employerTradeName = record.employerTradeName ?? ""
        jobTitle = record.role
        employmentType = .init(rawValue: record.employmentType)
        startDate = record.startDate ?? Date()
        endDate = record.endDate ?? Date()
        includesStartDate = record.startDate != nil
        includesEndDate = record.endDate != nil
        isCurrentlyWorking = record.currentlyWorking
        workArrangement = .init(rawValue: record.workArrangement)
        workLocationCity = record.workLocationCity ?? ""
        workLocationCountry = record.workLocationCountry ?? ""
        workLocationRegion = record.workLocationRegion ?? ""
    }

    var displayName: String {
        normalized(employerTradeName).nonEmpty
            ?? normalized(employerLegalName).nonEmpty
            ?? "employment record"
    }

    func validationErrors() -> [String: String] {
        var errors: [String: String] = [:]

        if normalized(employerLegalName).isEmpty {
            errors["employer_legal_name"] = "Enter the employer name."
        }

        if normalized(jobTitle).isEmpty {
            errors["job_title"] = "Enter the job title."
        }

        if workArrangement != .remote {
            if normalized(workLocationCity).isEmpty {
                errors["work_location_city"] = "Enter the work city."
            }
            if ManualProfileNormalization.normalizedCountryCode(workLocationCountry) == nil {
                errors["work_location_country"] = "Enter a valid country."
            }
        }

        if includesStartDate, includesEndDate, !isCurrentlyWorking, endDate < startDate {
            errors["end_date"] = "End date must be after the start date."
        }

        return errors
    }

    func createRequest(currentUser: AppUser) -> CareerEmploymentCreateRequestDTO {
        CareerEmploymentCreateRequestDTO(
            subjectFullName: normalized(currentUser.fullName ?? "").nonEmpty ?? currentUser.email,
            subjectEmail: currentUser.email,
            employerLegalName: normalized(employerLegalName),
            employerTradeName: normalized(employerTradeName).nonEmpty,
            jobTitle: normalized(jobTitle),
            employmentType: employmentType.rawValue,
            verificationMethod: "document",
            startDate: encodedDate(startDate),
            endDate: isCurrentlyWorking ? nil : encodedDate(endDate),
            workLocationCountry: workArrangement == .remote ? nil : ManualProfileNormalization.normalizedCountryCode(workLocationCountry),
            workLocationRegion: workArrangement == .remote ? nil : normalized(workLocationRegion).nonEmpty,
            workLocationCity: workArrangement == .remote ? nil : normalized(workLocationCity).nonEmpty,
            workArrangement: workArrangement.rawValue
        )
    }

    func updateRequest() -> CareerEmploymentUpdateRequestDTO {
        CareerEmploymentUpdateRequestDTO(
            subjectFullName: nil,
            subjectEmail: nil,
            employerLegalName: normalized(employerLegalName).nonEmpty,
            employerTradeName: normalized(employerTradeName).nonEmpty,
            jobTitle: normalized(jobTitle).nonEmpty,
            employmentType: employmentType.rawValue,
            startDate: includesStartDate ? encodedDate(startDate) : nil,
            endDate: isCurrentlyWorking || !includesEndDate ? nil : encodedDate(endDate),
            workLocationCountry: workArrangement == .remote ? nil : ManualProfileNormalization.normalizedCountryCode(workLocationCountry),
            workLocationRegion: workArrangement == .remote ? nil : normalized(workLocationRegion).nonEmpty,
            workLocationCity: workArrangement == .remote ? nil : normalized(workLocationCity).nonEmpty,
            workArrangement: workArrangement.rawValue
        )
    }
}

nonisolated struct CareerEducationDraft: Equatable, Sendable {
    var institutionName = ""
    var degree = ""
    var fieldOfStudy = ""
    var educationLevel: CareerEducationLevelOption?
    var grade = ""
    var startDate = Date()
    var includesStartDate = true
    var startPrecision: CareerDatePrecisionOption = .year
    var endDate = Date()
    var endPrecision: CareerDatePrecisionOption = .year
    var isCurrentlyStudying = false
    var includesEndDate = true

    init() {}

    init(record: CareerEducationRecord) {
        institutionName = record.institution
        degree = record.degree
        fieldOfStudy = record.fieldOfStudy ?? ""
        educationLevel = record.educationLevel.map(CareerEducationLevelOption.init(rawValue:))
        grade = record.grade ?? ""
        startDate = record.startDate ?? Date()
        includesStartDate = record.startDate != nil
        startPrecision = .init(rawValue: record.startDatePrecision)
        if let endDate = record.endDate {
            self.endDate = endDate
            includesEndDate = true
        } else {
            includesEndDate = false
        }
        endPrecision = .init(rawValue: record.endDatePrecision)
        isCurrentlyStudying = record.isCurrentlyStudying
    }

    var displayName: String {
        normalized(institutionName).nonEmpty ?? "education record"
    }

    func validationErrors() -> [String: String] {
        var errors: [String: String] = [:]

        if normalized(institutionName).isEmpty {
            errors["institution_name"] = "Enter the institution."
        }

        if normalized(degree).isEmpty {
            errors["degree"] = "Enter the degree."
        }

        if educationLevel == nil {
            errors["education_level"] = "Choose the education level."
        }

        if includesStartDate, !isCurrentlyStudying, includesEndDate, endDate < startDate {
            errors["end_date"] = "End date must be after the start date."
        }

        return errors
    }

    func createRequest() -> CareerEducationCreateRequestDTO {
        CareerEducationCreateRequestDTO(
            institutionName: normalized(institutionName),
            degree: normalized(degree),
            fieldOfStudy: normalized(fieldOfStudy).nonEmpty,
            educationLevel: educationLevel?.rawValue ?? "",
            grade: normalized(grade).nonEmpty,
            startDate: encodedDate(startDate, precision: startPrecision),
            startDatePrecision: startPrecision.rawValue,
            endDate: resolvedEndDate(),
            endDatePrecision: resolvedEndDate() == nil ? nil : endPrecision.rawValue,
            isCurrentlyStudying: isCurrentlyStudying
        )
    }

    func updateRequest() -> CareerEducationUpdateRequestDTO {
        CareerEducationUpdateRequestDTO(
            institutionName: normalized(institutionName).nonEmpty,
            degree: normalized(degree).nonEmpty,
            fieldOfStudy: normalized(fieldOfStudy).nonEmpty,
            educationLevel: educationLevel?.rawValue,
            grade: normalized(grade).nonEmpty,
            startDate: includesStartDate ? encodedDate(startDate, precision: startPrecision) : nil,
            startDatePrecision: includesStartDate ? startPrecision.rawValue : nil,
            endDate: resolvedEndDate(),
            endDatePrecision: resolvedEndDate() == nil ? nil : endPrecision.rawValue,
            isCurrentlyStudying: isCurrentlyStudying
        )
    }

    private func resolvedEndDate() -> String? {
        guard !isCurrentlyStudying, includesEndDate else {
            return nil
        }

        return encodedDate(endDate, precision: endPrecision)
    }
}

nonisolated struct CareerCertificationDraft: Equatable, Sendable {
    var title = ""
    var issuingOrganization = ""
    var issuedDate = Date()
    var includesIssuedDate = true
    var expiryDate = Date()
    var includesExpiryDate = false
    var doesNotExpire = false
    var credentialID = ""
    var credentialURL = ""
    var existingDocumentFilename: String?

    init() {}

    init(record: CareerCertificationRecord) {
        title = record.title
        issuingOrganization = record.issuer
        issuedDate = record.issueDate ?? Date()
        includesIssuedDate = record.issueDate != nil
        if let expiryDate = record.expiryDate {
            self.expiryDate = expiryDate
            includesExpiryDate = true
        }
        doesNotExpire = record.doesNotExpire
        credentialID = record.credentialID ?? ""
        credentialURL = record.credentialURL?.absoluteString ?? ""
        existingDocumentFilename = record.originalFilename
    }

    var displayName: String {
        normalized(title).nonEmpty ?? "certification"
    }

    func validationErrors() -> [String: String] {
        var errors: [String: String] = [:]

        if normalized(title).isEmpty {
            errors["title"] = "Enter the certification title."
        }

        if normalized(issuingOrganization).isEmpty {
            errors["issuing_organization"] = "Enter the issuer."
        }

        if includesIssuedDate, includesExpiryDate, !doesNotExpire, expiryDate < issuedDate {
            errors["expiry_date"] = "Expiry date must be after the issue date."
        }

        if !normalized(credentialURL).isEmpty, validatedURL(normalized(credentialURL)) == nil {
            errors["credential_url"] = "Enter a valid credential URL."
        }

        return errors
    }

    func createRequest() -> CareerCertificationCreateRequestDTO {
        CareerCertificationCreateRequestDTO(
            title: normalized(title),
            issuingOrganization: normalized(issuingOrganization),
            issuedDate: encodedDate(issuedDate),
            expiryDate: resolvedExpiryDate(),
            doesNotExpire: doesNotExpire,
            credentialID: normalized(credentialID).nonEmpty,
            credentialURL: validatedURL(normalized(credentialURL))
        )
    }

    func updateRequest() -> CareerCertificationUpdateRequestDTO {
        CareerCertificationUpdateRequestDTO(
            title: normalized(title).nonEmpty,
            issuingOrganization: normalized(issuingOrganization).nonEmpty,
            issuedDate: includesIssuedDate ? encodedDate(issuedDate) : nil,
            expiryDate: resolvedExpiryDate(),
            doesNotExpire: doesNotExpire,
            credentialID: normalized(credentialID).nonEmpty,
            credentialURL: validatedURL(normalized(credentialURL))
        )
    }

    private func resolvedExpiryDate() -> String? {
        guard includesExpiryDate, !doesNotExpire else {
            return nil
        }

        return encodedDate(expiryDate)
    }
}

nonisolated struct CareerProjectDraft: Equatable, Sendable {
    var title = ""
    var role = ""
    var description = ""
    var startDate = Date()
    var includesStartDate = false
    var endDate = Date()
    var includesEndDate = false
    var isOngoing = false
    var projectURL = ""
    var repositoryURL = ""
    var organizationName = ""

    init() {}

    init(record: CareerProjectRecord) {
        title = record.title
        role = record.role
        description = record.description ?? ""
        if let startDate = record.startDate {
            self.startDate = startDate
            includesStartDate = true
        }
        if let endDate = record.endDate {
            self.endDate = endDate
            includesEndDate = true
        }
        isOngoing = record.isOngoing
        projectURL = record.projectURL?.absoluteString ?? ""
        repositoryURL = record.repositoryURL?.absoluteString ?? ""
        organizationName = record.organizationName ?? ""
    }

    var displayName: String {
        normalized(title).nonEmpty ?? "project"
    }

    func validationErrors() -> [String: String] {
        var errors: [String: String] = [:]

        if normalized(title).isEmpty {
            errors["title"] = "Enter the project title."
        }

        if !normalized(projectURL).isEmpty, validatedURL(normalized(projectURL)) == nil {
            errors["project_url"] = "Enter a valid project URL."
        }

        if !normalized(repositoryURL).isEmpty, validatedURL(normalized(repositoryURL)) == nil {
            errors["repository_url"] = "Enter a valid repository URL."
        }

        if includesStartDate, includesEndDate, !isOngoing, endDate < startDate {
            errors["end_date"] = "End date must be after the start date."
        }

        return errors
    }

    func createRequest() -> CareerProjectCreateRequestDTO {
        CareerProjectCreateRequestDTO(
            title: normalized(title),
            role: normalized(role).nonEmpty,
            description: normalized(description).nonEmpty,
            startDate: includesStartDate ? encodedDate(startDate) : nil,
            endDate: resolvedEndDate(),
            isOngoing: isOngoing,
            projectURL: validatedURL(normalized(projectURL)),
            repositoryURL: validatedURL(normalized(repositoryURL)),
            organizationName: normalized(organizationName).nonEmpty
        )
    }

    func updateRequest() -> CareerProjectUpdateRequestDTO {
        CareerProjectUpdateRequestDTO(
            title: normalized(title).nonEmpty,
            role: normalized(role).nonEmpty,
            description: normalized(description).nonEmpty,
            startDate: includesStartDate ? encodedDate(startDate) : nil,
            endDate: resolvedEndDate(),
            isOngoing: isOngoing,
            projectURL: validatedURL(normalized(projectURL)),
            repositoryURL: validatedURL(normalized(repositoryURL)),
            organizationName: normalized(organizationName).nonEmpty
        )
    }

    private func resolvedEndDate() -> String? {
        guard includesEndDate, !isOngoing else {
            return nil
        }

        return encodedDate(endDate)
    }
}

nonisolated struct CareerPortfolioDraft: Equatable, Sendable {
    var title = ""
    var description = ""
    var url = ""
    var tags = ""
    var existingAttachmentFilename: String?

    init() {}

    init(record: PortfolioRecord) {
        title = record.title
        description = record.description ?? ""
        url = record.url?.absoluteString ?? ""
        tags = record.tags.joined(separator: ", ")
        existingAttachmentFilename = record.document?.originalFilename
    }

    var displayName: String {
        normalized(title).nonEmpty ?? "portfolio item"
    }

    func validationErrors() -> [String: String] {
        var errors: [String: String] = [:]
        let title = normalized(title)
        let description = normalized(description)
        let url = normalized(url)

        if title.isEmpty {
            errors["title"] = "Enter the portfolio title."
        } else if title.count > 512 {
            errors["title"] = "Keep the title to 512 characters or fewer."
        }
        if description.count > 5_000 {
            errors["description"] = "Keep the description to 5,000 characters or fewer."
        }
        if !url.isEmpty, validatedURL(url) == nil {
            errors["url"] = "Enter a valid HTTP or HTTPS URL."
        }
        return errors
    }

    func createRequest() -> PortfolioCreateRequestDTO {
        PortfolioCreateRequestDTO(
            title: normalized(title),
            description: normalized(description).nonEmpty,
            url: validatedURL(normalized(url)),
            tags: normalizedTags
        )
    }

    func updateRequest() -> PortfolioUpdateRequestDTO {
        PortfolioUpdateRequestDTO(
            title: normalized(title).nonEmpty,
            description: normalized(description).nonEmpty,
            url: validatedURL(normalized(url)),
            tags: normalizedTags
        )
    }

    private var normalizedTags: [String] {
        var seen = Set<String>()
        return tags.split(separator: ",")
            .map { normalized(String($0)) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}

nonisolated struct CareerSkillDraft: Equatable, Sendable {
    var name = ""

    init() {}

    init(name: String) {
        self.name = name
    }

    init(record: CareerSkillRecord) {
        name = record.name
    }

    var displayName: String {
        ProfileCatalogues.resolve(name, in: ProfileCatalogues.skills)?.name
            ?? normalized(name).nonEmpty
            ?? "skill"
    }

    func validationErrors(existingNames: [String]) -> [String: String] {
        let normalizedName = normalized(name)
        guard !normalizedName.isEmpty else {
            return ["name": "Choose a Skill."]
        }
        guard let entry = ProfileCatalogues.resolve(normalizedName, in: ProfileCatalogues.skills) else {
            return ["name": "Choose a Skill from the KairoID catalogue."]
        }

        if ProfileCatalogues.contains(entry, values: existingNames, in: ProfileCatalogues.skills) {
            return ["name": "That skill already exists."]
        }

        return [:]
    }

    func createRequest() -> CareerSkillCreateRequestDTO {
        CareerSkillCreateRequestDTO(
            name: ProfileCatalogues.resolve(name, in: ProfileCatalogues.skills)?.name ?? normalized(name)
        )
    }
}

nonisolated struct CareerMutationPresentationError: Equatable, Sendable {
    let title: String
    let message: String
    let fieldErrors: [String: String]
}

nonisolated enum CareerMutationErrorMapper {
    nonisolated static func map(_ error: Error, fallbackTitle: String) -> CareerMutationPresentationError {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .transport:
                return CareerMutationPresentationError(
                    title: "You're offline",
                    message: "KairoID couldn't reach your Career data. Check your connection and try again.",
                    fieldErrors: [:]
                )
            case .api(let apiError):
                let fieldErrors = apiError.fieldErrors.reduce(into: [String: String]()) { partialResult, pair in
                    if let message = validationMessage(for: pair.key) {
                        partialResult[pair.key] = message
                    }
                }
                return CareerMutationPresentationError(
                    title: title(for: apiError, fallbackTitle: fallbackTitle),
                    message: message(for: apiError),
                    fieldErrors: fieldErrors
                )
            case .invalidResponse:
                return CareerMutationPresentationError(
                    title: fallbackTitle,
                    message: "KairoID received an unexpected Career response. Please try again.",
                    fieldErrors: [:]
                )
            case .invalidURL:
                return CareerMutationPresentationError(
                    title: fallbackTitle,
                    message: "KairoID's Career configuration is invalid.",
                    fieldErrors: [:]
                )
            case .unavailableInDemoMode:
                return CareerMutationPresentationError(
                    title: fallbackTitle,
                    message: "Career editing is unavailable while Demo Mode is enabled.",
                    fieldErrors: [:]
                )
            }
        }

        return CareerMutationPresentationError(
            title: fallbackTitle,
            message: "KairoID couldn't complete that Career change. Please try again.",
            fieldErrors: [:]
        )
    }

    private nonisolated static func validationMessage(for field: String) -> String? {
        switch field {
        case "employer_legal_name": "Enter the employer name."
        case "job_title": "Enter the job title."
        case "work_location_city": "Enter the work city."
        case "work_location_country": "Enter a valid country."
        case "institution_name": "Enter the institution."
        case "degree": "Enter the degree."
        case "education_level": "Choose the education level."
        case "issuing_organization": "Enter the issuer."
        case "credential_url": "Enter a valid credential URL."
        case "project_url": "Enter a valid project URL."
        case "repository_url": "Enter a valid repository URL."
        case "expiry_date": "Expiry date must be after the issue date."
        case "end_date": "End date must be after the start date."
        case "title": "Enter a title."
        case "name": "Enter a skill name."
        default: nil
        }
    }

    private nonisolated static func message(for apiError: APIError) -> String {
        switch apiError.code {
        case .badRequest, .validationError:
            "Review the highlighted fields and try again."
        case .forbidden:
            "This record can't be changed in its current state."
        case .notFound:
            "This record is no longer available. Refresh Career and try again."
        case .conflict:
            "This record changed. Refresh Career and try again."
        case .unauthorized:
            "Your session needs to be restored. Sign in and try again."
        case .rateLimited:
            "Too many attempts. Wait a moment and try again."
        case .internalError, .serviceUnavailable:
            "KairoID couldn't complete that Career change. Please try again."
        }
    }

    private nonisolated static func title(for apiError: APIError, fallbackTitle: String) -> String {
        switch apiError.code {
        case .badRequest:
            fallbackTitle
        case .forbidden:
            "You can't change this record"
        case .notFound:
            "This record is no longer available"
        case .conflict:
            "This record changed"
        case .validationError:
            fallbackTitle
        case .unauthorized:
            "Session unavailable"
        case .rateLimited:
            "Too many attempts"
        case .internalError, .serviceUnavailable:
            fallbackTitle
        }
    }
}

private nonisolated func normalized(_ value: String) -> String {
    ManualProfileNormalization.normalized(value)
}

private nonisolated func encodedDate(
    _ date: Date,
    precision: CareerDatePrecisionOption = .day
) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    let components = calendar.dateComponents([.year, .month, .day], from: date)

    let normalizedDate: Date
    switch precision {
    case .day:
        normalizedDate = calendar.date(from: components) ?? date
    case .month:
        normalizedDate = calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: components.year,
                month: components.month,
                day: 1
            )
        ) ?? date
    case .year:
        normalizedDate = calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: components.year,
                month: 1,
                day: 1
            )
        ) ?? date
    }

    return CareerDateFormatting.storageFormatter.string(from: normalizedDate)
}

private nonisolated func validatedURL(_ value: String) -> String? {
    guard !value.isEmpty,
          let url = URL(string: value),
          ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
          let host = url.host, !host.isEmpty,
          url.user == nil, url.password == nil else {
        return nil
    }

    return value
}

private enum CareerDateFormatting {
    nonisolated static let storageFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
