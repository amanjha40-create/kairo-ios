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
            "Exact date"
        case .month:
            "Month & year"
        case .year:
            "Year only"
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
    var startDate = Date() { didSet { includesStartDate = true } }
    var includesStartDate = false
    var endDate = Date() { didSet { includesEndDate = true } }
    var includesEndDate = false
    var isCurrentlyWorking = true
    var workArrangement: CareerWorkArrangementOption = .onsite
    var workLocationCity = ""
    var workLocationCountry = ""
    var workLocationRegion = ""
    private var originalType: String?
    private var originalArrangement: String?
    private var originalCountry: String?
    private var initialType: CareerEmploymentTypeOption?
    private var initialArrangement: CareerWorkArrangementOption?
    var employmentTypeLabel: String { originalType.flatMap { CareerEmploymentTypeOption(rawValue: $0) == nil && employmentType == initialType ? $0 : nil } ?? employmentType.title }
    var workArrangementLabel: String { originalArrangement.flatMap { CareerWorkArrangementOption(rawValue: $0) == nil && workArrangement == initialArrangement ? $0 : nil } ?? workArrangement.title }
    mutating func selectEmploymentType(_ value: CareerEmploymentTypeOption) { originalType = nil; initialType = nil; employmentType = value }
    mutating func selectWorkArrangement(_ value: CareerWorkArrangementOption) { originalArrangement = nil; initialArrangement = nil; workArrangement = value }

    private var originalText: [String: String] = [:]

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
        originalType = record.employmentType
        initialType = employmentType
        originalArrangement = record.workArrangement
        initialArrangement = workArrangement
        originalCountry = record.workLocationCountry
        originalText = ["employerLegalName": employerLegalName, "employerTradeName": employerTradeName, "jobTitle": jobTitle, "workLocationCity": workLocationCity, "workLocationRegion": workLocationRegion]
    }

    var displayName: String {
        normalized(employerTradeName).nonEmpty
            ?? normalized(employerLegalName).nonEmpty
            ?? "employment record"
    }

    func validationErrors(mode: CareerMutationMode = .edit) -> [String: String] {
        var errors: [String: String] = [:]

        if originalText["employerLegalName"] != employerLegalName && (normalized(employerLegalName).count < 2 || employerLegalName.count > 512) {
            errors["employer_legal_name"] = "Enter an employer name of 2–512 characters."
        }

        if originalText["jobTitle"] != jobTitle && (normalized(jobTitle).isEmpty || jobTitle.count > 255) {
            errors["job_title"] = "Enter the job title."
        }

        if workArrangement != .remote {
            if !workLocationCountry.isEmpty, workLocationCountry != originalCountry,
               ManualProfileNormalization.normalizedCountryCode(workLocationCountry) == nil {
                errors["work_location_country"] = "Enter a valid country."
            }
        }

        if mode == .create && !includesStartDate { errors["start_date"] = "Choose a start date." }
        if isCurrentlyWorking && includesEndDate { errors["end_date"] = "Remove the end date explicitly, or turn off Currently working." }

        if includesStartDate, includesEndDate, !isCurrentlyWorking, encodedDate(endDate) < encodedDate(startDate) {
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
            endDate: includesEndDate ? encodedDate(endDate) : nil,
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
            employerLegalName: originalText["employerLegalName"] == employerLegalName ? nil : normalized(employerLegalName).nonEmpty,
            employerTradeName: originalText["employerTradeName"] == employerTradeName ? nil : normalized(employerTradeName).nonEmpty,
            jobTitle: originalText["jobTitle"] == jobTitle ? nil : normalized(jobTitle).nonEmpty,
            employmentType: initialType != nil && employmentType == initialType && (originalType == nil || CareerEmploymentTypeOption(rawValue: originalType!) == nil) ? nil : employmentType.rawValue,
            startDate: includesStartDate ? encodedDate(startDate) : nil,
            endDate: !includesEndDate ? nil : encodedDate(endDate),
            workLocationCountry: workLocationCountry == originalCountry ? nil : ManualProfileNormalization.normalizedCountryCode(workLocationCountry),
            workLocationRegion: workArrangement == .remote ? nil : originalText["workLocationRegion"] == workLocationRegion ? nil : normalized(workLocationRegion).nonEmpty,
            workLocationCity: workArrangement == .remote ? nil : originalText["workLocationCity"] == workLocationCity ? nil : normalized(workLocationCity).nonEmpty,
            workArrangement: initialArrangement != nil && workArrangement == initialArrangement && (originalArrangement == nil || CareerWorkArrangementOption(rawValue: originalArrangement!) == nil) ? nil : workArrangement.rawValue,
            updatesCountry: workLocationCountry != (originalCountry ?? ""),
            updatesRegion: workArrangement != .remote && workLocationRegion != (originalText["workLocationRegion"] ?? ""),
            updatesCity: workArrangement != .remote && workLocationCity != (originalText["workLocationCity"] ?? "")
        )
    }
}

