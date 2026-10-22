import SwiftUI

/// Reuses the development-only, network-blocked Batch 1 gate. No live services or writes.
struct LocalBatch2FormQA: View {
    @State private var result = "Synthetic forms — no writes"
    private let editor = ProcessInfo.processInfo.environment["KAIRO_BATCH2_EDITOR"] ?? "employment"
    var body: some View {
#if KAIRO_LOCAL_BATCH1_QA
        if let run = ProcessInfo.processInfo.environment["KAIRO_POSTBUILD8_PERSISTENCE_RUN"],
           UUID(uuidString: run) != nil {
            PostBuild8PersistenceQA(run: run, editor: editor)
        } else {
            forms
        }
#else
        forms
#endif
    }
    private var forms: some View {
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

#if KAIRO_LOCAL_BATCH1_QA
/// Disposable local canonical store, not evidence of live database persistence.
/// Only reachable through the existing signed, network-blocked local QA gate.
private struct PostBuild8PersistenceQA: View {
    let run: String
    let editor: String
    @State private var revision = 0
    @State private var result = "Synthetic persistence — network blocked"
    @State private var value: String?
    @State private var loaded = false

    private var key: String {
        switch editor {
        case "education": "field_of_study"
        case "certification": "credential_id"
        case "project": "role"
        default: "employer_trade_name"
        }
    }
    private var file: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PostBuild8SyntheticPersistence", isDirectory: true)
            .appendingPathComponent(run, isDirectory: true)
            .appendingPathComponent("\(key).json")
    }
    var body: some View {
        VStack {
            Text(result).font(.caption).accessibilityIdentifier("postbuild8.persistence.result")
            if loaded { editorView.id(revision) }
        }
        .task {
            do {
                if !FileManager.default.fileExists(atPath: file.path) {
                    try write([key: "Synthetic retained value"])
                }
                try refetch()
                loaded = true
            } catch { result = "Synthetic store failure" }
        }
    }
    @ViewBuilder private var editorView: some View {
        switch editor {
        case "education":
            CareerEducationEditorSheet(mode: .edit, draft: .init(record: .init(
                id: "synthetic", institution: "Synthetic institution", degree: "Bachelor of Science (BSc)",
                fieldOfStudy: value, educationLevel: "bachelors", grade: nil,
                startDate: nil, startDatePrecision: nil, endDate: nil, endDatePrecision: nil,
                isCurrentlyStudying: false, verificationStatus: .notVerified, rawVerificationStatus: "draft"))) {
                    try save($0.updateRequest())
                }
        case "certification":
            CareerCertificationEditorSheet(mode: .edit, draft: .init(record: .init(
                id: "synthetic", title: "Synthetic certification", issuer: "Synthetic issuer",
                issueDate: nil, expiryDate: nil, doesNotExpire: true, credentialID: value,
                credentialURL: nil, originalFilename: nil, contentType: nil, byteSize: nil,
                verificationStatus: .notVerified, rawVerificationStatus: "draft"))) { draft, _ in
                    try save(draft.updateRequest())
                }
        case "project":
            CareerProjectEditorSheet(mode: .edit, draft: .init(record: .init(
                id: "synthetic", title: "Synthetic project", role: value ?? "", description: nil,
                startDate: nil, endDate: nil, isOngoing: false, projectURL: nil, repositoryURL: nil,
                organizationName: nil, verificationStatus: .notVerified, rawVerificationStatus: "draft"))) {
                    try save($0.updateRequest())
                }
        default:
            CareerEmploymentEditorSheet(mode: .edit, draft: .init(record: .init(
                id: "synthetic", subjectFullName: nil, subjectEmail: nil, company: "Synthetic employer",
                employerLegalName: "Synthetic employer", employerTradeName: value, role: "Engineer",
                employmentType: "full_time", startDate: nil, endDate: nil, currentlyWorking: true,
                workLocationCountry: nil, workLocationRegion: nil, workArrangement: "remote",
                verificationMethod: "document", verificationStatus: .notVerified, rawVerificationStatus: "draft"))) {
                    try save($0.updateRequest())
                }
        }
    }
    private func save<T: Encodable>(_ request: T) throws {
        let patch = try JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(request)) as! [String: Any]
        var canonical = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        // Mirrors exclude-unset semantics: absence preserves, explicit null clears.
        if let change = patch[key] { canonical[key] = change }
        try write(canonical)
        try refetch()
        result = "Wire: \(patch[key] is NSNull ? "null" : patch[key] == nil ? "omitted" : "value"); refetch: \(value == nil ? "cleared" : "set")"
        revision += 1
    }
    private func write(_ object: [String: Any]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: object, options: .sortedKeys).write(to: file, options: .atomic)
    }
    private func refetch() throws {
        let canonical = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
        value = canonical[key] as? String
        result = "Refetched: \(value == nil ? "cleared" : "set")"
    }
}
#endif
