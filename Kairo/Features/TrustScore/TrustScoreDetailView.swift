import SwiftUI

struct TrustScorePresentation: Identifiable, Equatable, Sendable {
    let id = UUID()
}

struct TrustScoreDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trustScoreService) private var trustScoreService
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var score: TrustScoreResponseDTO?
    @State private var isLoading = true
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var confirmation: ConsentConfirmation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    content
                }
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
            }
            .background(
                LinearGradient(
                    colors: [KairoColors.background, KairoColors.surfaceMuted.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Trust Score details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isMutating)
                }
            }
            .task { await load(showLoading: true) }
            .refreshable { await load(showLoading: false) }
            .confirmationDialog(
                confirmation?.title ?? "",
                isPresented: Binding(
                    get: { confirmation != nil },
                    set: { if !$0 { confirmation = nil } }
                ),
                titleVisibility: .visible
            ) {
                if confirmation == .grant {
                    Button("Give consent") { mutate(.grant) }
                } else if confirmation == .withdraw {
                    Button("Withdraw consent", role: .destructive) { mutate(.withdraw) }
                }
                Button("Cancel", role: .cancel) { confirmation = nil }
            } message: {
                Text(confirmation?.message ?? "")
            }
        }
        .accessibilityIdentifier(KairoAccessibilityID.trustScoreDetail)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading, score == nil {
            KairoLoadingStateView(
                title: "Loading Trust Score",
                message: "Kairo is fetching the current backend-calculated score and explanation."
            )
        } else if let score {
            scoreSummary(score)
            explanation(score)
            breakdown(score)
            contributors(score)
            consentAction(score)
        } else {
            KairoErrorStateView(
                title: "Trust Score unavailable",
                message: errorMessage ?? "Kairo could not load your Trust Score.",
                retryAction: { Task { await load(showLoading: true) } }
            )
        }

        if let errorMessage, score != nil {
            KairoErrorStateView(
                title: "Trust Score action failed",
                message: errorMessage
            )
        }
    }

    private func scoreSummary(_ score: TrustScoreResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            HStack {
                Label("Trust Score", systemImage: "shield.checkered")
                    .font(KairoTypography.caption)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, KairoSpacing.small)
                    .padding(.vertical, KairoSpacing.xSmall)
                    .background(Color.white.opacity(0.14), in: Capsule())

                Spacer(minLength: KairoSpacing.small)

                if let date = score.lastCalculatedAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(KairoTypography.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }

            if let overall = score.overall {
                Text("\(overall) / 100")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .minimumScaleFactor(0.72)
            } else {
                Text("No score available")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.white)
            }

            Text(statusTitle(score.status))
                .font(KairoTypography.headline)
                .foregroundStyle(Color.white.opacity(0.88))

            ProgressView(value: Double(score.verificationCompletenessPercentage) / 100)
                .tint(KairoColors.accent)
                .background(Color.white.opacity(0.18))

            Text("Verification completeness: \(score.verificationCompletenessPercentage)%")
                .font(KairoTypography.footnote)
                .foregroundStyle(Color.white.opacity(0.76))

            if let breakdown = score.breakdown {
                Divider().overlay(Color.white.opacity(0.18))
                HStack(spacing: KairoSpacing.xSmall) {
                    heroMetric("Identity", value: breakdown.identity)
                    heroMetric("Employment", value: breakdown.employment)
                    heroMetric("Education", value: breakdown.education)
                }
            }
        }
        .padding(KairoSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.08, blue: 0.19), Color(red: 0.01, green: 0.50, blue: 0.56)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .kairoShadow(KairoShadow.card)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Trust Score, \(score.overall.map(String.init) ?? "not available") out of 100, \(statusTitle(score.status)), verification completeness \(score.verificationCompletenessPercentage) percent"
        )
    }

    private func heroMetric(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(title)
                .font(KairoTypography.caption)
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("\(Int(value.rounded()))")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func explanation(_ score: TrustScoreResponseDTO) -> some View {
        if score.status == .consentRequired {
            KairoCard {
                Text("Your consent is required")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)
                Text("Kairo calculates your Trust Score from backend verification outcomes. The app never calculates or estimates this score on your device.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if let reason = score.manualReviewReason, !reason.isEmpty {
            KairoCard {
                Text("What this means")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)
                Text(reason)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func breakdown(_ score: TrustScoreResponseDTO) -> some View {
        if let breakdown = score.breakdown {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                Text("Category breakdown")
                    .font(KairoTypography.sectionEyebrow)
                    .foregroundStyle(KairoColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                KairoCard {
                    breakdownRow(title: "Identity", value: breakdown.identity)
                    Divider()
                    breakdownRow(title: "Employment", value: breakdown.employment)
                    Divider()
                    breakdownRow(title: "Education", value: breakdown.education)
                }
            }
            .accessibilityIdentifier(KairoAccessibilityID.trustScoreBreakdown)
        }
    }

    private func breakdownRow(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            HStack {
                Text(title)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)
                Spacer()
                Text("\(Int(value.rounded())) / 100")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
            }
            ProgressView(value: value / 100)
                .tint(KairoColors.accent)
        }
        .padding(.vertical, KairoSpacing.xxSmall)
    }

    @ViewBuilder
    private func contributors(_ score: TrustScoreResponseDTO) -> some View {
        let items = score.positiveContributors + score.negativeContributors + score.criticalOverrides
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                Text("Why your score looks this way")
                    .font(KairoTypography.sectionEyebrow)
                    .foregroundStyle(KairoColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                KairoCard {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Divider() }
                        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                            Text(item.label)
                                .font(KairoTypography.bodyStrong)
                                .foregroundStyle(KairoColors.textPrimary)
                            Text(item.detail)
                                .font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func consentAction(_ score: TrustScoreResponseDTO) -> some View {
        if score.status == .consentRequired {
            KairoPrimaryButton(
                title: "Give Trust Score consent",
                isLoading: isMutating,
                accessibilityIdentifier: KairoAccessibilityID.trustScoreGrantConsent,
                action: { confirmation = .grant }
            )
            .disabled(isMutating)
        } else {
            Button(role: .destructive) {
                confirmation = .withdraw
            } label: {
                Text("Withdraw Trust Score consent")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isMutating)
            .accessibilityIdentifier(KairoAccessibilityID.trustScoreWithdrawConsent)
        }
    }

    private func load(showLoading: Bool) async {
        if showLoading { isLoading = true }
        errorMessage = nil
        do {
            let loaded = try await trustScoreService.loadScore()
            await MainActor.run {
                score = loaded
                isLoading = false
            }
        } catch {
            await handle(error, loading: false)
        }
    }

    private func mutate(_ action: ConsentConfirmation) {
        confirmation = nil
        isMutating = true
        errorMessage = nil
        Task {
            do {
                let updated: TrustScoreResponseDTO
                switch action {
                case .grant:
                    updated = try await trustScoreService.grantConsent(
                        version: score?.scoreVersion ?? "v1"
                    )
                case .withdraw:
                    updated = try await trustScoreService.withdrawConsent()
                }
                await MainActor.run {
                    score = updated
                    isMutating = false
                    refreshStore.candidateDataChanged()
                }
            } catch {
                await handle(error, loading: false)
            }
        }
    }

    @MainActor
    private func handle(_ error: Error, loading: Bool) async {
        isLoading = loading
        isMutating = false
        errorMessage = trustScoreErrorMessage(error)
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            await sessionStore.refreshLaunchRoute()
        }
    }

    private func trustScoreErrorMessage(_ error: Error) -> String {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError): return apiError.message
            case .transport: return "Kairo could not reach the Trust Score service. Check your connection and try again."
            case .invalidResponse: return "Kairo received an unexpected Trust Score response."
            case .invalidURL: return "Kairo's Trust Score configuration is invalid."
            case .unavailableInDemoMode: return "This action is unavailable in Demo Mode."
            }
        }
        return error.localizedDescription
    }

    private func statusTitle(_ status: TrustScoreResponseDTO.Status) -> String {
        switch status {
        case .consentRequired: "Consent required"
        case .incompleteVerification: "Verification in progress"
        case .calculated: "Calculated"
        case .criticalManualFraudReview: "Under review"
        }
    }
}

private enum ConsentConfirmation: Equatable {
    case grant
    case withdraw

    var title: String {
        switch self {
        case .grant: "Give consent to calculate your Trust Score?"
        case .withdraw: "Withdraw Trust Score consent?"
        }
    }

    var message: String {
        switch self {
        case .grant:
            "Kairo will use your verified identity, employment, and education outcomes to calculate an explainable Trust Score."
        case .withdraw:
            "Kairo will stop showing your Trust Score where consent is required. Existing audit snapshots may be retained for integrity."
        }
    }
}