nonisolated struct CareerEducationDraft: Equatable, Sendable {
    var institutionName = ""
    var degree = ""
    var fieldOfStudy = ""
    var educationLevel: CareerEducationLevelOption?
    var grade = ""
    var startDate = Date() { didSet { includesStartDate = true } }
    var includesStartDate = false
    var startPrecision: CareerDatePrecisionOption = .year
    var endDate = Date() { didSet { includesEndDate = true } }
    var endPrecision: CareerDatePrecisionOption = .year
    var isCurrentlyStudying = false
    var includesEndDate = false
    private var originalLevel: String?
    private var initialLevel: CareerEducationLevelOption?
    private var originalStart: Date?
    private var originalEnd: Date?
    private var originalStartPrecision: String?
    private var originalEndPrecision: String?
    var educationLevelLabel: String {
        originalLevel.flatMap { CareerEducationLevelOption(rawValue: $0) == nil && educationLevel == initialLevel ? $0 : nil }
            ?? educationLevel?.title ?? "Choose education level"
    }
    mutating func selectEducationLevel(_ value: CareerEducationLevelOption) { originalLevel = nil; educationLevel = value }

    private var originalText: [String: String] = [:]

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
        originalLevel = record.educationLevel
        initialLevel = educationLevel
        originalStart = record.startDate
        originalEnd = record.endDate
        originalStartPrecision = record.startDatePrecision
        originalEndPrecision = record.endDatePrecision
        originalText = ["institutionName": institutionName, "degree": degree, "fieldOfStudy": fieldOfStudy, "grade": grade]
    }

    var displayName: String {
        normalized(institutionName).nonEmpty ?? "education record"
    }

    func validationErrors(mode: CareerMutationMode = .edit) -> [String: String] {
        var errors: [String: String] = [:]

        if originalText["institutionName"] != institutionName && (normalized(institutionName).isEmpty || institutionName.count > 512) {
            errors["institution_name"] = "Enter the institution."
        }

        if originalText["degree"] != degree && (normalized(degree).isEmpty || degree.count > 255) {
            errors["degree"] = "Enter the degree."
        }

        if educationLevel == nil && mode == .create {
            errors["education_level"] = "Choose the education level."
        }

        if mode == .create && !includesStartDate { errors["start_date"] = "Choose a start date." }
        if isCurrentlyStudying && includesEndDate { errors["end_date"] = "Remove the end date explicitly, or turn off Currently studying." }

        let effectiveStart = mode == .create ? encodedDate(startDate, precision: startPrecision) : updateRequest().startDate
        if includesStartDate, !isCurrentlyStudying, includesEndDate,
           let effectiveStart, let effectiveEnd = resolvedEndDate(), effectiveEnd < effectiveStart {
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
            institutionName: originalText["institutionName"] == institutionName ? nil : normalized(institutionName).nonEmpty,
            degree: originalText["degree"] == degree ? nil : normalized(degree).nonEmpty,
            fieldOfStudy: originalText["fieldOfStudy"] == fieldOfStudy ? nil : normalized(fieldOfStudy).nonEmpty,
            educationLevel: originalLevel != nil && educationLevel == initialLevel && CareerEducationLevelOption(rawValue: originalLevel!) == nil ? nil : educationLevel?.rawValue,
            grade: originalText["grade"] == grade ? nil : normalized(grade).nonEmpty,
            startDate: includesStartDate ? encodedDate(startDate, precision: startDate == originalStart && startPrecision == .init(rawValue: originalStartPrecision) ? .day : startPrecision) : nil,
            startDatePrecision: includesStartDate ? (startDate == originalStart && startPrecision == .init(rawValue: originalStartPrecision) ? originalStartPrecision : startPrecision.rawValue) : nil,
            endDate: resolvedEndDate(),
            endDatePrecision: resolvedEndDate() == nil ? nil : (endDate == originalEnd && endPrecision == .init(rawValue: originalEndPrecision) ? originalEndPrecision : endPrecision.rawValue),
            isCurrentlyStudying: isCurrentlyStudying
        )
    }

    private func resolvedEndDate() -> String? {
        guard includesEndDate else {
            return nil
        }

        return encodedDate(endDate, precision: endDate == originalEnd && endPrecision == .init(rawValue: originalEndPrecision) ? .day : endPrecision)
    }
}

