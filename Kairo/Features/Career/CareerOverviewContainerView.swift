import SwiftUI

struct CareerOverviewContainerView: View {
    @Environment(\.careerOverviewService) private var careerOverviewService
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var state = CareerOverviewState.loading(summary: .placeholder)
    @State private var hasLoaded = false

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

    private func load(showLoading: Bool) async {
        let previousState = state

        if showLoading || !hasRenderableContent(previousState) {
            state = .loading(summary: cachedSummary)
        }

        do {
            state = CareerOverviewMapper.map(try await careerOverviewService.loadOverview())
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
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
