import Foundation

/// Display formatting never changes the retained payload; only an explicit picker choice does.
nonisolated enum ResumeReviewDate {
    static func parse(_ raw: String) -> Date? {
        let parts = raw.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        return CandidateDateInput.date(year: String(parts[0]), month: month, day: day)
    }
    static func display(_ raw: String) -> String {
        guard parse(raw) != nil else { return raw.isEmpty ? "Choose date…" : raw }
        return raw.replacingOccurrences(of: "-", with: "/")
    }
    static func wire(_ date: Date) -> String { ProfileBirthDate.wire(date) }
}
