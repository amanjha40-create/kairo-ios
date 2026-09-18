import SwiftUI

/// Presentation filters use canonical states, never display labels or inferred outcomes.
nonisolated enum VerifyRequestFilter: String, CaseIterable, Identifiable, Sendable {
    case all, attention, inProgress, verified, rejected, withdrawn, unableToVerify, expired, cancelled

    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "All verification requests"
        case .attention: "Needs your attention"
        case .inProgress: "In progress"
        case .verified: "Verified"
        case .rejected: "Rejected"
        case .withdrawn: "Withdrawn"
        case .unableToVerify: "Unable to verify"
        case .expired: "Expired"
        case .cancelled: "Cancelled"
        }
    }
    var emptyMessage: String {
        switch self {
        case .all: "No verification requests yet."
        case .attention: "No verification requests need your attention."
        case .inProgress: "No verification requests in progress."
        case .verified: "No verified requests yet."
        case .rejected: "No rejected requests."
        case .withdrawn: "No withdrawn requests."
        case .unableToVerify: "No requests with an unable-to-verify outcome."
        case .expired: "No expired requests."
        case .cancelled: "No cancelled requests."
        }
    }
    func includes(_ status: VerifyVerificationStatus) -> Bool {
        if self == .all { return true }
        if case .unknown = status { return false }
        switch self {
        case .all: return true
        case .attention: return status.group == .pending
        case .inProgress: return status.group == .inProgress
        case .verified: return status == .verified
        case .rejected: return status == .rejected
        case .withdrawn: return status == .withdrawnByCandidate
        case .unableToVerify: return status == .unableToVerify
        case .expired: return status == .expired
        case .cancelled: return status == .cancelled
        }
    }
    func requests(in requests: [VerifyRequest]) -> [VerifyRequest] {
        requests.filter { includes($0.status) }
    }
}

nonisolated enum VerifyListGroup: String, CaseIterable, Identifiable {
    case attention, inProgress, completed, unavailable
    var id: String { rawValue }
    var title: String {
        switch self {
        case .attention: "Needs your attention"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .unavailable: "Status unavailable"
        }
    }
    var accessibilityIdentifier: String {
        switch self {
        case .attention: "candidate.verify.pendingRequests"
        case .inProgress: "candidate.verify.inProgress"
        case .completed: "candidate.verify.completed"
        case .unavailable: "candidate.verify.unavailable"
        }
    }
    func includes(_ status: VerifyVerificationStatus) -> Bool {
        if case .unknown = status { return self == .unavailable }
        switch self {
        case .attention: return status.group == .pending
        case .inProgress: return status.group == .inProgress
        case .completed: return status.group == .completed
        case .unavailable: return false
        }
    }
}

/// Shared by actionable, active and historical requests. Padding is inside the Button label.
struct VerifyCompactRequestRow: View {
    let request: VerifyRequest
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: KairoSpacing.small) {
                VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                    Text(request.requestedItem).font(KairoTypography.bodyStrong).foregroundStyle(KairoColors.textPrimary)
                    Text(request.organization).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                    VerifyStatusBadge(status: request.status)
                    Text(request.dateLabel).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                    if request.status.group == .pending {
                        Text(request.requiredAction).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(KairoColors.textSecondary).accessibilityHidden(true)
            }
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([request.requestedItem, request.organization, request.status.style.title, request.dateLabel].joined(separator: ", "))
        .accessibilityHint("Opens this verification request.")
        .accessibilityIdentifier(KairoAccessibilityID.verifyRequestAction(request.id))
    }
}
