import Foundation

/// Presentation only: server versions/payloads remain authoritative for every PATCH.
/// Keep the entire intent visible until the batch's final refetch, not each response.
nonisolated struct ResumeBulkSelectionPresentation {
    let reviewID: String
    let sectionID: String
    let itemIDs: [String]
    let selected: Bool

    init?(reviewID: String, section: ResumeReviewSection) {
        guard let selected = ResumeImportMapper.bulkSelectionTarget(in: section) else { return nil }
        let changes = ResumeImportMapper.bulkSelectionChanges(in: section, selected: selected)
        guard !changes.isEmpty else { return nil }
        self.reviewID = reviewID
        self.sectionID = section.id
        self.itemIDs = changes.map(\.id)
        self.selected = selected
    }

    func applying(to review: ResumeReviewSession) -> ResumeReviewSession {
        guard review.id == reviewID else { return review }
        let ids = Set(itemIDs)
        return ResumeReviewSession(
            id: review.id, resumeID: review.resumeID, parsedResultID: review.parsedResultID,
            status: review.status, schemaVersion: review.schemaVersion, version: review.version,
            items: review.items.map { item in
                guard ids.contains(item.id), ResumeImportMapper.isSelectionEditable(for: item) else { return item }
                return ResumeReviewItem(
                    id: item.id, claimType: item.claimType, sourceClaimID: item.sourceClaimID,
                    originalPayload: item.originalPayload, editedPayload: item.editedPayload,
                    selected: selected, reviewStatus: item.reviewStatus, duplicateStatus: item.duplicateStatus,
                    duplicateCandidates: item.duplicateCandidates, conflictWarnings: item.conflictWarnings,
                    importAction: item.importAction, targetRecordID: item.targetRecordID,
                    importedRecordType: item.importedRecordType, importedRecordID: item.importedRecordID,
                    sourceReference: item.sourceReference, confidence: item.confidence, version: item.version
                )
            }, createdAt: review.createdAt, updatedAt: review.updatedAt
        )
    }
}
