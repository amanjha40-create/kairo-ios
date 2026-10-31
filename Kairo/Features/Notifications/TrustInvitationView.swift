import SwiftUI

nonisolated struct TrustInvitationPresentation: Identifiable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let id = UUID()
    let token: String
    let invitationID: String?
    var description: String { "TrustInvitationPresentation(<redacted>)" }
    var debugDescription: String { description }

    init(token: String) {
        self.token = token
        invitationID = nil
    }

    init(invitationID: String) {
        token = ""
        self.invitationID = invitationID
    }

    static func parse(_ url: URL, allowedHosts: Set<String>) -> Self? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", let host = parts.host, allowedHosts.contains(host.lowercased()),
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil else { return nil }
        let segments = parts.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count == 3, segments[0].isEmpty,
              segments[1] == "invite" || segments[1] == "trust-invitations" else { return nil }
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

nonisolated struct CandidateTrustInvitationRequirement: Decodable, Equatable, Identifiable, Sendable {
    let requirementType: String
    let mandatory: Bool
    let status: String
    let action: String?
    var id: String { requirementType }
}

nonisolated struct CandidateTrustInvitation: Decodable, Equatable, Identifiable, Sendable {
    struct ShareAction: Decodable, Equatable, Sendable {
        let action: String
        let label: String
    }

    let publicId: String
    let organizationPublicId: String
    let organizationName: String
    let role: String?
    let purpose: String?
    let message: String?
    let lifecycleState: String
    let requirementsVersion: Int
    let requirements: [CandidateTrustInvitationRequirement]
    let completedRequirements: Int
    let requiredRequirements: Int
    let acceptedAt: Date?
    let declinedAt: Date?
    let completedAt: Date?
    let expiresAt: Date
    let shareAction: ShareAction?

    var id: String { publicId }
    var actionable: Bool { ["available", "accepted", "in_progress"].contains(lifecycleState) }
}

nonisolated struct CandidateTrustInvitationHomeSummary: Decodable, Equatable, Sendable {
    let pendingInvitationCount: Int
    let actionRequiredInvitationCount: Int
    let latestActionableInvitation: CandidateTrustInvitation?
}

nonisolated struct FinalizeTrustInvitationRequest: Encodable, Equatable, Sendable {
    let passportShareId: String
    let consentVersion: Int
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
    func listMine() async throws -> [CandidateTrustInvitation]
    func homeSummary() async throws -> CandidateTrustInvitationHomeSummary
    func readMine(id: String) async throws -> CandidateTrustInvitation
    func acceptMine(id: String) async throws -> CandidateTrustInvitation
    func declineMine(id: String) async throws -> CandidateTrustInvitation
    func finalizeMine(id: String, shareID: String, consentVersion: Int) async throws -> CandidateTrustInvitation
}

extension TrustInvitationServing {
    func listMine() async throws -> [CandidateTrustInvitation] { throw NetworkError.invalidResponse }
    func homeSummary() async throws -> CandidateTrustInvitationHomeSummary { throw NetworkError.invalidResponse }
    func readMine(id: String) async throws -> CandidateTrustInvitation { _ = id; throw NetworkError.invalidResponse }
    func acceptMine(id: String) async throws -> CandidateTrustInvitation { _ = id; throw NetworkError.invalidResponse }
    func declineMine(id: String) async throws -> CandidateTrustInvitation { _ = id; throw NetworkError.invalidResponse }
    func finalizeMine(id: String, shareID: String, consentVersion: Int) async throws -> CandidateTrustInvitation {
        _ = (id, shareID, consentVersion)
        throw NetworkError.invalidResponse
    }
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

    func listMine() async throws -> [CandidateTrustInvitation] {
        try await authenticated(path: "/candidate/trust-invitations")
    }

    func homeSummary() async throws -> CandidateTrustInvitationHomeSummary {
        try await authenticated(path: "/candidate/trust-invitations/home-summary")
    }

    func readMine(id: String) async throws -> CandidateTrustInvitation {
        try await authenticated(path: "/candidate/trust-invitations/\(try safeID(id))")
    }

    func acceptMine(id: String) async throws -> CandidateTrustInvitation {
        try await authenticated(path: "/candidate/trust-invitations/\(try safeID(id))/accept", method: .post)
    }

    func declineMine(id: String) async throws -> CandidateTrustInvitation {
        try await authenticated(path: "/candidate/trust-invitations/\(try safeID(id))/decline", method: .post)
    }

