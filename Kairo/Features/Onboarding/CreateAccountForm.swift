import Foundation

struct CreateAccountDraft: Equatable, Sendable {
    var firstName = ""
    var lastName = ""
    var emailAddress = ""
    var mobileNumber = ""
    var password = ""
}

enum CreateAccountField: String, CaseIterable, Hashable, Identifiable, Sendable {
    case firstName
    case lastName
    case emailAddress
    case mobileNumber
    case password

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
            .password
        case .password:
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
        case .password:
            .mobileNumber
        }
    }
}

enum CreateAccountValidation {
    static let passwordMinimumLength = 12
    static let passwordMaximumLength = 128

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
        case .password:
            return passwordErrorMessage(draft.password)
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

    static func normalizedFullName(firstName: String, lastName: String) -> String? {
        let fullName = [normalizedName(firstName), normalizedName(lastName)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return fullName.isEmpty ? nil : fullName
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

    static func e164PhoneNumber(_ value: String) -> String? {
        let digits = normalizedMobileNumber(value)
        guard digits.count == 10 else {
            return nil
        }

        return "+91\(digits)"
    }

    static func passwordErrorMessage(_ value: String) -> String? {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a password."
        }

        if value.count < passwordMinimumLength {
            return "Use at least \(passwordMinimumLength) characters."
        }

        if value.count > passwordMaximumLength {
            return "Use \(passwordMaximumLength) characters or fewer."
        }

        return nil
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let range = NSRange(email.startIndex..<email.endIndex, in: email)
        guard let match = emailExpression.firstMatch(in: email, range: range) else {
            return false
        }

        return match.range == range
    }
}
