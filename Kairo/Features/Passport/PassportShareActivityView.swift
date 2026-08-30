import Combine
import SwiftUI

nonisolated struct PassportShareActivityItem: Identifiable, Equatable, Sendable {
    let share: PassportShare
    let analytics: PassportShareAnalytics?

    var id: String { share.id }
    var lastViewedAt: Date? { analytics?.lastViewedAt ?? share.lastViewedAt }
    var totalViews: Int? { analytics?.totalViews }
    var uniqueViews: Int? { analytics?.uniqueViews }
}

@MainActor
final class PassportShareActivityViewModel: ObservableObject {
    @Published private(set) var items: [PassportShareActivityItem] = []
    @Published private(set) var isLoading = false
    @Published var error: PassportSharePresentationError?

    private let service: any PassportShareServiceProtocol
    private var hasLoaded = false

    init(service: any PassportShareServiceProtocol) {
        self.service = service
    }

    var recentlyViewed: [PassportShareActivityItem] {
        items
            .filter { $0.lastViewedAt != nil }
            .sorted { ($0.lastViewedAt ?? .distantPast) > ($1.lastViewedAt ?? .distantPast) }
    }

    var activeUnviewed: [PassportShareActivityItem] {
        items
            .filter { $0.share.state == .active && $0.lastViewedAt == nil }
            .sorted { $0.share.createdAt > $1.share.createdAt }
    }

    var historicalUnviewed: [PassportShareActivityItem] {
        items
            .filter { $0.share.state != .active && $0.lastViewedAt == nil }
            .sorted { $0.share.updatedAt > $1.share.updatedAt }
    }

    func load() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let shares = try await service.listShares()
            items = await loadAnalytics(for: shares)
            hasLoaded = true
        } catch {
            self.error = .map(error, fallbackTitle: "Share activity unavailable")
        }
    }

    private func loadAnalytics(for shares: [PassportShare]) async -> [PassportShareActivityItem] {
        await withTaskGroup(of: PassportShareActivityItem.self) { group in
            for share in shares {
                group.addTask { [service] in
                    let analytics = try? await service.getAnalytics(shareID: share.id)
                    return PassportShareActivityItem(share: share, analytics: analytics)
                }
            }

            var loaded: [PassportShareActivityItem] = []
            for await item in group {
                loaded.append(item)
            }
            return loaded.sorted { $0.share.createdAt > $1.share.createdAt }
        }
    }
}

struct PassportShareActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: PassportShareActivityViewModel

    private let service: any PassportShareServiceProtocol
    private let onMutation: () -> Void

    init(
        service: any PassportShareServiceProtocol,
        onMutation: @escaping () -> Void
    ) {
        self.service = service
        self.onMutation = onMutation
        _model = StateObject(wrappedValue: PassportShareActivityViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    introduction
                    activityContent
                }
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Share Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .refreshable { await model.reload() }
        }
        .task { await model.load() }
        .alert(item: $model.error) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                primaryButton: .default(Text("Retry")) { Task { await model.reload() } },
                secondaryButton: .cancel()
            )
        }
        .presentationDetents([.large])
        .accessibilityIdentifier(KairoAccessibilityID.passportShareActivity)
    }

    private var introduction: some View {
        KairoCard {
            Text("Authoritative Passport views")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
            Text("Counts and last-viewed times come from Kairo's share analytics. Opening management screens never creates or increments a view.")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var activityContent: some View {
        if model.isLoading, model.items.isEmpty {
            KairoLoadingStateView(
                title: "Loading Share Activity",
                message: "Kairo is fetching the latest share-level view summaries."
            )
        } else if model.items.isEmpty {
            KairoEmptyStateView(
                title: "No Share Activity yet",
                message: "Create a Passport share when you are ready. Recipient views will appear here after the backend records them.",
                systemImage: "eye"
            )
        } else {
            activitySection(title: "Recently viewed", items: model.recentlyViewed)
            activitySection(title: "Active shares", items: model.activeUnviewed)
            activitySection(title: "Expired / Revoked history", items: model.historicalUnviewed)
        }
    }

    @ViewBuilder
    private func activitySection(title: String, items: [PassportShareActivityItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                Text(title)
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                ForEach(items) { item in
                    NavigationLink {
                        PassportShareDetailView(
                            service: service,
                            share: item.share,
                            onMutation: {
                                onMutation()
                                Task { await model.reload() }
                            }
                        )
                    } label: {
                        PassportShareActivityRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(KairoAccessibilityID.passportShareActivityRow(item.id))
                }
            }
            .accessibilityIdentifier(KairoAccessibilityID.passportShareActivityList)
        }
    }
}

private struct PassportShareActivityRow: View {
    let item: PassportShareActivityItem

    var body: some View {
        KairoCard {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                Image(systemName: item.share.state.symbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.share.displayLabel)
                            .font(KairoTypography.bodyStrong)
                            .foregroundStyle(KairoColors.textPrimary)
                        Spacer(minLength: KairoSpacing.small)
                        Text(item.share.state.title)
                            .font(KairoTypography.caption)
                            .foregroundStyle(statusColor)
                    }

                    if let totalViews = item.totalViews, let uniqueViews = item.uniqueViews {
                        Text("\(totalViews) total · \(uniqueViews) unique")
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textPrimary)
                    } else {
                        Text("View summary unavailable")
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                    }

                    Text(lastViewedText)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                    Text(expiryText)
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                    Text("Created \(item.share.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this share's management detail")
    }

    private var lastViewedText: String {
        item.lastViewedAt.map {
            "Last viewed \($0.formatted(date: .abbreviated, time: .shortened))"
        } ?? "No recipient views"
    }

    private var expiryText: String {
        item.share.expiresAt.map {
            "Expires \($0.formatted(date: .abbreviated, time: .shortened))"
        } ?? "No expiry"
    }

    private var accessibilityLabel: String {
        let counts: String
        if let totalViews = item.totalViews, let uniqueViews = item.uniqueViews {
            counts = "\(totalViews) total views, \(uniqueViews) unique views"
        } else {
            counts = "View summary unavailable"
        }
        return "\(item.share.displayLabel), \(item.share.state.title), \(counts), \(lastViewedText), \(expiryText)"
    }

    private var statusColor: Color {
        switch item.share.state {
        case .active: KairoColors.success
        case .expired: KairoColors.warning
        case .revoked, .unknown: KairoColors.textSecondary
        }
    }
}
