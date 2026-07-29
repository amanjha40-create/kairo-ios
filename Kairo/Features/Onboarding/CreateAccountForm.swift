import Foundation

struct CreateAccountDraft: Equatable, Sendable {
    var firstName = ""
    var lastName = ""
    var emailAddress = ""
    var mobileNumber = ""
}

enum CreateAccountField: String, CaseIterable, Hashable, Identifiable, Sendable {
    case firstName
    case lastName
    case emailAddress
    case mobileNumber

    var id: String { rawValue }

    var next: CreateAccountField? {
        switch self {
        case .firstName:
            .lastName
        case .lastName:
            .emailAddress
        case .emailAddress:
            .mobileNumber
        case .mobileNumber:
            nil
        }
    }

    var previous: CreateAccountField? {
        switch self {
        case .firstName:
            nil
        case .lastName:
            .firstName
        case .emailAddress:
            .lastName
        case .mobileNumber:
            .emailAddress
        }
    }
}

enum CreateAccountValidation {
    private static let emailPattern =
        #"^[A-Z0-9a-z.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$"#
    private static let emailExpression = try! NSRegularExpression(pattern: emailPattern)

    static func isFormValid(_ draft: CreateAccountDraft) -> Bool {
        CreateAccountField.allCases.allSatisfy { errorMessage(for: $0, in: draft) == nil }
    }

    static func errorMessage(
        for field: CreateAccountField,
        in draft: CreateAccountDraft
    ) -> String? {
        switch field {
        case .firstName:
            let name = normalizedName(draft.firstName)
            return name.isEmpty ? "Enter your first name." : nil
        case .lastName:
            let name = normalizedName(draft.lastName)
            return name.isEmpty ? "Enter your last name." : nil
        case .emailAddress:
            let email = normalizedEmail(draft.emailAddress)
            guard !email.isEmpty else {
                return "Enter your email address."
            }

            return isValidEmail(email) ? nil : "Enter a valid email address."
        case .mobileNumber:
            let number = normalizedMobileNumber(draft.mobileNumber)
            guard !number.isEmpty else {
                return "Enter your mobile number."
            }

            return number.count == 10 ? nil : "Enter a valid 10-digit Indian mobile number."
        }
    }

    static func sanitizedMobileNumber(_ value: String) -> String {
        normalizedMobileNumber(value)
    }

    static func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedMobileNumber(_ value: String) -> String {
        var digits = value.filter(\.isNumber)

        if digits.count > 10, digits.hasPrefix("91") {
            digits.removeFirst(2)
        } else if digits.count > 10, digits.hasPrefix("0") {
            digits.removeFirst()
        }

        return String(digits.prefix(10))
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let range = NSRange(email.startIndex..<email.endIndex, in: email)
        guard let match = emailExpression.firstMatch(in: email, range: range) else {
            return false
        }

        return match.range == range
    }
}
