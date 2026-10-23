import Foundation
import UIKit

enum ResumeImportMapper {
    private nonisolated static let hiddenMVPClaimTypes: Set<String> = [
        "internship",
        "freelance",
        "gig_platform"
    ]

    nonisolated static func map(_ dto: ResumeRecordDTO) -> ResumeRecord {
        ResumeRecord(
            id: dto.id,
            originalFilename: dto.originalFilename,
            contentType: dto.contentType,
            fileSizeBytes: dto.fileSizeBytes,
            uploadStatus: ResumeUploadStatus(apiValue: dto.uploadStatus),
            processingStatus: ResumeProcessingStatus(apiValue: dto.processingStatus),
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    nonisolated static func map(_ dto: ResumeUploadIntentDTO) -> ResumeUploadIntent {
        ResumeUploadIntent(
            resumeID: dto.resumeID,
            uploadURL: dto.uploadURL,
            expiresIn: dto.expiresIn,
            objectKey: dto.objectKey
        )
    }

    nonisolated static func map(_ dto: ResumeProcessDTO) -> ResumeProcessJob {
        ResumeProcessJob(
            resumeID: dto.resumeID,
            jobID: dto.jobID,
            status: ResumeProcessingStatus(apiValue: dto.status)
        )
    }

    nonisolated static func map(_ dto: ResumeParsedResultDTO) -> ResumeParsedResult {
        ResumeParsedResult(
            resumeID: dto.resumeID,
            jobID: dto.jobID,
            schemaVersion: dto.schemaVersion,
            status: dto.status,
            structuredResult: dto.structuredResult,
            warnings: dto.warnings
        )
    }

    nonisolated static func map(_ dto: ResumeReviewSessionDTO) -> ResumeReviewSession {
        ResumeReviewSession(
            id: dto.id,
            resumeID: dto.resumeID,
            parsedResultID: dto.parsedResultID,
            status: ResumeReviewStatus(apiValue: dto.status),
            schemaVersion: dto.schemaVersion,
            version: dto.version,
            items: dto.items.map(map),
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    nonisolated static func map(_ dto: ResumeReviewItemDTO) -> ResumeReviewItem {
        ResumeReviewItem(
            id: dto.id,
            claimType: dto.claimType,
            sourceClaimID: dto.sourceClaimID,
            originalPayload: dto.originalPayload,
            editedPayload: dto.editedPayload,
            selected: dto.selected,
            reviewStatus: dto.reviewStatus,
            duplicateStatus: ResumeDuplicateStatus(apiValue: dto.duplicateStatus),
            duplicateCandidates: dto.duplicateCandidates,
            conflictWarnings: dto.conflictWarnings,
            importAction: ResumeImportAction(apiValue: dto.importAction),
            targetRecordID: dto.targetRecordID,
            importedRecordType: dto.importedRecordType,
            importedRecordID: dto.importedRecordID,
            sourceReference: dto.sourceReference,
            confidence: dto.confidence,
            version: dto.version
        )
    }

    nonisolated static func map(_ dto: ResumeReviewPlanDTO) -> ResumeReviewPlan {
        ResumeReviewPlan(
            sessionID: dto.sessionID,
            ready: dto.ready,
            version: dto.version,
            items: dto.items.map {
                ResumeReviewPlanItem(
                    itemID: $0.itemID,
                    claimType: $0.claimType,
                    action: $0.action,
                    targetModel: $0.targetModel,
                    duplicateStatus: ResumeDuplicateStatus(apiValue: $0.duplicateStatus),
                    targetRecordID: $0.targetRecordID,
                    fieldsToCreate: $0.fieldsToCreate,
                    fieldsIgnored: $0.fieldsIgnored,
                    blockers: $0.blockers,
                    warnings: $0.warnings,
                    verifiedRecordProtected: $0.verifiedRecordProtected
                )
            }
        )
    }

    nonisolated static func map(_ dto: ResumeImportBatchDTO) -> ResumeImportBatch {
        ResumeImportBatch(
            id: dto.id,
            reviewSessionID: dto.reviewSessionID,
            status: dto.status,
            totalCount: dto.totalCount,
            importedCount: dto.importedCount,
            linkedCount: dto.linkedCount,
            skippedCount: dto.skippedCount,
            failedCount: dto.failedCount,
            blockedCount: dto.blockedCount,
            incompleteCount: dto.incompleteCount,
            entityCounts: dto.entityCounts.mapValues {
                ResumeImportEntitySummary(
                    detected: $0.detected,
                    imported: $0.imported,
                    incomplete: $0.incomplete,
                    failed: $0.failed
                )
            },
            results: dto.results.map {
                ResumeImportResultItem(
                    reviewItemID: $0.reviewItemID,
                    outcome: $0.outcome,
                    recordType: $0.recordType,
                    recordID: $0.recordID,
                    sanitizedErrorCode: $0.sanitizedErrorCode,
                    warnings: $0.warnings
                )
            },
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    nonisolated static func visibleItems(
        from session: ResumeReviewSession
    ) -> [ResumeReviewItem] {
        session.items.filter { !hiddenMVPClaimTypes.contains($0.claimType) }
    }

    nonisolated static func groupedItems(
        from session: ResumeReviewSession
    ) -> [ResumeReviewSection] {
        let grouped = Dictionary(grouping: visibleItems(from: session), by: \.claimType)
        let orderedKeys = ["profile", "employment", "education", "certification", "portfolio", "project", "skill"]

        return orderedKeys.compactMap { key in
            guard let items = grouped[key], !items.isEmpty else {
                return nil
            }

            return ResumeReviewSection(
                id: key,
                title: groupLabel(for: key),
                items: items
            )
        }
    }

    nonisolated static func groupLabel(for claimType: String) -> String {
        switch claimType {
        case "profile":
            "Basic details"
        case "employment":
            "Employment"
        case "education":
            "Education"
        case "certification":
            "Certifications"
        case "portfolio":
            "Portfolio"
        case "project":
            "Projects"
        case "skill":
            "Skills"
        default:
            claimType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    nonisolated static func displayTitle(for item: ResumeReviewItem) -> String {
        let payload = item.editedPayload

        return firstString(
            payload["company_name"],
            payload["employer_legal_name"],
            payload["institution_name"],
            payload["title"],
            payload["project_title"],
            payload["name"],
            payload["skill_name"],
            payload["full_name"],
            payload["email"]
        ) ?? "Untitled claim"
    }

    nonisolated static func displaySubtitle(for item: ResumeReviewItem) -> String? {
        let payload = item.editedPayload
        return firstString(
            payload["professional_headline"],
            payload["role_title"],
            payload["job_title"],
            payload["degree"],
            payload["field_of_study"],
            payload["headline"],
            payload["issuing_organization"],
            payload["role"],
            payload["source_reference"]
        )
    }

    nonisolated static func detailLines(for item: ResumeReviewItem) -> [String] {
        let payload = item.editedPayload
        var lines: [String] = []

        if let dateLine = dateRange(for: item) {
            lines.append(dateLine)
        }

        switch item.claimType {
        case "profile":
            if let email = stringValue(payload["email"]) {
                lines.append(email)
            }
            if let location = combinedLocation(payload) {
                lines.append(location)
            }
        case "education":
            if let degree = stringValue(payload["degree"]) {
                lines.append(degree)
            }
            if let field = stringValue(payload["field_of_study"]), field != lines.last {
                lines.append(field)
            }
        case "certification":
            if let issuer = stringValue(payload["issuing_organization"]) {
                lines.append(issuer)
            }
        case "project", "portfolio":
            if let link = stringValue(payload["portfolio_url"]) ?? stringValue(payload["url"]) {
                lines.append(link)
            }
        case "skill":
            if let category = stringValue(payload["category"]) {
                lines.append(category)
            }
        default:
            break
        }

        if !item.conflictWarnings.isEmpty {
            lines.append(item.conflictWarnings.joined(separator: " "))
        }

        return lines
    }

    nonisolated static func editableFields(for item: ResumeReviewItem) -> [ResumeReviewEditableField] {
        switch item.claimType {
        case "profile":
            return [
                .init(key: "full_name", label: "Full name", keyboard: .default),
                .init(key: "professional_headline", label: "Headline", keyboard: .default)
            ]
        case "employment":
            return [
                .init(key: "company_name", label: "Company", keyboard: .default, fallbacks: ["employer_legal_name"]),
                .init(key: "role_title", label: "Role", keyboard: .default, fallbacks: ["job_title"]),
                .init(key: "start_date", label: "Start date", keyboard: .default, fallbacks: ["start_date_display"]),
                .init(key: "end_date", label: "End date", keyboard: .default, fallbacks: ["end_date_display"])
            ]
        case "education":
            return [
                .init(key: "institution_name", label: "Institution", keyboard: .default),
                .init(key: "degree", label: "Degree", keyboard: .default),
                .init(key: "field_of_study", label: "Field of study", keyboard: .default),
                .init(key: "start_date", label: "Start date", keyboard: .default, fallbacks: ["start_date_display"]),
                .init(key: "end_date", label: "End date", keyboard: .default, fallbacks: ["end_date_display"])
            ]
        case "certification":
            return [
                .init(key: "title", label: "Certification", keyboard: .default, fallbacks: ["name"]),
                .init(key: "issuing_organization", label: "Issuer", keyboard: .default),
                .init(key: "issued_date", label: "Issue date", keyboard: .default)
            ]
        case "project":
            return [
                .init(key: "title", label: "Project", keyboard: .default, fallbacks: ["project_title"]),
                .init(key: "description", label: "Description", keyboard: .default),
                .init(key: "url", label: "Project link", keyboard: .URL, fallbacks: ["portfolio_url"])
            ]
        case "portfolio":
            return [
                .init(key: "title", label: "Portfolio item", keyboard: .default),
                .init(key: "description", label: "Description", keyboard: .default),
                .init(key: "url", label: "Portfolio link", keyboard: .URL)
            ]
        case "skill":
            return [
                .init(key: "name", label: "Skill", keyboard: .default, fallbacks: ["skill_name"])
            ]
        default:
            return []
        }
    }

    nonisolated static func editedPayload(
        for item: ResumeReviewItem,
        using values: [String: String]
    ) -> [String: JSONValue] {
        var payload = item.editedPayload

        for field in editableFields(for: item) {
            guard let value = values[field.key] else {
                continue
            }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            // Preserve the exact date/precision pair on an unrelated edit. API42
            // can retain a year/month display with a deliberately null date.
            let original = ([field.key] + field.fallbacks).compactMap { key -> String? in
                guard case .string(let string)? = item.editedPayload[key] else { return nil }
                return string
            }.first ?? ""
            if trimmed == original.trimmingCharacters(in: .whitespacesAndNewlines) { continue }
            payload[field.key] = trimmed.isEmpty ? .null : .string(trimmed)
            if ["employment", "education"].contains(item.claimType),
               ["start_date", "end_date"].contains(field.key) {
                // Otherwise API42's normalization resurrects a cleared date
                // from the stale display alias.
                payload[field.key + "_display"] = .null
                payload[field.key + "_precision"] = .null
            }
        }

        if item.claimType == "education" {
            let explicitChoice = values["institution_catalogue_id"] != nil || values["institution_catalogue_version"] != nil
            let nameChanged = payload["institution_name"] != item.editedPayload["institution_name"]
            if explicitChoice || nameChanged {
                for key in ["institution_catalogue_id", "institution_catalogue_version"] {
                    let value = explicitChoice ? values[key]?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                    payload[key] = value.flatMap { $0.isEmpty ? nil : JSONValue.string($0) } ?? .null
                }
            }
        }
        return payload
    }

    nonisolated static func failedItemGuidance(batch: ResumeImportBatch, review: ResumeReviewSession?) -> String {
        guard let review else { return "Refresh the review to identify the affected items. Already imported records are preserved." }
        let failedIDs = Set(batch.results.filter { ["failed", "blocked", "incomplete"].contains($0.outcome) }.map(\.reviewItemID))
        let descriptions = review.items.filter { failedIDs.contains($0.id) }.map { item in
            let peers = review.items.filter { $0.claimType == item.claimType }
            let ordinal = (peers.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
            return "\(groupLabel(for: item.claimType)) item \(ordinal)"
        }
        guard !descriptions.isEmpty else { return "Refresh the review to identify the affected items. Already imported records are preserved." }
        return "Review or exclude: " + descriptions.joined(separator: ", ") + ". Already imported records are preserved."
    }

    nonisolated static func selectionUpdateRequest(
        for item: ResumeReviewItem,
        selected: Bool
    ) -> ResumeReviewItemUpdateRequestDTO {
        ResumeReviewItemUpdateRequestDTO(
            expectedVersion: item.version,
            selected: selected,
            importAction: nil,
            targetRecordID: nil,
            editedPayload: nil
        )
    }

    nonisolated static func editedPayloadUpdateRequest(
        for item: ResumeReviewItem,
        editedPayload: [String: JSONValue]
    ) -> ResumeReviewItemUpdateRequestDTO {
        ResumeReviewItemUpdateRequestDTO(
            expectedVersion: item.version,
            selected: nil,
            importAction: nil,
            targetRecordID: nil,
            editedPayload: editedPayload
        )
    }

    nonisolated static func employmentDuplicateReviewState(
        for item: ResumeReviewItem
    ) -> ResumeEmploymentDuplicateReviewState {
        guard item.claimType == "employment" else {
            return .noConflict
        }

        let existing = item.duplicateCandidates.first.map(employmentSummary(from:))

        switch item.duplicateStatus {
        case .exactMatch:
            return .alreadyInCareer(existing: existing)
        case .possibleMatch, .probableMatch, .conflict:
            let decision: ResumeEmploymentDuplicateDecision =
                item.selected && item.importAction == .createNew
                    ? .addAsNewRole
                    : .keepExisting
            return .possibleMatch(
                existing: existing,
                imported: employmentSummary(from: item.editedPayload),
                decision: decision
            )
        case .noMatch, .unknown:
            return .noConflict
        }
    }

    nonisolated static func employmentDecisionUpdateRequest(
        for item: ResumeReviewItem,
        decision: ResumeEmploymentDuplicateDecision,
        distinctRoleConfirmed: Bool
    ) -> ResumeReviewItemUpdateRequestDTO? {
        guard item.claimType == "employment" else {
            return nil
        }

        switch employmentDuplicateReviewState(for: item) {
        case .noConflict, .alreadyInCareer:
            return nil
        case .possibleMatch:
            switch decision {
            case .keepExisting:
                return ResumeReviewItemUpdateRequestDTO(
                    expectedVersion: item.version,
                    selected: true,
                    importAction: ResumeImportAction.skip.rawValue,
                    targetRecordID: nil,
                    editedPayload: nil
                )
            case .addAsNewRole:
                guard distinctRoleConfirmed else {
                    return nil
                }
                return ResumeReviewItemUpdateRequestDTO(
                    expectedVersion: item.version,
                    selected: true,
                    importAction: ResumeImportAction.createNew.rawValue,
                    targetRecordID: nil,
                    editedPayload: nil,
                    confirmDistinctRole: true
                )
            }
        }
    }

    nonisolated static func reviewedOutcome(for item: ResumeReviewItem) -> ResumeReviewedOutcome {
        if item.claimType == "employment" {
            switch employmentDuplicateReviewState(for: item) {
            case .alreadyInCareer:
                return .alreadyInCareer
            case .possibleMatch(_, _, let decision):
                return decision == .addAsNewRole ? .addAsNewRole : .keepExisting
            case .noConflict:
                break
            }
        }

        if !item.selected || item.importAction == .skip {
            return .skip
        }
        if item.importAction == .linkExisting {
            return .alreadyInCareer
        }
        return .import
    }

    nonisolated static func employmentSummary(
        from payload: [String: JSONValue]
    ) -> ResumeEmploymentSummary {
        let employer = firstString(
            payload["employer"],
            payload["company_name"],
            payload["employer_legal_name"],
            payload["employer_trade_name"]
        )
        let role = firstString(
            payload["title"],
            payload["role_title"],
            payload["job_title"],
            payload["role"]
        )
        let start = firstString(payload["start_date_display"], payload["start_date"])
        let end = firstString(payload["end_date_display"], payload["end_date"])
        let dates: String? = switch (start, end) {
        case let (.some(start), .some(end)):
            "\(start) – \(end)"
        case let (.some(start), .none):
            "\(start) – Present"
        case let (.none, .some(end)):
            "Until \(end)"
        case (.none, .none):
            nil
        }
        let location = firstString(
            payload["location"],
            payload["work_location"],
            payload["work_location_city"],
            payload["city"]
        )

        return ResumeEmploymentSummary(
            employer: employer,
            role: role,
            dates: dates,
            location: location
        )
    }

    nonisolated static func reconciledUpdateRequest(
        for latestItem: ResumeReviewItem,
        desiredSelected: Bool? = nil,
        desiredEditedPayload: [String: JSONValue]? = nil
    ) -> ResumeReviewItemUpdateRequestDTO? {
        if let desiredSelected {
            guard latestItem.selected != desiredSelected else {
                return nil
            }

            return selectionUpdateRequest(
                for: latestItem,
                selected: desiredSelected
            )
        }

        if let desiredEditedPayload {
            guard latestItem.editedPayload != desiredEditedPayload else {
                return nil
            }

            return editedPayloadUpdateRequest(
                for: latestItem,
                editedPayload: desiredEditedPayload
            )
        }

        return nil
    }

    private nonisolated static func firstString(_ values: JSONValue?...) -> String? {
        values.compactMap(stringValue).first { !$0.isEmpty }
    }

    private nonisolated static func stringValue(_ value: JSONValue?) -> String? {
        guard let value else {
            return nil
        }

        switch value {
        case .string(let string):
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case .number(let number):
            return String(number)
        case .bool(let bool):
            return bool ? "True" : "False"
        case .null, .object, .array:
            return nil
        }
    }

    private nonisolated static func combinedLocation(_ payload: [String: JSONValue]) -> String? {
        if let locationObject = objectValue(payload["location"]),
           let display = stringValue(locationObject["display"]) {
            return display
        }

        if let location = stringValue(payload["location"]) {
            return location
        }

        let parts = [
            stringValue(payload["current_city"]),
            stringValue(payload["current_country"])
        ].compactMap { $0 }.filter { !$0.isEmpty }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private nonisolated static func dateRange(for item: ResumeReviewItem) -> String? {
        let payload = item.editedPayload
        let start = stringValue(payload["start_date"]) ?? stringValue(payload["start_date_display"])
        let end = stringValue(payload["end_date"]) ?? stringValue(payload["end_date_display"])

        guard start != nil || end != nil else {
            return nil
        }

        return "\(start ?? "Unknown start") – \(end ?? "Present")"
    }

    private nonisolated static func objectValue(_ value: JSONValue?) -> [String: JSONValue]? {
        guard let value else {
            return nil
        }

        if case .object(let object) = value {
            return object
        }

        return nil
    }
}

nonisolated struct ResumeReviewSection: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let items: [ResumeReviewItem]
}

nonisolated struct ResumeReviewEditableField: Equatable, Sendable, Identifiable {
    let key: String
    let label: String
    let keyboard: UIKeyboardType
    let fallbacks: [String]

    init(
        key: String,
        label: String,
        keyboard: UIKeyboardType,
        fallbacks: [String] = []
    ) {
        self.key = key
        self.label = label
        self.keyboard = keyboard
        self.fallbacks = fallbacks
    }

    var id: String { key }
}
