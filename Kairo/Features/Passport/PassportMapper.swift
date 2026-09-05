import Foundation

enum PassportOverviewMapper {
    nonisolated static func map(_ overview: PassportOverview) -> PassportOverviewState {
        let header = makeHeader(from: overview)
        let content = PassportOverviewContent(
            dataSourceLabel: "Live data",
            trustScore: makeTrustScoreContent(from: overview.trustScore),
            strengthSummary: makeStrengthSummary(from: overview),
            identity: makeIdentityDetails(from: overview),
            employment: overview.vault.employments.map(makeEmploymentRecord),
            education: overview.vault.educations.map(makeEducationRecord),
            certifications: overview.vault.certifications.map(makeCertificationRecord),
            skills: overview.vault.skills.map(makeSkillRecord),
            projects: overview.vault.projects.map(makeProjectRecord),
            timeline: .unavailable(
                PassportUnavailableSectionState(
                    title: "Trust timeline not available yet",
                    message: "Kairo's owner Passport response does not currently provide a unified activity timeline."
                )
            )
        )

        return .live(
            header: header,
            dataSourceLabel: "Live data",
            content: content,
            isEmpty: isEmpty(overview: overview)
        )
    }

    nonisolated static func errorState(for error: Error, header: PassportHeader) -> PassportOverviewState {
        if error is DecodingError {
            return .error(
                header: header,
                title: "Trust Passport unavailable",
                message: "Kairo received an unexpected Passport response. Please try again."
            )
        }

        if case .transport = (error as? NetworkError) {
            return .error(
                header: header,
                title: "You're offline",
                message: "Kairo couldn't reach your Trust Passport. Check your connection and try again."
            )
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError):
                return .error(
                    header: header,
                    title: "Trust Passport unavailable",
                    message: apiError.message
                )
            case .invalidResponse:
                return .error(
                    header: header,
                    title: "Trust Passport unavailable",
                    message: "Kairo received an unexpected Passport response. Please try again."
                )
            case .invalidURL:
                return .error(
                    header: header,
                    title: "Trust Passport unavailable",
                    message: "Kairo's Passport configuration is invalid."
                )
            case .transport, .unavailableInDemoMode:
                return .error(
                    header: header,
                    title: "You're offline",
                    message: "Kairo couldn't reach your Trust Passport. Check your connection and try again."
                )
            }
        }

        return .error(
            header: header,
            title: "Trust Passport unavailable",
            message: error.localizedDescription
        )
    }

    nonisolated static func requiresSessionRecovery(for error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            return true
        }

        return false
    }

    nonisolated static func cachedHeader(from user: AppUser?) -> PassportHeader {
        guard let user else {
            return .fixture
        }

        return PassportHeader(
            initials: initials(from: user),
            name: displayName(from: user),
            professionalHeadline: user.headline ?? user.currentRole ?? "Professional headline not added yet",
            location: location(from: user),
            status: user.isActive ? .active : .pendingVerification,
            identityTreatment: "Reusable professional identity",
            avatarURL: url(from: user.avatarURL)
        )
    }

    private nonisolated static func makeHeader(from overview: PassportOverview) -> PassportHeader {
        PassportHeader(
            initials: initials(from: overview.user),
            name: displayName(from: overview.user),
            professionalHeadline: overview.user.headline ?? overview.user.currentRole ?? "Professional headline not added yet",
            location: location(from: overview.user),
            status: overview.metadata.isOnboardingComplete ? .active : .pendingVerification,
            identityTreatment: "Reusable professional identity",
            avatarURL: url(from: overview.user.avatarURL)
        )
    }

    private nonisolated static func makeTrustScoreContent(
        from trustScore: PassportOverview.TrustScore
    ) -> PassportTrustScoreContent {
        guard let overall = trustScore.overall else {
            return .unavailable(
                PassportTrustScoreUnavailableState(
                    title: unavailableTrustScoreTitle(for: trustScore.status),
                    message: unavailableTrustScoreMessage(for: trustScore)
                )
            )
        }

        return .available(
            PassportTrustScore(
                value: overall,
                status: trustScoreStatusTitle(for: trustScore.status),
                progress: min(max(Double(overall) / 100.0, 0.0), 1.0),
                supportingCopy: trustScoreSupportingCopy(for: trustScore),
                isFixture: false
            )
        )
    }

    private nonisolated static func makeStrengthSummary(from overview: PassportOverview) -> [PassportStrengthItem] {
        let emailVerified = overview.metadata.isEmailVerified || overview.user.emailVerifiedAt != nil
        let mobileVerified = overview.user.phoneVerifiedAt != nil
        let identityStatus: PassportVerificationStatus

        if emailVerified && mobileVerified {
            identityStatus = .verified
        } else if emailVerified || mobileVerified {
            identityStatus = .pendingVerification
        } else {
            identityStatus = .notVerified
        }

        return [
            PassportStrengthItem(
                title: "Identity",
                value: identityStatus.style.title,
                status: identityStatus
            ),
            PassportStrengthItem(
                title: "Email",
                value: emailVerified ? "Verified" : "Not verified",
                status: emailVerified ? .verified : .notVerified
            ),
            PassportStrengthItem(
                title: "Mobile",
                value: mobileVerified ? "Verified" : "Not verified",
                status: mobileVerified ? .verified : .notVerified
            ),
            makeStrengthItem(title: "Employment", summary: overview.verificationSummary.employments),
            makeStrengthItem(title: "Education", summary: overview.verificationSummary.educations),
            makeStrengthItem(title: "Certifications", summary: overview.verificationSummary.certifications),
            makeStrengthItem(title: "Projects", summary: overview.verificationSummary.projects),
            makeStrengthItem(title: "Skills", summary: overview.verificationSummary.skills),
            PassportStrengthItem(
                title: "Profile",
                value: overview.metadata.isOnboardingComplete ? "Complete" : "In progress",
                status: overview.metadata.isOnboardingComplete ? .complete : .pendingVerification
            )
        ]
    }

    private nonisolated static func makeStrengthItem(
        title: String,
        summary: PassportOverview.VerificationSummary.SectionSummary
    ) -> PassportStrengthItem {
        let counts = aggregateStatusCounts(from: summary.statuses)
        let value: String
        let status: PassportVerificationStatus

        if summary.total == 0 {
            value = "No records yet"
            status = .notVerified
        } else {
            var parts: [String] = []
            if counts.verified > 0 {
                parts.append("\(counts.verified) verified")
            }
            if counts.pending > 0 {
                parts.append("\(counts.pending) pending")
            }
            if counts.notVerified > 0 {
                parts.append("\(counts.notVerified) not verified")
            }
            value = parts.isEmpty ? "\(summary.total) record(s)" : parts.joined(separator: ", ")

            if counts.verified == summary.total {
                status = .verified
            } else if counts.pending > 0 || counts.verified > 0 {
                status = .pendingVerification
            } else {
                status = .notVerified
            }
        }

        return PassportStrengthItem(title: title, value: value, status: status)
    }

    private nonisolated static func makeIdentityDetails(from overview: PassportOverview) -> PassportIdentityDetails {
        let emailVerified = overview.metadata.isEmailVerified || overview.user.emailVerifiedAt != nil
        let phoneVerified = overview.user.phoneVerifiedAt != nil
        let status: PassportVerificationStatus

        if emailVerified && phoneVerified {
            status = .verified
        } else if emailVerified || phoneVerified {
            status = .pendingVerification
        } else {
            status = .notVerified
        }

        let verifiedDates = [overview.user.emailVerifiedAt, overview.user.phoneVerifiedAt].compactMap { $0 }

        return PassportIdentityDetails(
            fullName: displayName(from: overview.user),
            emailAddress: emailVerified ? overview.user.email : "\(overview.user.email) (not verified)",
            mobileNumber: mobileDisplay(from: overview.user, isVerified: phoneVerified),
            status: status,
            lastVerifiedDate: verifiedDates.max().map(longDateFormatter.string(from:)) ?? "Not verified yet"
        )
    }

    private nonisolated static func makeEmploymentRecord(_ record: PassportEmploymentRecordDomain) -> PassportEmploymentRecord {
        PassportEmploymentRecord(
            company: record.company,
            role: record.role,
            dateRange: monthYearRange(startDate: record.startDate, endDate: record.endDate, isCurrent: record.endDate == nil),
            verificationStatus: presentationStatus(from: record.verificationStatus),
            evidenceSummary: employmentEvidenceSummary(for: record)
        )
    }

    private nonisolated static func makeEducationRecord(_ record: PassportEducationRecordDomain) -> PassportEducationRecord {
        PassportEducationRecord(
            institution: record.institution,
            qualification: qualification(for: record),
            dateRange: educationDateRange(for: record),
            verificationStatus: presentationStatus(from: record.verificationStatus),
            evidenceSummary: educationEvidenceSummary(for: record)
        )
    }

    private nonisolated static func makeCertificationRecord(_ record: PassportCertificationRecordDomain) -> PassportCertificationRecord {
        PassportCertificationRecord(
            title: record.title,
            issuer: record.issuer ?? "Issuer not added yet",
            issueDate: certificationIssueDate(for: record),
            verificationStatus: presentationStatus(from: record.verificationStatus),
            evidenceSummary: certificationEvidenceSummary(for: record)
        )
    }

    private nonisolated static func makeProjectRecord(_ record: PassportProjectRecordDomain) -> PassportProjectRecord {
        PassportProjectRecord(
            title: record.title,
            role: record.role ?? "Role not added yet",
            date: monthYearRange(startDate: record.startDate, endDate: record.endDate, isCurrent: record.isOngoing),
            evidenceStatus: projectEvidenceSummary(for: record),
            portfolioLinkTitle: projectLinkTitle(for: record)
        )
    }

    private nonisolated static func makeSkillRecord(_ record: PassportSkillRecordDomain) -> PassportSkillRecord {
        PassportSkillRecord(
            name: record.name,
            verificationStatus: presentationStatus(from: record.verificationStatus)
        )
    }

    private nonisolated static func isEmpty(overview: PassportOverview) -> Bool {
        overview.vault.employments.isEmpty &&
            overview.vault.educations.isEmpty &&
            overview.vault.certifications.isEmpty &&
            overview.vault.projects.isEmpty &&
            overview.vault.skills.isEmpty
    }

    private nonisolated static func presentationStatus(
        from status: PassportRecordVerificationStatus
    ) -> PassportVerificationStatus {
        switch status {
        case .verified:
            .verified
        case .pending:
            .pendingVerification
        case .notVerified:
            .notVerified
        }
    }

    private nonisolated static func unavailableTrustScoreTitle(
        for status: PassportOverview.TrustScore.Status
    ) -> String {
        switch status {
        case .consentRequired:
            return "Consent required"
        case .incompleteVerification:
            return "Verification in progress"
        case .calculated:
            return "Trust Score unavailable"
        case .criticalManualFraudReview:
            return "Under review"
        }
    }

    private nonisolated static func unavailableTrustScoreMessage(
        for trustScore: PassportOverview.TrustScore
    ) -> String {
        switch trustScore.status {
        case .consentRequired:
            return "Kairo needs your consent before it can calculate and share your Trust Score."
        case .incompleteVerification:
            return "Verify more of your professional history to unlock your Trust Score."
        case .calculated:
            return "Kairo has not provided a Trust Score value for this Passport yet."
        case .criticalManualFraudReview:
            return trustScore.manualReviewReason ?? "Kairo is reviewing this Trust Score before it can be shared."
        }
    }

    private nonisolated static func trustScoreStatusTitle(
        for status: PassportOverview.TrustScore.Status
    ) -> String {
        switch status {
        case .consentRequired:
            return "Consent required"
        case .incompleteVerification:
            return "Verification in progress"
        case .calculated:
            return "Actively strengthening"
        case .criticalManualFraudReview:
            return "Under review"
        }
    }

    private nonisolated static func trustScoreSupportingCopy(
        for trustScore: PassportOverview.TrustScore
    ) -> String {
        switch trustScore.status {
        case .consentRequired:
            return "Kairo needs your consent before it can calculate and share your Trust Score."
        case .incompleteVerification:
            return "Verify more of your employment, education, and credentials to strengthen your Trust Score."
        case .calculated:
            return "Your Trust Score reflects the verification progress across your identity and professional history."
        case .criticalManualFraudReview:
            return trustScore.manualReviewReason ?? "Kairo is reviewing this Trust Score before it can be shared."
        }
    }

    private nonisolated static func aggregateStatusCounts(
        from statuses: [String: Int]
    ) -> (verified: Int, pending: Int, notVerified: Int) {
        statuses.reduce(into: (verified: 0, pending: 0, notVerified: 0)) { counts, entry in
            switch PassportRecordVerificationStatus(rawBackendValue: entry.key) {
            case .verified:
                counts.verified += entry.value
            case .pending:
                counts.pending += entry.value
            case .notVerified:
                counts.notVerified += entry.value
            }
        }
    }

    private nonisolated static func employmentEvidenceSummary(
        for record: PassportEmploymentRecordDomain
    ) -> String {
        let documentCount = record.documents.count
        let method = verificationMethodTitle(record.verificationMethod)

        if documentCount > 0, let method {
            return "\(documentCount) supporting document\(documentCount == 1 ? "" : "s") on file. \(method)."
        }
        if documentCount > 0 {
            return "\(documentCount) supporting document\(documentCount == 1 ? "" : "s") on file."
        }
        if let method {
            return method
        }

        return ""
    }

    private nonisolated static func educationEvidenceSummary(
        for record: PassportEducationRecordDomain
    ) -> String {
        if let grade = record.grade {
            return "Grade: \(grade)"
        }
        if let educationLevel = record.educationLevel {
            return educationLevel
        }

        return ""
    }

    private nonisolated static func certificationEvidenceSummary(
        for record: PassportCertificationRecordDomain
    ) -> String {
        if let credentialID = record.credentialID {
            return "Credential ID: \(credentialID)"
        }
        if let host = record.credentialURL?.host, !host.isEmpty {
            return "Credential URL on file (\(host))"
        }
        if record.doesNotExpire {
            return "Does not expire"
        }

        return ""
    }

    private nonisolated static func projectEvidenceSummary(
        for record: PassportProjectRecordDomain
    ) -> String {
        if record.projectURL != nil || record.repositoryURL != nil {
            return "Portfolio link on file"
        }
        if let organizationName = record.organizationName {
            return "Linked to \(organizationName)"
        }

        return ""
    }

    private nonisolated static func projectLinkTitle(for record: PassportProjectRecordDomain) -> String {
        if let host = record.projectURL?.host, !host.isEmpty {
            return host
        }
        if let host = record.repositoryURL?.host, !host.isEmpty {
            return host
        }

        return ""
    }

    private nonisolated static func certificationIssueDate(for record: PassportCertificationRecordDomain) -> String {
        if let issuedDate = record.issuedDate {
            return monthYearFormatter.string(from: issuedDate)
        }
        return "Issue date unavailable"
    }

    private nonisolated static func qualification(for record: PassportEducationRecordDomain) -> String {
        let parts = [record.degree, record.fieldOfStudy]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !parts.isEmpty {
            return parts.joined(separator: " in ")
        }

        if let educationLevel = record.educationLevel {
            return educationLevel
        }

        return "Qualification not added yet"
    }

    private nonisolated static func educationDateRange(for record: PassportEducationRecordDomain) -> String {
        let start = formattedDate(record.startDate, precision: record.startDatePrecision) ?? "Start date unavailable"
        let end: String

        if record.isCurrentlyStudying {
            end = "Present"
        } else {
            end = formattedDate(record.endDate, precision: record.endDatePrecision) ?? "Present"
        }

        return "\(start) – \(end)"
    }

    private nonisolated static func formattedDate(_ date: Date?, precision: String?) -> String? {
        guard let date else {
            return nil
        }

        switch precision?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "year":
            return yearFormatter.string(from: date)
        case "day":
            return dayFormatter.string(from: date)
        default:
            return monthYearFormatter.string(from: date)
        }
    }

    private nonisolated static func monthYearRange(
        startDate: Date?,
        endDate: Date?,
        isCurrent: Bool
    ) -> String {
        let start = startDate.map(monthYearFormatter.string(from:)) ?? "Start date unavailable"
        let end = isCurrent ? "Present" : (endDate.map(monthYearFormatter.string(from:)) ?? "Present")
        return "\(start) – \(end)"
    }

    private nonisolated static func verificationMethodTitle(_ method: String?) -> String? {
        guard let method = method?.trimmingCharacters(in: .whitespacesAndNewlines),
              !method.isEmpty else {
            return nil
        }

        return method
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private nonisolated static func displayName(from user: AppUser) -> String {
        if let fullName = user.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fullName.isEmpty {
            return fullName
        }

        return user.email
    }

    private nonisolated static func location(from user: AppUser) -> String {
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

        return parts.isEmpty ? "Location not added yet" : parts.joined(separator: ", ")
    }

    private nonisolated static func mobileDisplay(from user: AppUser, isVerified: Bool) -> String {
        guard let phone = user.phone?.trimmingCharacters(in: .whitespacesAndNewlines),
              !phone.isEmpty else {
            return "Mobile number not added yet"
        }

        return isVerified ? phone : "\(phone) (not verified)"
    }

    private nonisolated static func initials(from user: AppUser) -> String {
        let parts = (user.fullName ?? user.email)
            .split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." || $0 == "_" })
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }

        let value = parts.joined()
        return value.isEmpty ? "KA" : value
    }

    private nonisolated static func url(from value: String?) -> URL? {
        guard let value else {
            return nil
        }

        return URL(string: value)
    }

    private nonisolated static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    private nonisolated static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private nonisolated static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private nonisolated static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
}
