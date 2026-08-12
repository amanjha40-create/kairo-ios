import SwiftUI

struct CareerOverviewContainerView: View {
    @Environment(\.careerOverviewService) private var careerOverviewService
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var state = CareerOverviewState.loading(summary: .placeholder)
    @State private var hasLoaded = false
    @State private var presentedSheet: CareerMutationSheet?
    @State private var pendingDeleteRequest: CareerDeleteRequest?
    @State private var mutationError: CareerMutationPresentationError?
    @State private var activeLoadingMessage: String?
    @State private var isDeleting = false

    var body: some View {
        CareerOverviewScreenView(
            state: state,
            retryAction: {
                Task {
                    await load(showLoading: true)
                }
            },
            refreshAction: {
                await load(showLoading: false)
            },
            addEmploymentAction: { presentedSheet = .employment(mode: .create, recordID: nil, draft: .init()) },
            editEmploymentAction: { item in
                Task {
                    await presentEmploymentEditor(for: item)
                }
            },
            deleteEmploymentAction: { item in
                pendingDeleteRequest = .employment(item)
            },
            addEducationAction: { presentedSheet = .education(mode: .create, recordID: nil, draft: .init()) },
            editEducationAction: { item in
                Task {
                    await presentEducationEditor(for: item)
                }
            },
            deleteEducationAction: { item in
                pendingDeleteRequest = .education(item)
            },
            addCertificationAction: { presentedSheet = .certification(mode: .create, recordID: nil, draft: .init()) },
            editCertificationAction: { item in
                Task {
                    await presentCertificationEditor(for: item)
                }
            },
            deleteCertificationAction: { item in
                pendingDeleteRequest = .certification(item)
            },
            addProjectAction: { presentedSheet = .project(mode: .create, recordID: nil, draft: .init()) },
            editProjectAction: { item in
                Task {
                    await presentProjectEditor(for: item)
                }
            },
            deleteProjectAction: { item in
                pendingDeleteRequest = .project(item)
            },
            addSkillAction: { presentedSheet = .skill(mode: .create, recordID: nil, draft: .init(), existingNames: currentSkillNames()) },
            editSkillAction: { item in
                presentedSheet = .skill(
                    mode: .edit,
                    recordID: item.routeID,
                    draft: CareerSkillDraft(name: item.name),
                    existingNames: currentSkillNames(excluding: item.routeID)
                )
            },
            deleteSkillAction: { item in
                pendingDeleteRequest = .skill(item)
            }
        )
        .task {
            guard !hasLoaded else {
                return
            }

            hasLoaded = true
            state = .loading(summary: cachedSummary)
            await load(showLoading: true)
        }
        .overlay {
            if let activeLoadingMessage {
                loadingOverlay(message: activeLoadingMessage)
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            mutationSheet(for: sheet)
        }
        .alert(item: $mutationError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("Done"))
            )
        }
        .confirmationDialog(
            pendingDeleteRequest?.title ?? "",
            isPresented: deleteDialogBinding,
            titleVisibility: .visible
        ) {
            if let pendingDeleteRequest {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteRecord(pendingDeleteRequest)
                    }
                }
                .accessibilityIdentifier(pendingDeleteRequest.confirmationAccessibilityIdentifier)
            }

            Button("Cancel", role: .cancel) {
                pendingDeleteRequest = nil
            }
        } message: {
            if let pendingDeleteRequest {
                Text(pendingDeleteRequest.message)
            }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteRequest != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteRequest = nil
                }
            }
        )
    }

    private var cachedSummary: CareerProfessionalSummary {
        if let currentUser = sessionStore.currentUser {
            return CareerProfessionalSummary(
                initials: initials(from: currentUser),
                name: currentUser.fullName?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmpty ?? currentUser.email,
                professionalHeadline: currentUser.headline ?? currentUser.currentRole ?? "Professional headline not added yet",
                currentCompany: "Current company not added yet",
                currentLocation: currentUser.location ?? "Current location not added yet",
                trustPassportStatus: currentUser.isActive ? "Active" : "Pending"
            )
        }

        return .placeholder
    }

    private func currentSkillNames(excluding routeID: String? = nil) -> [String] {
        switch state.phase {
        case .populated(let content), .empty(let content):
            return content.skills
                .filter { skill in
                    guard let routeID else {
                        return true
                    }
                    return skill.routeID != routeID
                }
                .map(\.name)
        case .loading, .error:
            return []
        }
    }

    private func load(showLoading: Bool) async {
        let previousState = state

        if showLoading || !hasRenderableContent(previousState) {
            state = .loading(summary: cachedSummary)
        }

        do {
            let overview = try await careerOverviewService.loadOverview()
            await MainActor.run {
                sessionStore.replaceCurrentUser(overview.user)
                state = CareerOverviewMapper.map(overview)
            }
        } catch {
            if CareerOverviewMapper.requiresSessionRecovery(for: error) {
                await sessionStore.refreshLaunchRoute()
                return
            }

            if hasRenderableContent(previousState), !showLoading {
                state = previousState
                return
            }

            state = CareerOverviewMapper.errorState(for: error, summary: cachedSummary)
        }
    }

    private func presentEmploymentEditor(for item: CareerEmploymentItem) async {
        await presentRecordEditor(
            loadingMessage: "Loading employment",
            fallbackTitle: "Employment unavailable"
        ) {
            let record = try await careerOverviewService.loadEmployment(id: item.routeID)
            return .employment(mode: .edit, recordID: item.routeID, draft: CareerEmploymentDraft(record: record))
        }
    }

    private func presentEducationEditor(for item: CareerEducationItem) async {
        await presentRecordEditor(
            loadingMessage: "Loading education",
            fallbackTitle: "Education unavailable"
        ) {
            let record = try await careerOverviewService.loadEducation(id: item.routeID)
            return .education(mode: .edit, recordID: item.routeID, draft: CareerEducationDraft(record: record))
        }
    }

    private func presentCertificationEditor(for item: CareerCertificationItem) async {
        await presentRecordEditor(
            loadingMessage: "Loading certification",
            fallbackTitle: "Certification unavailable"
        ) {
            let record = try await careerOverviewService.loadCertification(id: item.routeID)
            return .certification(mode: .edit, recordID: item.routeID, draft: CareerCertificationDraft(record: record))
        }
    }

    private func presentProjectEditor(for item: CareerProjectItem) async {
        await presentRecordEditor(
            loadingMessage: "Loading project",
            fallbackTitle: "Project unavailable"
        ) {
            let record = try await careerOverviewService.loadProject(id: item.routeID)
            return .project(mode: .edit, recordID: item.routeID, draft: CareerProjectDraft(record: record))
        }
    }

    private func presentRecordEditor(
        loadingMessage: String,
        fallbackTitle: String,
        operation: @escaping @Sendable () async throws -> CareerMutationSheet
    ) async {
        await MainActor.run {
            activeLoadingMessage = loadingMessage
            mutationError = nil
        }

        do {
            let sheet = try await operation()
            await MainActor.run {
                activeLoadingMessage = nil
                presentedSheet = sheet
            }
        } catch {
            if CareerOverviewMapper.requiresSessionRecovery(for: error) {
                await MainActor.run {
                    activeLoadingMessage = nil
                }
                await sessionStore.refreshLaunchRoute()
                return
            }

            let mapped = CareerMutationErrorMapper.map(error, fallbackTitle: fallbackTitle)
            await MainActor.run {
                activeLoadingMessage = nil
                mutationError = mapped
            }
        }
    }

    @ViewBuilder
    private func mutationSheet(for sheet: CareerMutationSheet) -> some View {
        switch sheet {
        case .employment(let mode, let recordID, let draft):
            CareerEmploymentEditorSheet(mode: mode, draft: draft) { draft in
                try await saveEmployment(mode: mode, recordID: recordID, draft: draft)
            }
        case .education(let mode, let recordID, let draft):
            CareerEducationEditorSheet(mode: mode, draft: draft) { draft in
                try await saveEducation(mode: mode, recordID: recordID, draft: draft)
            }
        case .certification(let mode, let recordID, let draft):
            CareerCertificationEditorSheet(mode: mode, draft: draft) { draft in
                try await saveCertification(mode: mode, recordID: recordID, draft: draft)
            }
        case .project(let mode, let recordID, let draft):
            CareerProjectEditorSheet(mode: mode, draft: draft) { draft in
                try await saveProject(mode: mode, recordID: recordID, draft: draft)
            }
        case .skill(let mode, let recordID, let draft, let existingNames):
            CareerSkillEditorSheet(mode: mode, existingNames: existingNames, draft: draft) { draft in
                try await saveSkill(mode: mode, recordID: recordID, draft: draft)
            }
        }
    }

    private func saveEmployment(
        mode: CareerMutationMode,
        recordID: String?,
        draft: CareerEmploymentDraft
    ) async throws {
        let currentUser = try requireCurrentUser()
        let overview: CareerOverview

        switch mode {
        case .create:
            overview = try await careerOverviewService.createEmployment(draft.createRequest(currentUser: currentUser))
        case .edit:
            guard let recordID else {
                throw CareerOverviewContainerError.missingRecordIdentifier
            }
            overview = try await careerOverviewService.updateEmployment(
                id: recordID,
                request: draft.updateRequest()
            )
        }

        await applyUpdatedOverview(overview)
    }

    private func saveEducation(
        mode: CareerMutationMode,
        recordID: String?,
        draft: CareerEducationDraft
    ) async throws {
        let overview: CareerOverview

        switch mode {
        case .create:
            overview = try await careerOverviewService.createEducation(draft.createRequest())
        case .edit:
            guard let recordID else {
                throw CareerOverviewContainerError.missingRecordIdentifier
            }
            overview = try await careerOverviewService.updateEducation(
                id: recordID,
                request: draft.updateRequest()
            )
        }

        await applyUpdatedOverview(overview)
    }

    private func saveCertification(
        mode: CareerMutationMode,
        recordID: String?,
        draft: CareerCertificationDraft
    ) async throws {
        let overview: CareerOverview

        switch mode {
        case .create:
            overview = try await careerOverviewService.createCertification(draft.createRequest())
        case .edit:
            guard let recordID else {
                throw CareerOverviewContainerError.missingRecordIdentifier
            }
            overview = try await careerOverviewService.updateCertification(
                id: recordID,
                request: draft.updateRequest()
            )
        }

        await applyUpdatedOverview(overview)
    }

    private func saveProject(
        mode: CareerMutationMode,
        recordID: String?,
        draft: CareerProjectDraft
    ) async throws {
        let overview: CareerOverview

        switch mode {
        case .create:
            overview = try await careerOverviewService.createProject(draft.createRequest())
        case .edit:
            guard let recordID else {
                throw CareerOverviewContainerError.missingRecordIdentifier
            }
            overview = try await careerOverviewService.updateProject(
                id: recordID,
                request: draft.updateRequest()
            )
        }

        await applyUpdatedOverview(overview)
    }

    private func saveSkill(
        mode: CareerMutationMode,
        recordID: String?,
        draft: CareerSkillDraft
    ) async throws {
        let overview: CareerOverview

        switch mode {
        case .create:
            overview = try await careerOverviewService.createSkill(draft.createRequest())
        case .edit:
            guard let recordID else {
                throw CareerOverviewContainerError.missingRecordIdentifier
            }
            overview = try await careerOverviewService.replaceSkill(
                id: recordID,
                with: draft.createRequest()
            )
        }

        await applyUpdatedOverview(overview)
    }

    private func deleteRecord(_ request: CareerDeleteRequest) async {
        guard !isDeleting else {
            return
        }

        pendingDeleteRequest = nil
        isDeleting = true
        activeLoadingMessage = "Deleting record"

        do {
            let overview: CareerOverview
            switch request {
            case .employment(let item):
                overview = try await careerOverviewService.deleteEmployment(id: item.routeID)
            case .education(let item):
                overview = try await careerOverviewService.deleteEducation(id: item.routeID)
            case .certification(let item):
                overview = try await careerOverviewService.deleteCertification(id: item.routeID)
            case .project(let item):
                overview = try await careerOverviewService.deleteProject(id: item.routeID)
            case .skill(let item):
                overview = try await careerOverviewService.deleteSkill(id: item.routeID)
            }

            await applyUpdatedOverview(overview)
            await MainActor.run {
                isDeleting = false
                activeLoadingMessage = nil
            }
        } catch {
            if CareerOverviewMapper.requiresSessionRecovery(for: error) {
                await MainActor.run {
                    isDeleting = false
                    activeLoadingMessage = nil
                }
                await sessionStore.refreshLaunchRoute()
                return
            }

            let fallbackTitle: String
            switch request {
            case .employment:
                fallbackTitle = "Employment unavailable"
            case .education:
                fallbackTitle = "Education unavailable"
            case .certification:
                fallbackTitle = "Certification unavailable"
            case .project:
                fallbackTitle = "Project unavailable"
            case .skill:
                fallbackTitle = "Skill unavailable"
            }

            let mapped = CareerMutationErrorMapper.map(error, fallbackTitle: fallbackTitle)
            await MainActor.run {
                isDeleting = false
                activeLoadingMessage = nil
                mutationError = mapped
            }
        }
    }

    private func applyUpdatedOverview(_ overview: CareerOverview) async {
        await MainActor.run {
            sessionStore.replaceCurrentUser(overview.user)
            state = CareerOverviewMapper.map(overview)
        }
    }

    private func requireCurrentUser() throws -> AppUser {
        if let currentUser = sessionStore.currentUser {
            return currentUser
        }

        throw CareerOverviewContainerError.missingCurrentUser
    }

    private func hasRenderableContent(_ state: CareerOverviewState) -> Bool {
        switch state.phase {
        case .populated, .empty:
            return true
        case .loading, .error:
            return false
        }
    }

    private func initials(from user: AppUser) -> String {
        let parts = (user.fullName ?? user.email)
            .split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." || $0 == "_" })
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }

        let value = parts.joined()
        return value.isEmpty ? "KA" : value
    }

    private func loadingOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.06)
                .ignoresSafeArea()

            KairoCard {
                HStack(spacing: KairoSpacing.medium) {
                    ProgressView()
                        .tint(KairoColors.brandPrimary)

                    Text(message)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                }
            }
            .frame(maxWidth: 280)
        }
    }
}

private enum CareerOverviewContainerError: LocalizedError {
    case missingCurrentUser
    case missingRecordIdentifier

    var errorDescription: String? {
        switch self {
        case .missingCurrentUser:
            "Kairo couldn't load the current candidate profile required for this Career change."
        case .missingRecordIdentifier:
            "Kairo couldn't find the backend record identifier required for this Career change."
        }
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

extension CareerMutationPresentationError: Identifiable {
    var id: String {
        "\(title)|\(message)"
    }
}
