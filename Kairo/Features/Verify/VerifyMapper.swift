import Foundation

enum VerifyOverviewMapper {
    nonisolated static func map(_ overview: VerifyOverview) -> VerifyOverviewState {
        let sortedRequests = sortRequests(overview.requests)
        let content = VerifyOverviewContent(
            dataSourceLabel: "Live data",
            priorityAction: makePriorityAction(from: sortedRequests),
            requests: sortedRequests.map(makeRequest),
            suggestions: makeSuggestions(from: sortedRequests)
        )

        return .live(
            header: .live,
            content: content,
            isEmpty: sortedRequests.isEmpty
        )
    }

    nonisolated static func errorState(for error: Error, header: VerifyHeader = .live) -> VerifyOverviewState {
        if case .transport = (error as? NetworkError) {
            return .error(
                header: header,
                title: "You're offline",
                message: "Kairo couldn't reach your Verify data. Check your connection and try again."
            )
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError):
                return .error(
                    header: header,
                    title: "Verify unavailable",
                    message: apiError.message
                )
            case .invalidResponse:
                return .error(
                    header: header,
                    title: "Verify unavailable",
                    message: "Kairo received an unexpected Verify response. Please try again."
                )
            case .invalidURL:
                return .error(
                    header: header,
                    title: "Verify unavailable",
                    message: "Kairo's Verify configuration is invalid."
                )
            case .transport, .unavailableInDemoMode:
                return .error(
                    header: header,
                    title: "You're offline",
                    message: "Kairo couldn't reach your Verify data. Check your connection and try again."
                )
            }
        }

        return .error(
            header: header,
            title: "Verify unavailable",
            message: error.localizedDescription
        )
    }

    nonisolated static func requiresSessionRecovery(for error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            return true
        }

        return false
    }

    private nonisolated static func sortRequests(_ requests: [VerifyRequestRecord]) -> [VerifyRequestRecord] {
        requests.sorted { lhs, rhs in
            if lhs.status.group != rhs.status.group {
                return groupRank(lhs.status.group) < groupRank(rhs.status.group)
            }

            if lhs.status.rank != rhs.status.rank {
                return lhs.status.rank < rhs.status.rank
            }

            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.id < rhs.id
        }
    }

    private nonisolated static func groupRank(_ group: VerifyRequestGroup) -> Int {
        switch group {
        case .pending:
            0
        case .inProgress:
            1
        case .completed:
            2
        }
    }

    private nonisolated static func makePriorityAction(from requests: [VerifyRequestRecord]) -> VerifyPriorityAction {
        if let actionable = requests.first(where: { !$0.availableActions.isEmpty }) {
            return VerifyPriorityAction(
                title: priorityTitle(for: actionable),
                organization: actionable.organizationName,
                supportingCopy: requiredActionText(for: actionable.status),
                trustImpact: "Action required",
                estimatedCompletionTime: actionable.dueDate.map(dueDateLabel) ?? updatedLabel(for: actionable.updatedAt),
                statusTitle: actionable.status.style.title,
                actionTitle: "View request",
                action: .openRequest(actionable.id)
            )
        }

        if let inProgress = requests.first(where: { $0.status.group == .inProgress }) {
            return VerifyPriorityAction(
                title: "Track your latest verification",
                organization: inProgress.organizationName,
                supportingCopy: "Kairo is following the latest live status for this verification request.",
                trustImpact: "Live status",
                estimatedCompletionTime: updatedLabel(for: inProgress.updatedAt),
                statusTitle: inProgress.status.style.title,
                actionTitle: "View request",
                action: .openRequest(inProgress.id)
            )
        }

        if let completed = requests.first(where: { $0.status.group == .completed }) {
            return VerifyPriorityAction(
                title: "Review your latest completed verification",
                organization: completed.organizationName,
                supportingCopy: "Completed verifications stay here as a reusable part of your Trust Passport.",
                trustImpact: "Completed",
                estimatedCompletionTime: updatedLabel(for: completed.updatedAt),
                statusTitle: completed.status.style.title,
                actionTitle: "View request",
                action: .openRequest(completed.id)
            )
        }

        return VerifyPriorityAction(
            title: "No verification requests yet",
            organization: "Trust Center",
            supportingCopy: "Kairo will surface employment and education verification requests here once they exist for your records.",
            trustImpact: "Live status",
            estimatedCompletionTime: "No action needed",
            statusTitle: "Up to date",
            actionTitle: "Continue profile",
            action: .openCareer
        )
    }

    private nonisolated static func priorityTitle(for request: VerifyRequestRecord) -> String {
        switch request.status {
        case .pendingSubjectAcceptance:
            return "Review your \(request.typeTitle.lowercased())"
        case .awaitingInformation:
            return "Provide the information requested"
        case .accepted, .pendingSubjectSubmission:
            return "Submit your verification for review"
        case .awaitingSubjectCorrections:
            return "Resubmit your verification"
        default:
            return "Continue your \(request.typeTitle.lowercased())"
        }
    }

    private nonisolated static func makeSuggestions(from requests: [VerifyRequestRecord]) -> [VerifySuggestion] {
        if requests.isEmpty {
            return []
        }

        return []
    }

    private nonisolated static func makeRequest(_ record: VerifyRequestRecord) -> VerifyRequest {
        VerifyRequest(
            id: record.id,
            routeRequestID: record.routeID,
            type: record.typeTitle,
            organization: record.organizationName,
            requester: record.requesterName,
            requestedItem: record.requestedItem,
            status: record.status,
            dateLabel: record.dueDate.map(dueDateLabel) ?? updatedLabel(for: record.updatedAt),
            timelineSummary: timelineSummary(for: record),
            requiredAction: requiredActionText(for: record.status),
            supportingNote: supportingNote(for: record),
            evidenceRequirement: evidenceRequirement(for: record),
            timeline: record.timeline.map(makeTimelineEvent),
            availableActions: record.availableActions
        )
    }

    private nonisolated static func timelineSummary(for record: VerifyRequestRecord) -> String {
        if let lastEvent = record.timeline.max(by: { $0.createdAt < $1.createdAt }) {
            return humanizeTimelineEvent(lastEvent.eventType)
        }

        return "Updated \(shortDateFormatter.string(from: record.updatedAt))"
    }

    private nonisolated static func supportingNote(for record: VerifyRequestRecord) -> String {
        if let response = record.candidateResponse?.trimmingCharacters(in: .whitespacesAndNewlines),
           !response.isEmpty {
            return response
        }

        if let acceptedAt = record.acceptedAt {
            return "Accepted on \(fullDateFormatter.string(from: acceptedAt))."
        }

        return "Kairo is reflecting the current backend status for this verification request."
    }

    private nonisolated static func evidenceRequirement(for record: VerifyRequestRecord) -> String {
        if !record.consentedFields.isEmpty {
            return "Requested fields: \(record.consentedFields.joined(separator: ", "))"
        }

        if !record.consentedEvidenceScope.isEmpty {
            return "Requested evidence: \(record.consentedEvidenceScope.joined(separator: ", "))"
        }

        if !record.evidenceSummary.fieldKeys.isEmpty {
            return "Evidence fields on file: \(record.evidenceSummary.fieldKeys.joined(separator: ", "))"
        }

        if record.evidenceSummary.totalItems > 0 {
            let itemLabel = record.evidenceSummary.totalItems == 1 ? "item" : "items"
            return "Evidence on file: \(record.evidenceSummary.totalItems) \(itemLabel)"
        }

        return "No specific evidence requirements were provided yet."
    }

    private nonisolated static func makeTimelineEvent(_ record: VerifyTimelineEventRecord) -> VerifyTimelineEvent {
        VerifyTimelineEvent(
            id: record.id,
            title: record.newStatus?.style.title ?? humanizeTimelineEvent(record.eventType),
            source: humanizeEventSource(record.eventSource),
            dateLabel: fullDateFormatter.string(from: record.createdAt)
        )
    }

    private nonisolated static func humanizeTimelineEvent(_ rawValue: String) -> String {
        rawValue
            .split(separator: "_")
            .map { token in
                token.prefix(1).uppercased() + token.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private nonisolated static func humanizeEventSource(_ rawValue: String) -> String {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "candidate":
            return "You"
        case "organization":
            return "Organisation"
        case "admin":
            return "Kairo review team"
        case "system":
            return "Kairo"
        case "ai":
            return "Kairo assistant"
        default:
            return rawValue
        }
    }

    private nonisolated static func requiredActionText(for status: VerifyVerificationStatus) -> String {
        switch status {
        case .draft:
            return "Complete this verification request before it can move forward."
        case .pendingSubjectAcceptance:
            return "Review and accept this verification request to continue."
        case .accepted, .pendingSubjectSubmission:
            return "Submit the requested information and evidence for review."
        case .awaitingInformation:
            return "Provide the information Kairo requested for this verification."
        case .awaitingSubjectCorrections:
            return "Update the requested details and resubmit for review."
        case .pendingAdminReview,
             .pendingAdminReReview,
             .approvedForOrganizationVerification,
             .pendingOrganizationResolution,
             .pendingOrganizationAcceptance,
             .inProgress,
             .unknown:
            return "No action is needed from you right now."
        case .verified, .rejected, .unableToVerify, .cancelled, .expired:
            return "No further action is needed."
        }
    }

    private nonisolated static func updatedLabel(for date: Date) -> String {
        "Updated \(shortDateFormatter.string(from: date))"
    }

    private nonisolated static func dueDateLabel(for date: Date) -> String {
        "Due \(shortDateFormatter.string(from: date))"
    }

    private nonisolated static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private nonisolated static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d MMM yyyy, h:mm a"
        return formatter
    }()
}

private extension VerifyRequestRecord {
    var availableActions: [VerifyRequestAction] {
        guard routeID != nil else {
            return []
        }

        switch status {
        case .pendingSubjectAcceptance:
            return [.accept]
        case .awaitingInformation:
            return [.submitInformation]
        case .accepted, .pendingSubjectSubmission:
            return [.submitForReview]
        case .awaitingSubjectCorrections:
            return [.resubmitForReview]
        default:
            return []
        }
    }
}
