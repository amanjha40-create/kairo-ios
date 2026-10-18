import SwiftUI

nonisolated struct TrustInvitationPresentation: Identifiable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id = UUID()
    let token: String
    var description: String { "TrustInvitationPresentation(<redacted>)" }
    var debugDescription: String { description }

    static func parse(_ url: URL, allowedHosts: Set<String>) -> Self? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", let host = parts.host, allowedHosts.contains(host.lowercased()),
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil else { return nil }
        let segments = parts.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count == 3, segments[0].isEmpty, segments[1] == "trust-invitations" else { return nil }
        let token = String(segments[2])
        guard validToken(token) else { return nil }
        return Self(token: token)
    }

    static func validToken(_ token: String) -> Bool {
        (20...512).contains(token.utf8.count) && token.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }
}

nonisolated struct PublicTrustInvitation: Decodable, Equatable, Sendable {
    let publicId: String
    let organizationName: String
    let subjectName: String
    let purpose: String?
    let requestedVerificationTypes: [String]
    let expiresAt: Date
    let status: String
    func canAccept(at now: Date) -> Bool { status == "pending" && expiresAt > now }
}

nonisolated struct TrustInvitationAcceptance: Decodable, Sendable {
    let publicId: String
    let organizationPublicId: String
    let status: String
    let acceptedAt: Date
}

nonisolated protocol TrustInvitationServing: Sendable {
    func read(token: String) async throws -> PublicTrustInvitation
    func accept(token: String) async throws -> TrustInvitationAcceptance
}

nonisolated struct TrustInvitationService: TrustInvitationServing {
    let publicClient: any NetworkClient
    let session: any SessionServiceProtocol
    func read(token: String) async throws -> PublicTrustInvitation {
        guard TrustInvitationPresentation.validToken(token) else { throw NetworkError.invalidURL }
        let data = try await publicClient.send(NetworkRequest(path: "/trust-invitations/\(token)", requiresPrivateJSONTransport: true))
        return try APIJSONCoder.makeDecoder().decode(PublicTrustInvitation.self, from: data)
    }
    func accept(token: String) async throws -> TrustInvitationAcceptance {
        guard TrustInvitationPresentation.validToken(token) else { throw NetworkError.invalidURL }
        let data = try await session.sendAuthenticated(NetworkRequest(path: "/trust-invitations/\(token)/accept", method: .post, requiresPrivateJSONTransport: true))
        let result = try APIJSONCoder.makeDecoder().decode(TrustInvitationAcceptance.self, from: data)
        guard result.status == "accepted" else { throw NetworkError.invalidResponse }
        return result
    }
}

private struct TrustInvitationServiceKey: EnvironmentKey {
    static let defaultValue: (any TrustInvitationServing)? = nil
}
extension EnvironmentValues {
    var trustInvitationService: (any TrustInvitationServing)? {
        get { self[TrustInvitationServiceKey.self] }
        set { self[TrustInvitationServiceKey.self] = newValue }
    }
}

/// UI-test dependency only; no network, credentials, account or organization writes.
nonisolated struct SyntheticTrustInvitationService: TrustInvitationServing {
    func read(token: String) async throws -> PublicTrustInvitation {
        PublicTrustInvitation(publicId: "synthetic-invitation", organizationName: "Synthetic organization",
                              subjectName: "Synthetic candidate", purpose: "Disposable product QA",
                              requestedVerificationTypes: ["employment"], expiresAt: Date().addingTimeInterval(86400), status: "pending")
    }
    func accept(token: String) async throws -> TrustInvitationAcceptance {
        TrustInvitationAcceptance(publicId: "synthetic-invitation", organizationPublicId: "synthetic-organization", status: "accepted", acceptedAt: Date())
    }
}

struct TrustInvitationView: View {
    let presentation: TrustInvitationPresentation
    @Environment(\.trustInvitationService) private var service
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @State private var invitation: PublicTrustInvitation?
    @State private var isWorking = false
    @State private var failure = false
    @State private var accepted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    ProductGuidanceView(topic: .invitation)
                    if let invitation {
                        Text(invitation.organizationName).font(KairoTypography.title)
                        Text("Invitation for \(invitation.subjectName)").font(KairoTypography.body)
                        if let purpose = invitation.purpose { Text(purpose).font(KairoTypography.body) }
                        Text(accepted ? "Accepted" : invitation.status.capitalized).font(KairoTypography.headline)
                        Text("Requested checks: \(invitation.requestedVerificationTypes.map { $0.replacingOccurrences(of: "_", with: " ") }.joined(separator: ", "))")
                            .font(KairoTypography.footnote)
                        if accepted {
                            Text("Organization linked. No verification request was created by accepting this invitation.")
                            Button("View Career") { router.selectTab(.career); dismiss() }
                        } else if invitation.canAccept(at: Date()) {
                            if sessionStore.currentUser == nil {
                                Button("Login to review and accept") {
                                    router.pendingTrustInvitation = presentation
                                    dismiss()
                                    router.showLogin()
                                }
                            } else {
                                Button("Accept invitation") { Task { await accept(invitation) } }
                                    .disabled(isWorking)
                                    .accessibilityIdentifier("invitation.accept")
                            }
                        } else {
                            Text("This invitation cannot be accepted. Ask the organization for help if you need a new invitation.")
                        }
                    } else if !failure {
                        ProgressView("Loading invitation")
                    }
                    if failure {
                        KairoErrorStateView(title: "Invitation unavailable", message: "Check your connection and that you are using the intended account. No acceptance has been confirmed.", retryAction: { Task { await load() } })
                    }
                }
                .padding(KairoSpacing.medium)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Review invitation").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .task { await load() }
        .accessibilityIdentifier("candidate.trustInvitation")
    }

    private func load() async {
        guard let service else { failure = true; return }
        failure = false
        do { invitation = try await service.read(token: presentation.token) }
        catch { failure = true }
    }
    private func accept(_ invitation: PublicTrustInvitation) async {
        guard let service, !isWorking, sessionStore.currentUser != nil, invitation.canAccept(at: Date()) else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await service.accept(token: presentation.token)
            guard result.publicId == invitation.publicId else { throw NetworkError.invalidResponse }
            accepted = true; failure = false
        } catch { failure = true }
    }
}
