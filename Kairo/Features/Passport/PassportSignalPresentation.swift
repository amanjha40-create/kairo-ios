import Foundation

/// Contact verification is never elevated to identity proof; these are not scores.
nonisolated enum PassportSignalPresentation {
    static func rows(_ content: PassportOverviewContent) -> [PassportStrengthItem] {
        let email = content.strengthSummary.first { $0.title == "Email" }
        var rows = [PassportStrengthItem(title: "Account contact", value: email?.status == .verified ? "Email verified" : "Email verification missing", status: email?.status == .verified ? .verified : .notVerified)]
        rows.append(summary("Employment", content.employment.map(\.verificationStatus)))
        rows.append(summary("Education", content.education.map(\.verificationStatus)))
        rows.append(summary("Certifications", content.certifications.map(\.verificationStatus), optional: true))
        if !content.skills.isEmpty {
            rows.append(PassportStrengthItem(title: "Skills", value: "\(content.skills.count) self-declared \(content.skills.count == 1 ? "skill" : "skills")", status: .notVerified))
        }
        if !content.projects.isEmpty {
            rows.append(PassportStrengthItem(title: "Projects", value: "\(content.projects.count) optional \(content.projects.count == 1 ? "project" : "projects")", status: .notVerified))
        }
        return rows
    }

    private static func summary(_ title: String, _ statuses: [PassportVerificationStatus], optional: Bool = false) -> PassportStrengthItem {
        guard !statuses.isEmpty else {
            return PassportStrengthItem(title: title, value: optional ? "Optional · No records added" : "No records added", status: .notVerified)
        }
        // Optional records use a neutral count, not generic provenance wording.
        // Preserve any actual verification state alongside that count.
        let presented = optional ? statuses.filter { $0 != .notVerified } : statuses
        var labels: [String] = []
        for status in presented where !labels.contains(status.style.title) { labels.append(status.style.title) }
        let value = labels.map { label in "\(presented.filter { $0.style.title == label }.count) \(label.lowercased())" }.joined(separator: ", ")
        let count = "\(statuses.count) \(statuses.count == 1 ? "certification" : "certifications")"
        let tone = statuses.first { $0 != .verified } ?? .verified
        return PassportStrengthItem(title: title, value: optional ? count + (value.isEmpty ? "" : " · " + value) : value, status: tone)
    }
}
