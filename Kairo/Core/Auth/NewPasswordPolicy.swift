import Foundation

/// Applies only when choosing a new password, never when signing in with an existing one.
nonisolated enum NewPasswordPolicy {
    static let guidance = "Use 12–128 characters, including a letter, a number and a symbol."
    static func compositionError(_ password: String) -> String? {
        let scalars = password.unicodeScalars
        let letter = scalars.contains { CharacterSet.letters.contains($0) }
        let digit = scalars.contains { CharacterSet.decimalDigits.contains($0) }
        let symbol = scalars.contains { CharacterSet.punctuationCharacters.union(.symbols).contains($0) }
        return letter && digit && symbol ? nil : "Include at least one letter, one number and one symbol."
    }
}
