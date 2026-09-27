import Foundation

/// Presentation-only destinations. Account mutations remain in the canonical More handlers.
enum MoreHubDestination: String, Hashable, CaseIterable {
    case resume, settings, support, legal

    var row: MoreRowItem {
        switch self {
        case .resume:
            MoreRowItem(id: "candidate.more.resume", title: "Resume import", subtitle: "Review previous and current imports", systemImage: "doc.text.magnifyingglass")
        case .settings:
            MoreRowItem(id: "candidate.more.settings", title: "Settings", subtitle: "Privacy, notifications, and active sessions", systemImage: "gearshape")
        case .support:
            MoreRowItem(id: "candidate.more.support", title: "Support", subtitle: "Help and contact", systemImage: "questionmark.circle")
        case .legal:
            MoreRowItem(id: "candidate.more.legal", title: "Legal", subtitle: "Privacy, terms, and about KairoID", systemImage: "doc.text")
        }
    }
}

enum MoreSettingsHierarchy {
    static func accountRows(_ content: MoreOverviewContent) -> [MoreRowItem] {
        content.accountRows.filter { $0.id == "personalInformation" }
    }

    static func securityRows(_ content: MoreOverviewContent) -> [MoreRowItem] {
        content.accountRows.filter { $0.id == "loginSecurity" || $0.id == "sessionsDevices" }
    }

    static func privacyRows(_ content: MoreOverviewContent) -> [MoreRowItem] {
        content.privacyRows.filter { $0.id == "manageConsent" }
    }

    static func destructiveRows(_ content: MoreOverviewContent) -> [MoreRowItem] {
        content.privacyRows.filter { $0.id == "deleteAccount" }
    }

    static func contactState(_ user: AppUser) -> String {
        let email = user.emailVerifiedAt == nil ? "Email not verified" : "Email verified"
        let phone = user.phoneVerifiedAt == nil ? "Phone not verified" : "Phone verified"
        return "\(email) • \(phone)"
    }
}
