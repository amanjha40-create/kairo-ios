import SwiftUI

struct CandidateNotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var store: CandidateNotificationStore

    @State private var detailPath: [String] = []

    var body: some View {
        NavigationStack(path: $detailPath) {
            content
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }

                    if store.hasUnreadNotifications {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Mark all as read") {
                                Task {
                                    await store.markAllRead()
                                    await recoverSessionIfRequired()
                                }
                            }
                            .disabled(store.isMarkingAllRead)
                            .accessibilityIdentifier(KairoAccessibilityID.notificationsMarkAllRead)
                        }
                    }
                }
                .navigationDestination(for: String.self) { notificationID in
                    if let notification = store.items.first(where: { $0.id == notificationID }) {
                        CandidateNotificationDetailView(notification: notification)
                    } else {
                        KairoErrorStateView(
                            title: "Notification unavailable",
                            message: "Refresh Notifications and try again."
                        )
                        .padding(KairoSpacing.large)
                    }
                }
        }
        .accessibilityIdentifier(KairoAccessibilityID.notificationsCenter)
        .task {
            await load()
        }
        .alert(
            "Notification action failed",
            isPresented: Binding(
                get: { store.actionErrorMessage != nil },
                set: { if !$0 { store.actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.actionErrorMessage = nil }
        } message: {
            Text(store.actionErrorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle, .loading:
            KairoLoadingStateView(
                title: "Loading notifications",
                message: "Kairo is checking your latest updates."
            )
            .padding(KairoSpacing.large)
        case .empty:
            KairoEmptyStateView(
                title: "No notifications yet",
                message: "Verification and account updates will appear here when they are available.",
                systemImage: "bell.slash"
            )
            .padding(KairoSpacing.large)
            .accessibilityIdentifier(KairoAccessibilityID.notificationsEmptyState)
        case .error(let message):
            KairoErrorStateView(
                title: "Notifications unavailable",
                message: message,
                retryAction: { Task { await load() } }
            )
            .padding(KairoSpacing.large)
            .accessibilityIdentifier(KairoAccessibilityID.notificationsErrorState)
        case .loaded:
            notificationList
        }
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                notificationSection(title: "Unread", items: store.items.filter { !$0.isRead })
                notificationSection(title: "Earlier", items: store.items.filter(\.isRead))

                if store.isLoadingNextPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(KairoSpacing.large)
                }
            }
            .padding(.horizontal, KairoSpacing.large)
            .padding(.bottom, KairoSpacing.xxLarge)
        }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func notificationSection(
        title: String,
        items: [CandidateNotification]
    ) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)
                .padding(.top, KairoSpacing.large)
                .padding(.bottom, KairoSpacing.small)

            ForEach(items) { notification in
                Button {
                    open(notification)
                } label: {
                    CandidateNotificationRow(
                        notification: notification,
                        isWorking: store.markingNotificationIDs.contains(notification.id)
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.markingNotificationIDs.contains(notification.id))
                .accessibilityIdentifier(KairoAccessibilityID.notificationRow(notification.id))
                .onAppear {
                    Task { await store.loadNextPageIfNeeded(after: notification) }
                }

                Divider()
                    .foregroundStyle(KairoColors.border)
            }
        }
    }

    private func open(_ notification: CandidateNotification) {
        Task {
            guard await store.prepareToOpen(notification) else {
                await recoverSessionIfRequired()
                return
            }

            switch notification.destination {
            case .verificationRequest(let requestID):
                refreshStore.verificationRequested(requestID: requestID)
                dismiss()
                router.selectTab(.verify)
            case .verify:
                dismiss()
                router.selectTab(.verify)
            case .genericDetail:
                detailPath.append(notification.id)
            }
        }
    }

    private func load() async {
        await store.loadInitial()
        await recoverSessionIfRequired()
    }

    private func recoverSessionIfRequired() async {
        guard store.requiresSessionRecovery else { return }
        dismiss()
        await sessionStore.refreshLaunchRoute()
    }
}

private struct CandidateNotificationRow: View {
    let notification: CandidateNotification
    let isWorking: Bool

    var body: some View {
        HStack(alignment: .top, spacing: KairoSpacing.medium) {
            Image(systemName: notification.categorySystemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KairoColors.brandPrimary)
                .frame(width: 34, height: 34)
                .background(KairoColors.brandPrimary.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: KairoSpacing.small) {
                    Text(notification.title)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: KairoSpacing.small)

                    if !notification.isRead {
                        Circle()
                            .fill(KairoColors.brandPrimary)
                            .frame(width: 8, height: 8)
                            .accessibilityIdentifier(KairoAccessibilityID.notificationUnreadIndicator(notification.id))
                    }
                }

                Text(notification.message)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(CandidateNotificationTimestampFormatter.string(for: notification.createdAt))
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary.opacity(0.8))
            }

            if isWorking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoColors.textSecondary.opacity(0.8))
            }
        }
        .padding(.vertical, KairoSpacing.medium)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(notification.title), \(notification.isRead ? "read" : "unread"), "
                + CandidateNotificationTimestampFormatter.string(for: notification.createdAt)
                + ", \(notification.message)"
        )
        .accessibilityHint("Opens this notification.")
    }
}

private struct CandidateNotificationDetailView: View {
    let notification: CandidateNotification

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                Image(systemName: notification.categorySystemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(KairoColors.brandPrimary)

                Text(notification.title)
                    .font(KairoTypography.title)
                    .foregroundStyle(KairoColors.textPrimary)

                Text(CandidateNotificationTimestampFormatter.string(for: notification.createdAt))
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)

                Text(notification.message)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(KairoSpacing.large)
        }
        .navigationTitle("Notification")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(KairoAccessibilityID.notificationDetail)
    }
}