    func finalizeMine(id: String, shareID: String, consentVersion: Int) async throws -> CandidateTrustInvitation {
        try await authenticated(
            path: "/candidate/trust-invitations/\(try safeID(id))/finalize",
            method: .post,
            body: try APIJSONCoder.makeEncoder().encode(FinalizeTrustInvitationRequest(
                passportShareId: shareID,
                consentVersion: consentVersion
            ))
        )
    }

    private func authenticated<Response: Decodable>(
        path: String, method: HTTPMethod = .get, body: Data? = nil
    ) async throws -> Response {
        let data = try await session.sendAuthenticated(NetworkRequest(
            path: path,
            method: method,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: body
        ))
        return try APIJSONCoder.makeDecoder().decode(Response.self, from: data)
    }

    private func safeID(_ value: String) throws -> String {
        guard (1...255).contains(value.utf8.count), value.utf8.allSatisfy({
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }) else { throw NetworkError.invalidURL }
        return value
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
        Group {
            if let invitationID = presentation.invitationID {
                CandidateTrustInvitationDetailView(invitationID: invitationID)
            } else {
                publicInvitationBody
            }
        }
    }

    private var publicInvitationBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    ProductGuidanceView(topic: .invitation)
                    if let invitation {
                        Text("Trust Invitation").font(KairoTypography.title)
                        Text("Review this invitation using the verified account it was sent to.")
                            .font(KairoTypography.body)
                        Text(accepted ? "Accepted" : invitation.status.capitalized).font(KairoTypography.headline)
                        if accepted {
                            Text("Invitation accepted. Open the authenticated invitation to review its organization, requirements, and sharing consent.")
                            Button("Review invitation") {
                                dismiss()
                                router.showTrustInvitation(id: invitation.publicId)
                            }
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

struct TrustInvitationHomeCard: View {
    @Environment(\.trustInvitationService) private var service
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: AppSessionStore
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @State private var summary: CandidateTrustInvitationHomeSummary?

    var body: some View {
        Group {
            if let invitation = summary?.latestActionableInvitation {
                Button {
                    router.showTrustInvitation(id: invitation.publicId)
                } label: {
                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                        Text(invitation.acceptedAt == nil
                             ? "Trust Invitation from \(invitation.organizationName)"
                             : "Complete requirements for \(invitation.organizationName)")
                            .font(KairoTypography.recordTitle)
                            .foregroundStyle(KairoColors.textPrimary)
                        Text(invitation.shareAction?.label
                             ?? "\(invitation.completedRequirements) of \(invitation.requiredRequirements) required items completed")
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("candidate.home.trustInvitation")
            }
        }
        .task(id: "\(session.currentUser?.id ?? "signed-out").\(refreshStore.revision)") {
            guard session.currentUser != nil, let service else { summary = nil; return }
            summary = try? await service.homeSummary()
        }
    }
}

struct TrustInvitationsListView: View {
    @Environment(\.trustInvitationService) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var invitations: [CandidateTrustInvitation] = []
    @State private var selected: CandidateTrustInvitation?
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    KairoLoadingStateView(title: "Loading invitations", message: "Checking your verified account for organization requests.")
                } else if failed {
                    KairoErrorStateView(
                        title: "Invitations unavailable",
                        message: "Check your connection and try again. No invitation details were changed.",
                        retryAction: { Task { await load() } }
                    )
                } else if invitations.isEmpty {
                    KairoEmptyStateView(
                        title: "No Trust Invitations",
                        message: "Invitations sent to your verified account will appear here automatically.",
                        systemImage: "person.crop.circle.badge.checkmark"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                            ForEach(invitations) { invitation in
                                Button { selected = invitation } label: {
                                    KairoSection(compact: true) {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                                Text(invitation.organizationName).font(KairoTypography.recordTitle)
                                                if let role = invitation.role { Text(role).font(KairoTypography.footnote) }
                                                Text("\(invitation.completedRequirements) of \(invitation.requiredRequirements) required items completed")
                                                    .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                                            }
                                            Spacer(minLength: KairoSpacing.small)
                                            Text(Self.statusTitle(invitation.lifecycleState))
                                                .font(KairoTypography.caption)
                                                .foregroundStyle(KairoColors.teal)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("candidate.trustInvitation.list.\(invitation.publicId)")
                            }
                        }
                        .padding(KairoSpacing.medium)
                    }
                    .refreshable { await load() }
                }
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Trust Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task { await load() }
        .sheet(item: $selected, onDismiss: { Task { await load() } }) { invitation in
            CandidateTrustInvitationDetailView(invitationID: invitation.publicId)
        }
    }

    private func load() async {
        guard let service else { loading = false; failed = true; return }
        do {
            invitations = try await service.listMine()
            failed = false
        } catch {
            failed = true
        }
        loading = false
    }

    private static func statusTitle(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct CandidateTrustInvitationDetailView: View {
    let invitationID: String
    @Environment(\.trustInvitationService) private var service
    @Environment(\.passportShareService) private var passportShareService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @State private var invitation: CandidateTrustInvitation?
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var sharing = false
    @State private var selectedOptional: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    if let invitation {
                        KairoSection {
                            Text("Trust Invitation").font(KairoTypography.sectionEyebrow)
                            Text(invitation.organizationName).font(KairoTypography.title)
                            Text(invitation.lifecycleState.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(KairoTypography.caption)
                                .foregroundStyle(KairoColors.teal)
                            if let role = invitation.role { Text(role).font(KairoTypography.bodyStrong) }
                            if let purpose = invitation.purpose { Text(purpose).font(KairoTypography.body) }
                            Text("Expires \(invitation.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                            if let message = invitation.message { Text(message).font(KairoTypography.footnote) }
                        }
                        if invitation.acceptedAt == nil, invitation.actionable {
                            KairoSection {
                                Text("Accepting lets you complete the requested checks. Your Passport is shared only after a separate final consent.")
                                    .font(KairoTypography.footnote)
                                KairoPrimaryButton(title: "Accept invitation", isLoading: busy) {
                                    Task { await mutate { try await $0.acceptMine(id: invitationID) } }
                                }
                                KairoSecondaryButton(title: "Decline invitation") {
                                    Task { await mutate { try await $0.declineMine(id: invitationID) } }
                                }
                                .disabled(busy)
                            }
                        }
                        requirements(invitation)
                        if invitation.shareAction?.action == "OPEN_PASSPORT", invitation.actionable {
                            KairoSection {
                                Text(invitation.shareAction?.label ?? "Review & Share")
                                    .font(KairoTypography.headline)
                                Text("Review the exact requested Passport information before giving final consent.")
                                    .font(KairoTypography.footnote)
                                KairoPrimaryButton(title: "Review & Share") { sharing = true }
                            }
                        }
                    } else if errorMessage == nil {
                        KairoLoadingStateView(title: "Opening invitation", message: "Confirming your invitation and latest requirements.")
                    }
                    if let errorMessage {
                        KairoErrorStateView(title: "Invitation unavailable", message: errorMessage,
                                            retryAction: { Task { await load() } })
                    }
                }
                .padding(KairoSpacing.medium)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Trust Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .task { await load() }
        .sheet(isPresented: $sharing) {
            if let invitation { InvitationShareConsentView(
                invitation: invitation,
                selectedOptional: $selectedOptional,
                isSubmitting: busy,
                errorMessage: errorMessage,
                submit: { Task { await finalize(invitation) } }
            ) }
        }
        .accessibilityIdentifier("candidate.trustInvitation.detail")
    }

    private func requirements(_ invitation: CandidateTrustInvitation) -> some View {
        KairoSection {
            KairoSectionHeading(title: "Requirements", count: invitation.requirements.count)
            Text("\(invitation.completedRequirements) of \(invitation.requiredRequirements) required items completed")
                .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
            ForEach(invitation.requirements) { requirement in
                Divider()
                Button {
                    open(requirement.action)
                } label: {
                    HStack {
                        Image(systemName: requirement.status == "completed" ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(requirement.status == "completed" ? KairoColors.success : KairoColors.warning)
                        VStack(alignment: .leading) {
                            Text(Self.requirementTitle(requirement.requirementType))
                                .font(KairoTypography.recordTitle)
                            Text("\(requirement.mandatory ? "Required" : "Optional") · \(requirement.status.replacingOccurrences(of: "_", with: " ").capitalized)")
                                .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                        }
                        Spacer()
                        if requirement.status != "completed", requirement.action != nil {
                            Text("Open").font(KairoTypography.action)
                        }
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(invitation.acceptedAt == nil || requirement.status == "completed")
            }
            if invitation.acceptedAt != nil, invitation.actionable {
                KairoSecondaryButton(title: "Refresh requirements") { Task { await load() } }
                    .disabled(busy)
            }
        }
    }

    private func load() async {
        guard let service else { errorMessage = "Invitation service is unavailable."; return }
        do { invitation = try await service.readMine(id: invitationID); errorMessage = nil }
        catch { errorMessage = "Check your connection and that this invitation belongs to your verified account." }
    }

    private func mutate(_ action: (any TrustInvitationServing) async throws -> CandidateTrustInvitation) async {
        guard let service, !busy else { return }
        busy = true; defer { busy = false }
        do {
            invitation = try await action(service)
            refreshStore.candidateDataChanged()
            errorMessage = nil
        }
        catch { errorMessage = "The invitation could not be updated. Nothing was shared." }
    }

    private func open(_ action: String?) {
        dismiss()
        switch action {
        case "OPEN_IDENTITY": router.showDigiLocker()
        case "OPEN_PERMANENT_ADDRESS": router.showPermanentAddress()
        case "OPEN_EMPLOYMENT", "OPEN_EDUCATION", "OPEN_CERTIFICATION", "OPEN_REFERENCES": router.selectTab(.career)
        default: break
        }
    }

    private func finalize(_ current: CandidateTrustInvitation) async {
        guard let service, !busy,
              current.shareAction?.action == "OPEN_PASSPORT",
              current.requirements.allSatisfy({ !$0.mandatory || $0.status == "completed" }) else { return }
        busy = true; defer { busy = false }
        do {
            let capabilities = try await passportShareService.capabilities()
            let permissions = CandidateTrustInvitationSharing.permissions(
                for: current.requirements,
                selectedOptional: selectedOptional
            )
            let mode: PassportSharingMode = permissions.includeProfile || permissions.includeCertifications ? .mixed : .verifiedOnly
            let supported = Set(capabilities.options(for: mode))
            guard Set(permissions.enabledOptions).isSubset(of: supported) else {
                throw PassportShareServiceError.capabilitiesUnavailable
            }
            let creation = try await passportShareService.createShare(PassportShareMutationInput(
                label: "Trust Invitation · \(current.organizationName)",
                permissions: permissions,
                expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                sharingMode: mode
            ))
            invitation = try await service.finalizeMine(
                id: invitationID,
                shareID: creation.share.id,
                consentVersion: current.requirementsVersion
            )
            refreshStore.candidateDataChanged()
            sharing = false
            errorMessage = nil
        } catch {
            errorMessage = "Passport sharing could not be completed. Review the invitation again; no automatic retry was made."
        }
    }

    fileprivate static func requirementTitle(_ value: String) -> String {
        ["identity": "Identity", "employment": "Employment", "education": "Education",
         "certification": "Certifications", "professional_reference": "Professional references",
         "permanent_address": "Permanent Address"][value] ?? "Requirement"
    }
}

nonisolated enum CandidateTrustInvitationSharing {
    static func permissions(
        for requirements: [CandidateTrustInvitationRequirement],
        selectedOptional: Set<String>
    ) -> PassportSharePermissions {
        var permissions = PassportSharePermissions.privacyPreserving
        for requirement in requirements where requirement.mandatory
            || (requirement.status == "completed" && selectedOptional.contains(requirement.requirementType)) {
            switch requirement.requirementType {
            case "identity": permissions.includeProfile = true
            case "employment":
                permissions.includeEmployments = true
                permissions.showEmployerNames = true
            case "education": permissions.includeEducations = true
            case "certification": permissions.includeCertifications = true
            default: break
            }
        }
        return permissions
    }
}

private struct InvitationShareConsentView: View {
    let invitation: CandidateTrustInvitation
    @Binding var selectedOptional: Set<String>
    let isSubmitting: Bool
    let errorMessage: String?
    let submit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    Text("Share Passport with \(invitation.organizationName)").font(KairoTypography.title)
                    Text("Accepting the invitation did not share your Passport. This is your final consent.")
                        .font(KairoTypography.footnote)
                    KairoSection {
                        ForEach(invitation.requirements.filter { ["identity", "employment", "education", "certification"].contains($0.requirementType) }) { item in
                            let selected = item.mandatory || selectedOptional.contains(item.requirementType)
                            Button {
                                guard !item.mandatory, item.status == "completed" else { return }
                                if selected { selectedOptional.remove(item.requirementType) }
                                else { selectedOptional.insert(item.requirementType) }
                            } label: {
                                HStack {
                                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                                    VStack(alignment: .leading) {
                                        Text(CandidateTrustInvitationDetailView.requirementTitle(item.requirementType))
                                        Text(item.mandatory ? "Required by \(invitation.organizationName)" : "Optional")
                                            .font(KairoTypography.caption)
                                    }
                                    Spacer()
                                    if item.mandatory { Image(systemName: "lock.fill") }
                                }.frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .disabled(item.mandatory || item.status != "completed")
                        }
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(KairoColors.danger) }
                    KairoPrimaryButton(title: "Share with \(invitation.organizationName)", isLoading: isSubmitting, action: submit)
                        .disabled(isSubmitting || !invitation.requirements.allSatisfy { !$0.mandatory || $0.status == "completed" })
                }.padding(KairoSpacing.medium)
            }
            .navigationTitle("Review & Share").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
