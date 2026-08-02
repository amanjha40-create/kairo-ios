import Foundation

struct UITestCreateAccountConfiguration {
    enum EnvironmentKey {
        static let firstName = "KAIRO_UI_TEST_CREATE_ACCOUNT_FIRST_NAME"
        static let lastName = "KAIRO_UI_TEST_CREATE_ACCOUNT_LAST_NAME"
        static let emailAddress = "KAIRO_UI_TEST_CREATE_ACCOUNT_EMAIL"
        static let mobileNumber = "KAIRO_UI_TEST_CREATE_ACCOUNT_MOBILE"
        static let password = "KAIRO_UI_TEST_CREATE_ACCOUNT_PASSWORD"
        static let touchedFields = "KAIRO_UI_TEST_CREATE_ACCOUNT_TOUCHED_FIELDS"
    }

    let draft: CreateAccountDraft
    let touchedFields: Set<CreateAccountField>

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestCreateAccountConfiguration {
        guard UITestLaunchConfiguration.current(arguments: arguments, environment: environment).isEnabled else {
            return UITestCreateAccountConfiguration(
                draft: CreateAccountDraft(),
                touchedFields: []
            )
        }

        return UITestCreateAccountConfiguration(
            draft: CreateAccountDraft(
                firstName: environment[EnvironmentKey.firstName] ?? "",
                lastName: environment[EnvironmentKey.lastName] ?? "",
                emailAddress: environment[EnvironmentKey.emailAddress] ?? "",
                mobileNumber: environment[EnvironmentKey.mobileNumber] ?? "",
                password: environment[EnvironmentKey.password] ?? ""
            ),
            touchedFields: parseTouchedFields(environment[EnvironmentKey.touchedFields] ?? "")
        )
    }

    private static func parseTouchedFields(_ rawValue: String) -> Set<CreateAccountField> {
        Set(
            rawValue
                .split(separator: ",")
                .compactMap { CreateAccountField(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
    }
}
