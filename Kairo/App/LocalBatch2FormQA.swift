import SwiftUI

/// Reuses the development-only, network-blocked Batch 1 gate. No live services or writes.
struct LocalBatch2FormQA: View {
    @State private var result = "Synthetic forms — no writes"
    private let editor = ProcessInfo.processInfo.environment["KAIRO_BATCH2_EDITOR"] ?? "employment"
    var body: some View {
        VStack(spacing: 0) {
            Text(result).font(.caption).accessibilityIdentifier("batch2.result")
            switch editor {
            case "education":
                CareerEducationEditorSheet(mode: .edit, draft: .init(record: .init(
                    id: "synthetic", institution: "Synthetic institution", degree: "Uncommon degree",
                    fieldOfStudy: nil, educationLevel: "bachelors", grade: nil,
                    startDate: CandidateDateInput.date(year: "2020", month: 6, day: 15), startDatePrecision: "year",
                    endDate: CandidateDateInput.date(year: "2024"), endDatePrecision: "year", isCurrentlyStudying: false,
                    verificationStatus: .notVerified, rawVerificationStatus: "draft"))) { draft in
                        result = "Saved locally: \(draft.updateRequest().startDate ?? "null") / \(draft.updateRequest().startDatePrecision ?? "null")"
                    }
            case "certification":
                CareerCertificationEditorSheet(mode: .create, draft: certification()) { draft, _ in
                    result = "Saved locally: \(draft.createRequest().issuedDate)"
                }
            default:
                CareerEmploymentEditorSheet(mode: .edit, draft: .init(record: .init(
                    id: "synthetic", subjectFullName: nil, subjectEmail: nil, company: "Synthetic employer",
                    employerLegalName: "Synthetic employer", employerTradeName: nil, role: "Engineer",
                    employmentType: "legacy apprenticeship", startDate: nil,
                    endDate: CandidateDateInput.date(year: "2024"), currentlyWorking: false,
                    workLocationCountry: nil, workLocationRegion: nil, workArrangement: "onsite",
                    verificationMethod: "document", verificationStatus: .notVerified, rawVerificationStatus: "draft"))) { draft in
                        result = "Saved locally: \(draft.updateRequest().employmentType ?? "unchanged") / \(draft.updateRequest().startDate ?? "null")"
                    }
            }
        }
    }
    private func certification() -> CareerCertificationDraft {
        var draft = CareerCertificationDraft()
        draft.title = "Synthetic certification"; draft.issuingOrganization = "Synthetic issuer"
        return draft
    }
}
