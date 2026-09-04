import Foundation

struct UITestNotificationConfiguration {
    static let stateEnvironmentKey = "KAIRO_UI_TEST_NOTIFICATIONS_STATE"

    let fixture: DemoNotificationFixture?

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestNotificationConfiguration {
        let launch = UITestLaunchConfiguration.current(
            arguments: arguments,
            environment: environment
        )
        guard launch.isEnabled else {
            return UITestNotificationConfiguration(fixture: nil)
        }
        return UITestNotificationConfiguration(
            fixture: DemoNotificationFixture(rawValue: environment[stateEnvironmentKey] ?? "unread") ?? .unread
        )
    }
}
