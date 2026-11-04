import Foundation

nonisolated enum ResumeEmploymentDuplicateDecision: Equatable, Sendable {
    case keepExisting
    case addAsNewRole

    var title: String {
        switch self {
        case .keepExisting:
            "Keep existing"
        case .addAsNewRole:
            "Add as new role"
        }
    }
}

nonisolated struct ResumeEmploymentSummary: Equatable, Sendable {
    let employer: String?
    let role: String?
    let dates: String?
    let location: String?

    var accessibilitySummary: String {
        [employer, role, dates, location]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

nonisolated enum ResumeEmploymentDuplicateReviewState: Equatable, Sendable {
    case noConflict
    case alreadyInCareer(existing: ResumeEmploymentSummary?)
    case possibleMatch(
        existing: ResumeEmploymentSummary?,
        imported: ResumeEmploymentSummary,
        decision: ResumeEmploymentDuplicateDecision
    )

    var allowsAddAsNewRole: Bool {
        if case .possibleMatch = self {
            return true
        }
        return false
    }

    var selectedDecision: ResumeEmploymentDuplicateDecision? {
        guard case .possibleMatch(_, _, let decision) = self else {
            return nil
        }
        return decision
    }
}

nonisolated enum ResumeReviewedOutcome: String, Equatable, Sendable {
    case alreadyInCareer = "Already in Career"
    case keepExisting = "Keep existing"
    case addAsNewRole = "Add as new role"
    case `import` = "Import"
    case skip = "Skip"
}

nonisolated enum ResumeImportResultOutcome: String, Equatable, Sendable {
    case added = "Added"
    case alreadyInCareer = "Already in Career"
    case skipped = "Skipped"
    case updated = "Updated"
    case needsAttention = "Needs attention"
}

nonisolated struct ResumeEmploymentDecisionSubmissionGate: Equatable, Sendable {
    private(set) var inFlightItemID: String?

    mutating func begin(itemID: String) -> Bool {
        guard inFlightItemID == nil else {
            return false
        }
        inFlightItemID = itemID
        return true
    }

    mutating func finish(itemID: String) {
        guard inFlightItemID == itemID else {
            return
        }
        inFlightItemID = nil
    }
}

nonisolated struct ResumeImportResultSummary: Equatable, Sendable {
    let added: Int
    let alreadyInCareer: Int
    let skipped: Int
    let updated: Int
    let needsAttention: Int

    init(batch: ResumeImportBatch) {
        added = batch.importedCount
        alreadyInCareer = batch.linkedCount
        skipped = batch.skippedCount
        updated = batch.results.filter { Self.outcome(for: $0) == .updated }.count
        needsAttention = batch.failedCount + batch.blockedCount + batch.incompleteCount
    }

    var outcomeMessage: String {
        if added == 0, alreadyInCareer == 0, updated == 0 {
            if skipped == 0, needsAttention == 0 {
                return "No Career records were added from this resume."
            }

            let skippedCopy = Self.itemCount(skipped, singular: "item was skipped", plural: "items were skipped")
            let attentionCopy = Self.itemCount(
                needsAttention,
                singular: "item needs attention",
                plural: "items need attention"
            )
            let details = [skippedCopy, attentionCopy].compactMap { $0 }.joined(separator: " ")
            return "No Career records were added. \(details)"
        }

        var outcomes: [String] = []
        if let addedCopy = Self.itemCount(added, singular: "record was added", plural: "records were added") {
            outcomes.append(addedCopy)
        }
        if let linkedCopy = Self.itemCount(
            alreadyInCareer,
            singular: "item was already in Career",
            plural: "items were already in Career"
        ) {
            outcomes.append(linkedCopy)
        }
        if let updatedCopy = Self.itemCount(updated, singular: "record was updated", plural: "records were updated") {
            outcomes.append(updatedCopy)
        }
        if let skippedCopy = Self.itemCount(skipped, singular: "item was skipped", plural: "items were skipped") {
            outcomes.append(skippedCopy)
        }
        if let attentionCopy = Self.itemCount(
            needsAttention,
            singular: "item needs attention",
            plural: "items need attention"
        ) {
            outcomes.append(attentionCopy)
        }
        return outcomes.joined(separator: " ")
    }

    static func outcome(for result: ResumeImportResultItem) -> ResumeImportResultOutcome {
        switch result.outcome.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "imported", "created", "added":
            .added
        case "linked", "already_exists", "existing":
            .alreadyInCareer
        case "skipped":
            .skipped
        case "updated", "reviewed":
            .updated
        default:
            .needsAttention
        }
    }

    private static func itemCount(_ count: Int, singular: String, plural: String) -> String? {
        guard count > 0 else { return nil }
        return "\(count) \(count == 1 ? singular : plural)."
    }
}

nonisolated enum ResumePostImportCareerRefresh {
    static func loadAuthoritativeOverview<Value: Sendable>(
        using loader: @Sendable () async throws -> Value
    ) async throws -> Value {
        try await loader()
    }
}
