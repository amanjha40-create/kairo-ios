import Foundation

nonisolated struct ManualProfileSubmissionPayloads: Equatable, Sendable {
    nonisolated struct EmploymentItem: Equatable, Sendable {
        let entryID: Int
        let request: ManualEmploymentCreateRequestDTO
    }

    nonisolated struct EducationItem: Equatable, Sendable {
        let entryID: Int
        let request: ManualEducationCreateRequestDTO
    }

    let profile: OnboardingProfileUpdateRequestDTO
    let employments: [EmploymentItem]
    let educations: [EducationItem]
}

nonisolated enum ManualProfileMappingError: Error, Equatable, Sendable {
    case missingFullName
    case basic(field: ManualProfileBasicField, message: String)
    case employment(entryID: Int, field: ManualEmploymentField, message: String)
    case education(entryID: Int, field: ManualEducationField, message: String)
}

nonisolated enum ManualProfileMapper {
    private nonisolated static let calendar = Calendar(identifier: .gregorian)
    private nonisolated static let englishLocale = Locale(identifier: "en_US_POSIX")
    private nonisolated static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    nonisolated static func makeRemainingProfileDraft(
        currentUser: AppUser,
        signupDraftFullName: String?,
        employments: [CareerEmploymentDTO],
        educations: [CareerEducationDTO]
    ) -> ManualProfileFlowState {
        let locationParts = fallbackLocationParts(from: currentUser.location)
        let basicProfile = ManualProfileBasicDraft(
            fullName: ManualProfileNormalization.normalized(currentUser.fullName ?? "").nonEmpty
                ?? ManualProfileNormalization.normalized(signupDraftFullName ?? ""),
            professionalHeadline: ManualProfileNormalization.normalized(currentUser.headline ?? ""),
            currentRole: ManualProfileNormalization.normalized(currentUser.currentRole ?? ""),
            industry: ManualProfileNormalization.normalized(currentUser.industry ?? ""),
            yearsOfExperience: currentUser.yearsOfExperience.map(String.init) ?? "",
            currentCity: ManualProfileNormalization.normalized(
                currentUser.locationCity ?? locationParts.city ?? ""
            ),
            currentCountry: ManualProfileNormalization.normalized(
                displayCountry(currentUser.locationCountry) ?? locationParts.country ?? ""
            )
        )

        let employmentEntries = employments.enumerated().map { index, employment in
            manualEmploymentEntry(from: employment, id: index)
        }
        let educationEntries = educations.enumerated().map { index, education in
            manualEducationEntry(from: education, id: index)
        }

        return ManualProfileFlowState(
            step: .basicProfile,
            basicProfile: basicProfile,
            employmentEntries: employmentEntries,
            educationEntries: educationEntries,
            nextEmploymentID: employmentEntries.count,
            nextEducationID: educationEntries.count
        )
    }

    nonisolated static func makeSubmissionPayloads(
        draft: ManualProfileFlowState,
        currentUser: AppUser
    ) throws -> ManualProfileSubmissionPayloads {
        let normalizedFullName = ManualProfileNormalization.normalized(draft.basicProfile.fullName)
            .nonEmpty
            ?? currentUser.fullName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty

        guard let normalizedFullName else {
            throw ManualProfileMappingError.missingFullName
        }

        let normalizedCity = ManualProfileNormalization.normalized(draft.basicProfile.currentCity)
        let normalizedCountry = ManualProfileNormalization.normalized(draft.basicProfile.currentCountry)
        let location = [normalizedCity, normalizedCountry]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .nonEmpty

        guard let yearsOfExperience = ManualProfileValidation.normalizedYearsOfExperience(
            draft.basicProfile.yearsOfExperience
        ) else {
            throw ManualProfileMappingError.basic(
                field: .yearsOfExperience,
                message: "Enter valid whole years of experience."
            )
        }

        let profile = OnboardingProfileUpdateRequestDTO(
            fullName: normalizedFullName,
            currentRole: ManualProfileNormalization.normalized(draft.basicProfile.currentRole),
            industry: ManualProfileNormalization.normalized(draft.basicProfile.industry),
            yearsOfExperience: yearsOfExperience,
            location: location,
            locationCity: normalizedCity.nonEmpty,
            locationCountry: ManualProfileNormalization.normalizedCountryCode(normalizedCountry),
            headline: ManualProfileNormalization.normalized(draft.basicProfile.professionalHeadline)
        )

        let employments: [ManualProfileSubmissionPayloads.EmploymentItem] = try draft.employmentEntries.compactMap { entry in
            guard !entry.isPersisted else {
                return nil
            }

            return try ManualProfileSubmissionPayloads.EmploymentItem(
                entryID: entry.id,
                request: mapEmploymentRequest(
                    entry: entry,
                    subjectFullName: normalizedFullName,
                    subjectEmail: currentUser.email
                )
            )
        }

        let educations: [ManualProfileSubmissionPayloads.EducationItem] = try draft.educationEntries.compactMap { entry in
            guard !entry.isPersisted else {
                return nil
            }

            return try ManualProfileSubmissionPayloads.EducationItem(
                entryID: entry.id,
                request: mapEducationRequest(entry: entry)
            )
        }

        return ManualProfileSubmissionPayloads(
            profile: profile,
            employments: employments,
            educations: educations
        )
    }

    nonisolated static func employmentFingerprint(
        request: ManualEmploymentCreateRequestDTO
    ) -> ManualEmploymentFingerprint {
        ManualEmploymentFingerprint(
            subjectFullName: ManualProfileNormalization.normalized(request.subjectFullName).lowercased(),
            subjectEmail: ManualProfileNormalization.normalized(request.subjectEmail ?? "").lowercased(),
            employerLegalName: ManualProfileNormalization.normalized(request.employerLegalName).lowercased(),
            jobTitle: ManualProfileNormalization.normalized(request.jobTitle).lowercased(),
            employmentType: request.employmentType,
            startDate: request.startDate,
            endDate: request.endDate ?? "",
            workLocationCountry: request.workLocationCountry,
            workLocationRegion: ManualProfileNormalization.normalized(request.workLocationRegion ?? "").lowercased()
        )
    }

    nonisolated static func employmentFingerprint(
        dto: CareerEmploymentDTO,
        currentUser: AppUser
    ) -> ManualEmploymentFingerprint {
        ManualEmploymentFingerprint(
            subjectFullName: ManualProfileNormalization.normalized(currentUser.fullName ?? "").lowercased(),
            subjectEmail: ManualProfileNormalization.normalized(currentUser.email).lowercased(),
            employerLegalName: ManualProfileNormalization.normalized(
                dto.employerLegalName ?? dto.companyDisplayName
            ).lowercased(),
            jobTitle: ManualProfileNormalization.normalized(dto.jobTitle).lowercased(),
            employmentType: dto.employmentType ?? "",
            startDate: dto.startDate.map(dateFormatter.string(from:)) ?? "",
            endDate: dto.endDate.map(dateFormatter.string(from:)) ?? "",
            workLocationCountry: dto.workLocationCountry ?? "",
            workLocationRegion: ManualProfileNormalization.normalized(dto.workLocationRegion ?? "").lowercased()
        )
    }

    nonisolated static func educationFingerprint(
        request: ManualEducationCreateRequestDTO
    ) -> ManualEducationFingerprint {
        ManualEducationFingerprint(
            institutionName: ManualProfileNormalization.normalized(request.institutionName).lowercased(),
            degree: ManualProfileNormalization.normalized(request.degree).lowercased(),
            educationLevel: request.educationLevel,
            fieldOfStudy: ManualProfileNormalization.normalized(request.fieldOfStudy ?? "").lowercased(),
            startDate: request.startDate,
            startDatePrecision: request.startDatePrecision ?? "",
            endDate: request.endDate ?? "",
            endDatePrecision: request.endDatePrecision ?? "",
            isCurrentlyStudying: request.isCurrentlyStudying
        )
    }

    nonisolated static func educationFingerprint(dto: CareerEducationDTO) -> ManualEducationFingerprint {
        ManualEducationFingerprint(
            institutionName: ManualProfileNormalization.normalized(dto.institutionName).lowercased(),
            degree: ManualProfileNormalization.normalized(dto.degree ?? "").lowercased(),
            educationLevel: dto.educationLevel ?? "",
            fieldOfStudy: ManualProfileNormalization.normalized(dto.fieldOfStudy ?? "").lowercased(),
            startDate: dto.startDate.map(dateFormatter.string(from:)) ?? "",
            startDatePrecision: dto.startDatePrecision ?? "",
            endDate: dto.endDate.map(dateFormatter.string(from:)) ?? "",
            endDatePrecision: dto.endDatePrecision ?? "",
            isCurrentlyStudying: dto.isCurrentlyStudying
        )
    }

    private nonisolated static func mapEmploymentRequest(
        entry: ManualEmploymentEntry,
        subjectFullName: String,
        subjectEmail: String
    ) throws -> ManualEmploymentCreateRequestDTO {
        guard let employmentType = ManualProfileNormalization.normalizedEmploymentType(entry.employmentType) else {
            throw ManualProfileMappingError.employment(
                entryID: entry.id,
                field: .employmentType,
                message: "Choose a supported employment type."
            )
        }

        guard let workCountry = ManualProfileNormalization.normalizedCountryCode(entry.workCountry) else {
            throw ManualProfileMappingError.employment(
                entryID: entry.id,
                field: .workCountry,
                message: "Enter a valid country."
            )
        }

        let startDate = try employmentDate(
            entryID: entry.id,
            day: entry.startDay,
            month: entry.startMonth,
            year: entry.startYear,
            field: .startDay,
            emptyMessage: "Enter a valid start date."
        )
        let endDate = entry.isCurrentlyWorking
            ? nil
            : try employmentDate(
                entryID: entry.id,
                day: entry.endDay,
                month: entry.endMonth,
                year: entry.endYear,
                field: .endDay,
                emptyMessage: "Enter a valid end date."
            )

        return ManualEmploymentCreateRequestDTO(
            subjectFullName: subjectFullName,
            subjectEmail: subjectEmail,
            employerLegalName: ManualProfileNormalization.normalized(entry.company),
            employerTradeName: nil,
            jobTitle: ManualProfileNormalization.normalized(entry.jobTitle),
            employmentType: employmentType,
            verificationMethod: "document",
            startDate: dateFormatter.string(from: startDate),
            endDate: endDate.map(dateFormatter.string(from:)),
            workLocationCountry: workCountry,
            workLocationRegion: nil
        )
    }

    private nonisolated static func mapEducationRequest(
        entry: ManualEducationEntry
    ) throws -> ManualEducationCreateRequestDTO {
        guard let educationLevel = ManualProfileNormalization.normalizedEducationLevel(entry.educationLevel) else {
            throw ManualProfileMappingError.education(
                entryID: entry.id,
                field: .educationLevel,
                message: "Choose a supported education level."
            )
        }

        guard
            let startYear = Int(ManualProfileNormalization.normalized(entry.startYear)),
            let endYear = Int(ManualProfileNormalization.normalized(entry.endYear))
        else {
            throw ManualProfileMappingError.education(
                entryID: entry.id,
                field: .startYear,
                message: "Enter valid education years."
            )
        }

        return ManualEducationCreateRequestDTO(
            institutionName: ManualProfileNormalization.normalized(entry.institution),
            degree: ManualProfileNormalization.normalized(entry.degree),
            fieldOfStudy: ManualProfileNormalization.normalized(entry.fieldOfStudy).nonEmpty,
            educationLevel: educationLevel,
            grade: nil,
            startDate: formattedYearDate(startYear),
            startDatePrecision: "year",
            endDate: formattedYearDate(endYear),
            endDatePrecision: "year",
            isCurrentlyStudying: false
        )
    }

    private nonisolated static func manualEmploymentEntry(
        from dto: CareerEmploymentDTO,
        id: Int
    ) -> ManualEmploymentEntry {
        var entry = ManualEmploymentEntry.blank(id: id)
        entry.isPersisted = true
        entry.company = ManualProfileNormalization.normalized(
            dto.employerLegalName ?? dto.companyDisplayName
        )
        entry.jobTitle = ManualProfileNormalization.normalized(dto.jobTitle)
        entry.employmentType = displayEmploymentType(dto.employmentType)
        entry.workCountry = displayCountry(dto.workLocationCountry) ?? ""
        if let startDate = dto.startDate {
            entry.startDay = calendar.component(.day, from: startDate).description
            entry.startMonth = monthName(from: startDate)
            entry.startYear = calendar.component(.year, from: startDate).description
        }
        if let endDate = dto.endDate {
            entry.endDay = calendar.component(.day, from: endDate).description
            entry.endMonth = monthName(from: endDate)
            entry.endYear = calendar.component(.year, from: endDate).description
            entry.isCurrentlyWorking = false
        } else {
            entry.isCurrentlyWorking = true
        }
        return entry
    }

    private nonisolated static func manualEducationEntry(
        from dto: CareerEducationDTO,
        id: Int
    ) -> ManualEducationEntry {
        var entry = ManualEducationEntry.blank(id: id)
        entry.isPersisted = true
        entry.institution = ManualProfileNormalization.normalized(dto.institutionName)
        entry.degree = ManualProfileNormalization.normalized(dto.degree ?? "")
        entry.educationLevel = displayEducationLevel(dto.educationLevel)
        entry.fieldOfStudy = ManualProfileNormalization.normalized(dto.fieldOfStudy ?? "")
        if let startDate = dto.startDate {
            entry.startYear = calendar.component(.year, from: startDate).description
        }
        if let endDate = dto.endDate {
            entry.endYear = calendar.component(.year, from: endDate).description
        }
        return entry
    }

    private nonisolated static func monthName(from date: Date) -> String {
        date.formatted(.dateTime.month(.wide).locale(englishLocale))
    }

    private nonisolated static func displayEmploymentType(_ rawValue: String?) -> String {
        switch rawValue?.lowercased() {
        case "full_time": "Full-time"
        case "part_time": "Part-time"
        case "contract": "Contract"
        case "intern": "Internship"
        case "gig": "Gig"
        case "freelance": "Freelance"
        case "other": "Other"
        default: rawValue ?? ""
        }
    }

    private nonisolated static func displayEducationLevel(_ rawValue: String?) -> String {
        switch rawValue?.lowercased() {
        case "high_school": "High School"
        case "diploma": "Diploma"
        case "bachelors": "Bachelor's"
        case "masters": "Master's"
        case "doctorate": "Doctorate"
        case "certification": "Certification"
        case "other": "Other"
        default: rawValue ?? ""
        }
    }

    private nonisolated static func displayCountry(_ rawValue: String?) -> String? {
        guard let normalized = ManualProfileNormalization.normalized(rawValue ?? "").nonEmpty else {
            return nil
        }

        if normalized.count == 2,
           let localizedName = englishLocale.localizedString(
                forRegionCode: normalized.uppercased()
           )?.trimmingCharacters(in: .whitespacesAndNewlines),
           !localizedName.isEmpty {
            return localizedName
        }

        return normalized
    }

    private nonisolated static func fallbackLocationParts(
        from rawLocation: String?
    ) -> (city: String?, country: String?) {
        guard let location = ManualProfileNormalization.normalized(rawLocation ?? "").nonEmpty else {
            return (nil, nil)
        }

        let components = location
            .split(separator: ",")
            .map { ManualProfileNormalization.normalized(String($0)) }
            .filter { !$0.isEmpty }

        guard let first = components.first, let last = components.last else {
            return (nil, nil)
        }

        return (first, last)
    }

    private nonisolated static func employmentDate(
        entryID: Int,
        day: String,
        month: String,
        year: String,
        field: ManualEmploymentField,
        emptyMessage: String
    ) throws -> Date {
        guard
            let resolvedDay = Int(ManualProfileNormalization.normalized(day)),
            let resolvedMonth = resolvedMonthNumber(from: month),
            let resolvedYear = Int(ManualProfileNormalization.normalized(year)),
            let date = calendar.date(
                from: DateComponents(
                    calendar: calendar,
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: resolvedYear,
                    month: resolvedMonth,
                    day: resolvedDay
                )
            )
        else {
            throw ManualProfileMappingError.employment(
                entryID: entryID,
                field: field,
                message: emptyMessage
            )
        }

        return date
    }

    private nonisolated static func resolvedMonthNumber(from value: String) -> Int? {
        ManualProfileNormalization.normalizedMonthNumber(value)
    }

    private nonisolated static func formattedYearDate(_ year: Int) -> String {
        String(format: "%04d-01-01", year)
    }
}

nonisolated struct ManualEmploymentFingerprint: Hashable, Sendable {
    let subjectFullName: String
    let subjectEmail: String
    let employerLegalName: String
    let jobTitle: String
    let employmentType: String
    let startDate: String
    let endDate: String
    let workLocationCountry: String
    let workLocationRegion: String
}

nonisolated struct ManualEducationFingerprint: Hashable, Sendable {
    let institutionName: String
    let degree: String
    let educationLevel: String
    let fieldOfStudy: String
    let startDate: String
    let startDatePrecision: String
    let endDate: String
    let endDatePrecision: String
    let isCurrentlyStudying: Bool
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