nonisolated struct CareerCertificationDraft: Equatable, Sendable {
    var title = ""
    var issuingOrganization = ""
    var issuedDate = Date() { didSet { includesIssuedDate = true } }
    var includesIssuedDate = false
    var expiryDate = Date() { didSet { includesExpiryDate = true } }
    var includesExpiryDate = false
    var doesNotExpire = false
    var credentialID = ""
    var credentialURL = ""
    var existingDocumentFilename: String?

    private var originalText: [String: String] = [:]

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
        originalText = ["title": title, "issuingOrganization": issuingOrganization, "credentialID": credentialID]
    }

    var displayName: String {
        normalized(title).nonEmpty ?? "certification"
    }

    func validationErrors(mode: CareerMutationMode = .edit) -> [String: String] {
        var errors: [String: String] = [:]
        if mode == .create && !includesIssuedDate { errors["issued_date"] = "Choose an issue date." }
        if doesNotExpire && includesExpiryDate { errors["expiry_date"] = "Remove the expiry date explicitly, or turn off Never expires." }

        if originalText["title"] != title && (normalized(title).isEmpty || title.count > 512) {
            errors["title"] = "Enter the certification title."
        }

        if originalText["issuingOrganization"] != issuingOrganization && (normalized(issuingOrganization).isEmpty || issuingOrganization.count > 512) {
            errors["issuing_organization"] = "Enter the issuer."
        }

        if includesIssuedDate, includesExpiryDate, !doesNotExpire, encodedDate(expiryDate) < encodedDate(issuedDate) {
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
            title: originalText["title"] == title ? nil : normalized(title).nonEmpty,
            issuingOrganization: originalText["issuingOrganization"] == issuingOrganization ? nil : normalized(issuingOrganization).nonEmpty,
            issuedDate: includesIssuedDate ? encodedDate(issuedDate) : nil,
            expiryDate: resolvedExpiryDate(),
            doesNotExpire: doesNotExpire,
            credentialID: originalText["credentialID"] == credentialID ? nil : normalized(credentialID).nonEmpty,
            credentialURL: validatedURL(normalized(credentialURL))
        )
    }

    private func resolvedExpiryDate() -> String? {
        guard includesExpiryDate else {
            return nil
        }

        return encodedDate(expiryDate)
    }
}

nonisolated struct CareerProjectDraft: Equatable, Sendable {
    var title = ""
    var role = ""
    var description = ""
    var startDate = Date() { didSet { includesStartDate = true } }
    var includesStartDate = false
    var endDate = Date() { didSet { includesEndDate = true } }
    var includesEndDate = false
    var isOngoing = false
    var projectURL = ""
    var repositoryURL = ""
    var organizationName = ""

    private var originalText: [String: String] = [:]

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
        originalText = ["title": title, "role": role, "description": description, "organizationName": organizationName]
    }

    var displayName: String {
        normalized(title).nonEmpty ?? "project"
    }

    func validationErrors() -> [String: String] {
        var errors: [String: String] = [:]
        if isOngoing && includesEndDate { errors["end_date"] = "Remove the end date explicitly, or turn off Ongoing." }

        if originalText["title"] != title && (normalized(title).isEmpty || title.count > 255) {
            errors["title"] = "Enter the project title."
        }

        if !normalized(projectURL).isEmpty, validatedURL(normalized(projectURL)) == nil {
            errors["project_url"] = "Enter a valid project URL."
        }

        if !normalized(repositoryURL).isEmpty, validatedURL(normalized(repositoryURL)) == nil {
            errors["repository_url"] = "Enter a valid repository URL."
        }

        if includesStartDate, includesEndDate, !isOngoing, encodedDate(endDate) < encodedDate(startDate) {
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
            title: originalText["title"] == title ? nil : normalized(title).nonEmpty,
            role: originalText["role"] == role ? nil : normalized(role).nonEmpty,
            description: originalText["description"] == description ? nil : normalized(description).nonEmpty,
            startDate: includesStartDate ? encodedDate(startDate) : nil,
            endDate: resolvedEndDate(),
            isOngoing: isOngoing,
            projectURL: validatedURL(normalized(projectURL)),
            repositoryURL: validatedURL(normalized(repositoryURL)),
            organizationName: originalText["organizationName"] == organizationName ? nil : normalized(organizationName).nonEmpty
        )
    }

    private func resolvedEndDate() -> String? {
        guard includesEndDate else {
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
