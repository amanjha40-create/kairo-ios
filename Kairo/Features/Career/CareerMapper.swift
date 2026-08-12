import Foundation

enum CareerOverviewMapper {
    nonisolated static func map(_ overview: CareerOverview) -> CareerOverviewState {
        let content = CareerOverviewContent(
            employment: overview.employments.map(makeEmploymentItem),
            education: overview.educations.map(makeEducationItem),
            certifications: overview.certifications.map(makeCertificationItem),
            projects: overview.projects.map(makeProjectItem),
            skills: overview.skills.map(makeSkillItem)
        )

        return .live(
            summary: makeSummary(from: overview),
            dataSourceLabel: "Live data",
            content: content,
            isEmpty: isEmpty(content: content)
        )
    }

    nonisolated static func errorState(for error: Error, summary: CareerProfessionalSummary) -> CareerOverviewState {
        if case .transport = (error as? NetworkError) {
            return .error(
                summary: summary,
                title: "You're offline",
                message: "Kairo couldn't reach your Career data. Check your connection and try again."
            )
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError):
                return .error(
                    summary: summary,
                    title: "Career overview unavailable",
                    message: apiError.message
                )
            case .invalidResponse:
                return .error(
                    summary: summary,
                    title: "Career overview unavailable",
                    message: "Kairo received an unexpected Career response. Please try again."
                )
            case .invalidURL:
                return .error(
                    summary: summary,
                    title: "Career overview unavailable",
                    message: "Kairo's Career configuration is invalid."
                )
            case .transport, .unavailableInDemoMode:
                return .error(
                    summary: summary,
                    title: "You're offline",
                    message: "Kairo couldn't reach your Career data. Check your connection and try again."
                )
            }
        }

        return .error(
            summary: summary,
            title: "Career overview unavailable",
            message: error.localizedDescription
        )
    }

    nonisolated static func requiresSessionRecovery(for error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            return true
        }

        return false
    }

    private nonisolated static func makeSummary(from overview: CareerOverview) -> CareerProfessionalSummary {
        let user = overview.user
        let currentEmployment = selectCurrentEmployment(from: overview.employments)

        return CareerProfessionalSummary(
            initials: initials(from: user),
            name: displayName(from: user),
            professionalHeadline: user.headline ?? user.currentRole ?? "Professional headline not added yet",
            currentCompany: currentEmployment?.company ?? "Current company not added yet",
            currentLocation: currentLocation(from: user),
            trustPassportStatus: user.isActive ? "Active" : "Pending"
        )
    }

    private nonisolated static func makeEmploymentItem(_ record: CareerEmploymentRecord) -> CareerEmploymentItem {
        CareerEmploymentItem(
            routeID: record.id,
            company: record.company,
            role: record.role,
            dateRange: dateRange(
                startDate: record.startDate,
                endDate: record.endDate,
                isCurrent: record.currentlyWorking
            ),
            verificationStatus: verificationStatus(from: record.verificationStatus),
            allowsEdit: record.allowsCandidateEditing,
            allowsDelete: record.allowsCandidateDeletion
        )
    }

    private nonisolated static func makeEducationItem(_ record: CareerEducationRecord) -> CareerEducationItem {
        let degreeLine = [record.degree, record.fieldOfStudy].compactMap { value -> String? in
            guard let value, !value.isEmpty else {
                return nil
            }

            return value
        }.joined(separator: " in ")

        return CareerEducationItem(
            routeID: record.id,
            institution: record.institution,
            degree: degreeLine.isEmpty ? record.degree : degreeLine,
            dateRange: educationDateRange(
                startDate: record.startDate,
                startPrecision: record.startDatePrecision,
                endDate: record.endDate,
                endPrecision: record.endDatePrecision,
                isCurrent: record.isCurrentlyStudying
            ),
            verificationStatus: verificationStatus(from: record.verificationStatus)
        )
    }

    private nonisolated static func makeCertificationItem(_ record: CareerCertificationRecord) -> CareerCertificationItem {
        CareerCertificationItem(
            routeID: record.id,
            title: record.title,
            issuer: record.issuer,
            issueDate: monthYear(record.issueDate) ?? "Issue date unavailable",
            verificationStatus: verificationStatus(from: record.verificationStatus)
        )
    }

    private nonisolated static func makeProjectItem(_ record: CareerProjectRecord) -> CareerProjectItem {
        CareerProjectItem(
            routeID: record.id,
            title: record.title,
            role: record.role,
            duration: dateRange(
                startDate: record.startDate,
                endDate: record.endDate,
                isCurrent: record.isOngoing
            ),
            portfolioLinkTitle: portfolioLinkTitle(for: record.portfolioURL),
            verificationStatus: record.verificationStatus.map(verificationStatus(from:))
        )
    }

    private nonisolated static func makeSkillItem(_ record: CareerSkillRecord) -> CareerSkillItem {
        CareerSkillItem(
            routeID: record.id,
            name: record.name,
            verificationStatus: verificationStatus(from: record.verificationStatus)
        )
    }

    private nonisolated static func verificationStatus(from status: CareerRecordVerificationStatus) -> CareerVerificationStatus {
        switch status {
        case .verified:
            return .verified
        case .pending:
            return .pendingVerification
        case .notVerified:
            return .notVerified
        }
    }

    private nonisolated static func isEmpty(content: CareerOverviewContent) -> Bool {
        content.employment.isEmpty &&
            content.education.isEmpty &&
            content.certifications.isEmpty &&
            content.projects.isEmpty &&
            content.skills.isEmpty
    }

    private nonisolated static func displayName(from user: AppUser) -> String {
        if let fullName = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fullName.isEmpty {
            return fullName
        }

        return user.email
    }

    private nonisolated static func currentLocation(from user: AppUser) -> String {
        if let location = user.location?.trimmingCharacters(in: .whitespacesAndNewlines),
           !location.isEmpty {
            return location
        }

        let parts = [user.locationCity, user.locationCountry].compactMap { value -> String? in
            guard let value, !value.isEmpty else {
                return nil
            }

            return value
        }

        return parts.isEmpty ? "Current location not added yet" : parts.joined(separator: ", ")
    }

    private nonisolated static func initials(from user: AppUser) -> String {
        let parts = (user.fullName ?? user.email)
            .split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." || $0 == "_" })
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }

        let value = parts.joined()
        return value.isEmpty ? "KA" : value
    }

    private nonisolated static func monthYear(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }

        return monthYearFormatter.string(from: date)
    }

    private nonisolated static func dateRange(startDate: Date?, endDate: Date?, isCurrent: Bool) -> String {
        let start = monthYear(startDate) ?? "Start date unavailable"
        let end = isCurrent ? "Present" : (monthYear(endDate) ?? "Present")
        return "\(start) – \(end)"
    }

    private nonisolated static func selectCurrentEmployment(
        from employments: [CareerEmploymentRecord]
    ) -> CareerEmploymentRecord? {
        let currentEmployments = employments.filter(\.currentlyWorking)
        if !currentEmployments.isEmpty {
            return mostRecentEmployment(in: currentEmployments)
        }

        return mostRecentEmployment(in: employments)
    }

    private nonisolated static func mostRecentEmployment(
        in employments: [CareerEmploymentRecord]
    ) -> CareerEmploymentRecord? {
        employments.max { lhs, rhs in
            employmentSortKey(for: lhs) < employmentSortKey(for: rhs)
        }
    }

    private nonisolated static func employmentSortKey(for employment: CareerEmploymentRecord) -> (Int, Date, String) {
        let hasStartDate = employment.startDate != nil ? 1 : 0
        let startDate = employment.startDate ?? .distantPast
        return (hasStartDate, startDate, employment.id)
    }

    private nonisolated static func yearRange(startYear: Int?, endYear: Int?) -> String {
        let start = startYear.map(String.init) ?? "Start year unavailable"
        let end = endYear.map(String.init) ?? "Present"
        return "\(start) – \(end)"
    }

    private nonisolated static func educationDateRange(
        startDate: Date?,
        startPrecision: String?,
        endDate: Date?,
        endPrecision: String?,
        isCurrent: Bool
    ) -> String {
        let start = formattedEducationDate(startDate, precision: startPrecision) ?? "Start date unavailable"
        let end = isCurrent ? "Present" : (formattedEducationDate(endDate, precision: endPrecision) ?? "Present")
        return "\(start) – \(end)"
    }

    private nonisolated static func formattedEducationDate(_ date: Date?, precision: String?) -> String? {
        guard let date else {
            return nil
        }

        switch CareerDatePrecisionOption(rawValue: precision) {
        case .day:
            return dayMonthYearFormatter.string(from: date)
        case .month:
            return monthYearFormatter.string(from: date)
        case .year:
            return yearFormatter.string(from: date)
        }
    }

    private nonisolated static func portfolioLinkTitle(for url: URL?) -> String {
        if let host = url?.host, !host.isEmpty {
            return host
        }

        return "Portfolio link"
    }

    private nonisolated static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    private nonisolated static let dayMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private nonisolated static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}
