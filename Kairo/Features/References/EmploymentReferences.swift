import Foundation
import SwiftUI

// Deliberately no private contacts, comments, answers, ratings or invitation URLs.
nonisolated struct CandidateReferences: Codable, Equatable, Sendable {
    let employmentId: String
    let completedCount: Int
    let totalCount: Int
    let hrReference: ReferenceSummary
    let reportingManager: ManagerReferenceSummary

    func validated(for id: String) throws -> Self {
        guard employmentId == id, totalCount == 2, (0...2).contains(completedCount) else {
            throw NetworkError.invalidResponse
        }
        return self
    }
}
nonisolated struct ReferenceSummary: Codable, Equatable, Sendable { let status: String }
nonisolated struct ManagerReferenceSummary: Codable, Equatable, Sendable {
    let status: String
    var nominationId: String?
    var fullName: String?
    var designation: String?
    var relationship: String?
    var relationshipConfirmedByHr: Bool?
    var nominationLocked: Bool?
    var validatedAt: String?
    var invitationBlockedReason: String?
    var identityWithheld: Bool?

    var requiresChange: Bool {
        nominationLocked == true || relationshipConfirmedByHr == true || validatedAt != nil
        || !["not_started", "awaiting_hr_validation", "pending"].contains(status)
    }
    var visibleName: String? { identityWithheld == true ? nil : fullName }
    var visibleDesignation: String? { identityWithheld == true ? nil : designation }
}
nonisolated enum ReferenceCopy {
    static func status(_ value: String) -> String {
        ["not_started": "Not started", "pending": "Pending", "awaiting_hr_validation": "Awaiting HR confirmation",
         "ready_to_invite": "Ready for invitation", "invitation_sent": "Invitation sent", "opened": "Awaiting response",
         "completed": "Completed", "declined": "Declined", "expired": "Invitation expired",
         "needs_review": "Needs review", "cannot_confirm": "Unable to confirm"][value] ?? "Status unavailable"
    }
    static func error(_ error: Error) -> String {
        if case .api(let api) = error as? NetworkError {
            if api.statusCode == 409 { return "The manager details have changed or been reviewed by HR. Refresh references, then use Request manager change if needed." }
            if api.statusCode == 429 { return "Too many attempts. Please wait before trying again." }
            if api.statusCode == 401 { return "Your session has expired. Please sign in again." }
            if [403, 404].contains(api.statusCode) { return "References are not available for this employment." }
            if api.statusCode == 422 { return "Check the manager's name, designation and contact details." }
        }
        return "We couldn't update references. Refresh to check the latest status before trying again."
    }
}
nonisolated struct ManagerNominationInput: Encodable, Equatable, Sendable {
    var fullName = ""
    var designation = ""
    var workEmail: String? = nil
    var phone: String? = nil
    var normalized: Self {
        .init(fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
              designation: designation.trimmingCharacters(in: .whitespacesAndNewlines),
              workEmail: workEmail?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
              phone: phone?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
    }
    var isValid: Bool {
        let value = normalized
        return (1...255).contains(value.fullName.count) && (1...255).contains(value.designation.count)
        && (value.workEmail != nil || value.phone != nil)
        && (value.workEmail == nil || value.workEmail!.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil)
        && (value.phone == nil || value.phone!.range(of: #"^\+[1-9][0-9]{7,14}$"#, options: .regularExpression) != nil)
    }
}
private extension String { nonisolated var nilIfEmpty: String? { isEmpty ? nil : self } }

protocol EmploymentReferencesServing: Sendable {
    var enabled: Bool { get }
    func load(employmentID: String) async throws -> CandidateReferences
    func save(employmentID: String, input: ManagerNominationInput, change: Bool) async throws -> CandidateReferences
}
actor EmploymentReferencesService: EmploymentReferencesServing {
    nonisolated let enabled: Bool
    private let session: any SessionServiceProtocol
    init(session: any SessionServiceProtocol, enabled: Bool = true) { self.session = session; self.enabled = enabled }
    private func path(_ id: String) throws -> String {
        guard enabled, UUID(uuidString: id) != nil else { throw NetworkError.invalidURL }
        return "/employments/\(id)/references"
    }
    func load(employmentID: String) async throws -> CandidateReferences {
        let data = try await session.sendAuthenticated(.init(path: path(employmentID),
            headers: ["Cache-Control": "no-store"], requiresPrivateJSONTransport: true))
        return try APIJSONCoder.makeDecoder().decode(CandidateReferences.self, from: data).validated(for: employmentID)
    }
    func save(employmentID: String, input: ManagerNominationInput, change: Bool) async throws -> CandidateReferences {
        guard input.isValid else { throw NetworkError.invalidResponse }
        let data = try await session.sendAuthenticated(.init(path: path(employmentID) + "/reporting-manager" + (change ? "/change" : ""),
            method: change ? .post : .put, headers: ["Content-Type": "application/json", "Cache-Control": "no-store"],
            body: APIJSONCoder.makeEncoder().encode(input.normalized), allowsSessionRefreshOnUnauthorized: false,
            requiresPrivateJSONTransport: true))
        return try APIJSONCoder.makeDecoder().decode(CandidateReferences.self, from: data).validated(for: employmentID)
    }
}
struct UnavailableReferencesService: EmploymentReferencesServing {
    let enabled = false
    func load(employmentID: String) async throws -> CandidateReferences { throw NetworkError.unavailableInDemoMode }
    func save(employmentID: String, input: ManagerNominationInput, change: Bool) async throws -> CandidateReferences { throw NetworkError.unavailableInDemoMode }
}
private struct ReferencesServiceKey: EnvironmentKey { static let defaultValue: any EmploymentReferencesServing = UnavailableReferencesService() }
extension EnvironmentValues {
    var employmentReferencesService: any EmploymentReferencesServing {
        get { self[ReferencesServiceKey.self] }
        set { self[ReferencesServiceKey.self] = newValue }
    }
}
