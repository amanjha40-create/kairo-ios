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
                .init(key: "email", label: "Email", keyboard: .emailAddress),
                .init(key: "headline", label: "Headline", keyboard: .default),
                .init(key: "location", label: "Location", keyboard: .default)
            ]
        case "employment":
            return [
                .init(key: "company_name", label: "Company", keyboard: .default, fallbacks: ["employer_legal_name"]),
                .init(key: "role_title", label: "Role", keyboard: .default, fallbacks: ["job_title"]),
                .init(key: "start_date", label: "Start date", keyboard: .default),
                .init(key: "end_date", label: "End date", keyboard: .default)
            ]
        case "education":
            return [
                .init(key: "institution_name", label: "Institution", keyboard: .default),
                .init(key: "degree", label: "Degree", keyboard: .default),
                .init(key: "field_of_study", label: "Field of study", keyboard: .default),
                .init(key: "start_date", label: "Start date", keyboard: .default),
                .init(key: "end_date", label: "End date", keyboard: .default)
            ]
        case "certification":
            return [
                .init(key: "title", label: "Certification", keyboard: .default, fallbacks: ["name"]),
                .init(key: "issuing_organization", label: "Issuer", keyboard: .default),
                .init(key: "issue_date", label: "Issue date", keyboard: .default)
            ]
        case "project", "portfolio":
            return [
                .init(key: "project_title", label: "Project", keyboard: .default, fallbacks: ["title"]),
                .init(key: "role", label: "Role", keyboard: .default),
                .init(key: "portfolio_url", label: "Portfolio link", keyboard: .URL, fallbacks: ["url"])
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
            payload[field.key] = trimmed.isEmpty ? .null : .string(trimmed)
        }

        return payload
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
